import AppIntents
import Foundation
import Observation
import os.log

enum FocusIntegrationError: Error, LocalizedError {
    case processError(String)
    case noActiveSession
    case alreadyPaused
    case sessionNotPaused
    case sessionAlreadyActive
    case actionRequiresActiveSession

    var errorDescription: String? {
        switch self {
        case .processError(let detail):
            return "System error: \(detail)"
        case .noActiveSession:
            return "No Focally session is active."
        case .alreadyPaused:
            return "The Focally session is already paused."
        case .sessionNotPaused:
            return "The Focally session is not paused."
        case .sessionAlreadyActive:
            return "The Focally session is already running."
        case .actionRequiresActiveSession:
            return "Start or end a focus session in Focally first."
        }
    }
}

enum FocusIntegrationAction {
    case start
    case end
}

enum DNDTransitionOutcome: Equatable {
    case unchanged(active: Bool)
    case activated
    case deactivated
    case handedOff
    case failed(targetActive: Bool)
}

@MainActor
@Observable
final class FocusIntegrationService {
    static let shared = FocusIntegrationService()

    private let logger = Logger.slack
    private let defaults: UserDefaults
    private let presenceCoordinator: PresenceCoordinating
    private let slackService: SlackService
    private let shortcutsService = ManagedFocusShortcutsService.shared
    private let notificationCenterPresenter: NotificationCenterPresenting
    private let verificationDelay: () async -> Void
    private let shortcutBackup: (FocusIntegrationAction) async throws -> Void
    private static let enabledKey = "focusIntegrationEnabled"

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }

    var lastError: FocusIntegrationError?
    var isFocusActive = false
    private(set) var lastDNDOutcome: DNDTransitionOutcome = .unchanged(active: false)
    private(set) var slackTestState: SlackOperationState = .idle
    var isFocusModeActive: Bool { presenceCoordinator.isManualFocusActive }
    private var activeMode: FocusMode?
    private var transitionGeneration: UInt = 0

    // Internal, read-only identity seam for singleton regression coverage.
    var slackServiceForTesting: SlackService { slackService }

    init(
        presenceCoordinator: PresenceCoordinating? = nil,
        slackService: SlackService? = nil,
        defaults: UserDefaults = .standard,
        notificationCenterPresenter: NotificationCenterPresenting? = nil,
        verificationDelay: @escaping () async -> Void = {
            try? await Task.sleep(nanoseconds: 750_000_000)
        },
        shortcutBackup: ((FocusIntegrationAction) async throws -> Void)? = nil
    ) {
        self.presenceCoordinator = presenceCoordinator ?? DefaultPresenceCoordinator.shared
        self.slackService = slackService ?? .shared
        self.defaults = defaults
        self.notificationCenterPresenter = notificationCenterPresenter ?? NotificationCenterPresenter.shared
        self.verificationDelay = verificationDelay
        self.shortcutBackup = shortcutBackup ?? ManagedFocusShortcutsService.shared.runShortcut
        if defaults.object(forKey: Self.enabledKey) == nil {
            defaults.set(true, forKey: Self.enabledKey)
        }
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
    }

    func activateFocus(for mode: FocusMode) {
        transitionGeneration &+= 1
        let generation = transitionGeneration
        activeMode = mode.sanitized()
        lastError = nil
        if notificationCenterPresenter.ownsVisiblePanel {
            Task { @MainActor [weak self] in
                guard let self else { return }
                await notificationCenterPresenter.closeIfOwned()
                guard generation == transitionGeneration else { return }
                beginFocusActivation(generation: generation)
            }
            return
        }
        beginFocusActivation(generation: generation)
    }

    private func beginFocusActivation(generation: UInt) {
        let wasActive = presenceCoordinator.isSystemDNDActive
        if let activeMode {
            presenceCoordinator.manualFocusStarted(mode: activeMode, systemDNDEnabled: isEnabled)
        }
        isFocusActive = presenceCoordinator.isSystemDNDActive
        guard isEnabled, activeMode?.enableMacOSDND == true else {
            lastDNDOutcome = .unchanged(active: isFocusActive)
            return
        }
        Task { @MainActor [weak self] in
            await self?.verifyTransition(
                action: .start,
                wasActive: wasActive,
                wasOwned: false,
                generation: generation
            )
        }
    }

    func deactivateFocus() {
        transitionGeneration &+= 1
        let generation = transitionGeneration
        lastError = nil
        let wasActive = presenceCoordinator.isSystemDNDActive
        let wasOwned = presenceCoordinator.ownsSystemDND
        presenceCoordinator.manualFocusEnded()
        isFocusActive = presenceCoordinator.isSystemDNDActive
        activeMode = nil

        if wasActive, wasOwned, presenceCoordinator.wantsSystemDND {
            lastDNDOutcome = .handedOff
            return
        }
        guard wasActive, wasOwned else {
            lastDNDOutcome = .unchanged(active: isFocusActive)
            return
        }
        Task { @MainActor [weak self] in
            await self?.verifyTransition(
                action: .end,
                wasActive: wasActive,
                wasOwned: wasOwned,
                generation: generation
            )
        }
    }

    func runSlackTest(completion: ((Bool, String) -> Void)? = nil) {
        guard slackTestState != .working else { return }

        slackTestState = .working
        slackService.disableSlackDND()
        slackService.setStatus(
            text: "Focally test",
            expirationTimestamp: Int(Date().addingTimeInterval(300).timeIntervalSince1970),
            taskEmoji: ":brain:"
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                let message = "Slack focus status updated"
                slackTestState = .success(message)
                completion?(true, message)
            case .failure(let error):
                let message = error.localizedDescription
                slackTestState = .failed(message)
                completion?(false, message)
            }
        }
    }

    static func performFromAppIntent(_ action: FocusIntegrationAction) async throws {
        guard let timer = await MainActor.run(body: { FocusTimerService.shared }) else {
            throw FocusIntegrationError.actionRequiresActiveSession
        }
        let state = await MainActor.run { (timer.hasSession, timer.isPaused) }
        try validateAppIntentAction(action, hasSession: state.0, isPaused: state.1)
        await MainActor.run {
            switch action {
            case .start:
                timer.resumeSession()
            case .end:
                timer.endSession(playCompletionSound: false)
            }
        }
    }

    static func validateAppIntentAction(
        _ action: FocusIntegrationAction,
        hasSession: Bool,
        isPaused: Bool
    ) throws {
        guard hasSession else { throw FocusIntegrationError.actionRequiresActiveSession }
        if action == .start, !isPaused { throw FocusIntegrationError.sessionAlreadyActive }
    }

    static func pauseFromAppIntent() async throws {
        guard let timer = await MainActor.run(body: { FocusTimerService.shared }),
              await MainActor.run(body: { timer.hasSession }) else {
            throw FocusIntegrationError.noActiveSession
        }
        guard await MainActor.run(body: { !timer.isPaused }) else {
            throw FocusIntegrationError.alreadyPaused
        }
        await MainActor.run { timer.pauseSession() }
    }

    static func resumeFromAppIntent() async throws {
        guard let timer = await MainActor.run(body: { FocusTimerService.shared }),
              await MainActor.run(body: { timer.hasSession }) else {
            throw FocusIntegrationError.noActiveSession
        }
        guard await MainActor.run(body: { timer.isPaused }) else {
            throw FocusIntegrationError.sessionNotPaused
        }
        await MainActor.run { timer.resumeSession() }
    }

    var statusText: String {
        if let lastError {
            return lastError.localizedDescription
        }
        if shortcutsService.allInstalled {
            return "DND is controlled directly. Signed shortcuts are installed as backup."
        }
        return "DND is controlled directly. Install signed shortcuts for keyboard trigger backup."
    }

    var areShortcutsInstalled: Bool {
        shortcutsService.allInstalled
    }

    func performDirectFocusAction(_ action: FocusIntegrationAction, mode: FocusMode?) {
        guard isEnabled else { return }
        guard let mode else {
            isFocusActive = presenceCoordinator.isManualFocusActive
            return
        }
        switch action {
        case .start:
            presenceCoordinator.manualFocusStarted(mode: mode)
            isFocusActive = presenceCoordinator.isManualFocusActive
        case .end:
            presenceCoordinator.manualFocusEnded()
            isFocusActive = false
        }
    }

    private func verifyTransition(
        action: FocusIntegrationAction,
        wasActive: Bool,
        wasOwned: Bool,
        generation: UInt
    ) async {
        let targetActive = action == .start
        await verificationDelay()
        guard generation == transitionGeneration else { return }

        if presenceCoordinator.refreshSystemDNDStatus() != targetActive {
            do {
                try await shortcutBackup(action)
            } catch {
                logger.warning("Shortcut backup skipped: \(error.localizedDescription)")
            }
            await verificationDelay()
            guard generation == transitionGeneration else { return }
        }

        let active = presenceCoordinator.refreshSystemDNDStatus()
        isFocusActive = active
        guard active == targetActive else {
            lastDNDOutcome = .failed(targetActive: targetActive)
            lastError = .processError(targetActive ? "DND could not be activated" : "DND could not be deactivated")
            return
        }

        if targetActive {
            lastDNDOutcome = wasActive ? .unchanged(active: true) : .activated
        } else if wasActive, wasOwned, !presenceCoordinator.wantsSystemDND {
            lastDNDOutcome = .deactivated
            _ = await notificationCenterPresenter.openForBreak()
        } else {
            lastDNDOutcome = .unchanged(active: active)
        }
    }

    func performSlackBreakAction(breakLabel: String?, isLongBreak: Bool, breakDurationMinutes: Int, modeName: String, modeEmoji: String) {
        guard slackService.isEnabled else { return }

        let breakText: String
        if let label = breakLabel, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            breakText = isLongBreak ? "\(label) — Long Break" : "\(label)"
        } else {
            breakText = isLongBreak ? "\(modeName) — Long Break" : "\(modeName) — Break"
        }

        let expiration = Int(Date().addingTimeInterval(TimeInterval(breakDurationMinutes * 60)).timeIntervalSince1970)
        slackService.setStatus(
            text: breakText,
            expirationTimestamp: expiration,
            taskEmoji: modeEmoji,
            fallbackEmoji: slackService.savedStatusEmoji()
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let error = self?.slackService.connectionError {
                self?.logger.error("Slack break status update failed: \(error)")
                self?.lastError = FocusIntegrationError.processError(error)
            }
        }
    }
}

@available(macOS 14.0, *)
struct StartFocusAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Focus"
    static var description = IntentDescription("Resumes the current paused Focally session.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await FocusIntegrationService.performFromAppIntent(.start)
        return .result(dialog: "Focus resumed.")
    }
}

@available(macOS 14.0, *)
struct EndFocusAppIntent: AppIntent {
    static var title: LocalizedStringResource = "End Focus"
    static var description = IntentDescription("Ends the current Focally session and releases its integrations.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await FocusIntegrationService.performFromAppIntent(.end)
        return .result(dialog: "Focus ended.")
    }
}

@available(macOS 14.0, *)
struct PauseFocusAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Focus"
    static var description = IntentDescription("Pauses the current Focally focus session.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await FocusIntegrationService.pauseFromAppIntent()
        return .result(dialog: "Focus paused.")
    }
}

@available(macOS 14.0, *)
struct ResumeFocusAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Focus"
    static var description = IntentDescription("Resumes the paused Focally focus session.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await FocusIntegrationService.resumeFromAppIntent()
        return .result(dialog: "Focus resumed.")
    }
}

@available(macOS 14.0, *)
struct FocallyAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusAppIntent(),
            phrases: ["Start focus with \(.applicationName)"],
            shortTitle: "Start Focus",
            systemImageName: "moon.circle.fill"
        )

        AppShortcut(
            intent: PauseFocusAppIntent(),
            phrases: ["Pause focus with \(.applicationName)"],
            shortTitle: "Pause Focus",
            systemImageName: "pause.circle.fill"
        )

        AppShortcut(
            intent: ResumeFocusAppIntent(),
            phrases: ["Resume focus with \(.applicationName)"],
            shortTitle: "Resume Focus",
            systemImageName: "play.circle.fill"
        )

        AppShortcut(
            intent: EndFocusAppIntent(),
            phrases: ["End focus with \(.applicationName)"],
            shortTitle: "End Focus",
            systemImageName: "moon.zzz.fill"
        )
    }
}
