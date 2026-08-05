import AppIntents
import Foundation
import Observation
import os.log

enum FocusIntegrationError: Error, LocalizedError {
    case processError(String)

    var errorDescription: String? {
        switch self {
        case .processError(let detail):
            return "System error: \(detail)"
        }
    }
}

enum FocusIntegrationAction {
    case start
    case end
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
    private let shortcutBackup: (FocusIntegrationAction) throws -> Void
    private static let enabledKey = "focusIntegrationEnabled"

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }

    var lastError: FocusIntegrationError?
    var isFocusActive = false
    var isFocusModeActive: Bool { presenceCoordinator.isManualFocusActive }
    private var activeMode: FocusMode?

    // Internal, read-only identity seam for singleton regression coverage.
    var slackServiceForTesting: SlackService { slackService }

    init(
        presenceCoordinator: PresenceCoordinating = DefaultPresenceCoordinator.shared,
        slackService: SlackService = .shared,
        defaults: UserDefaults = .standard,
        shortcutBackup: ((FocusIntegrationAction) throws -> Void)? = nil
    ) {
        self.presenceCoordinator = presenceCoordinator
        self.slackService = slackService
        self.defaults = defaults
        self.shortcutBackup = shortcutBackup ?? ManagedFocusShortcutsService.shared.runShortcut
        if defaults.object(forKey: Self.enabledKey) == nil {
            defaults.set(true, forKey: Self.enabledKey)
        }
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
    }

    func activateFocus(for mode: FocusMode) {
        activeMode = mode.sanitized()
        lastError = nil
        if let activeMode {
            presenceCoordinator.manualFocusStarted(mode: activeMode, systemDNDEnabled: isEnabled)
        }
        isFocusActive = presenceCoordinator.isSystemDNDActive
        attemptShortcutBackup(.start)
    }

    func deactivateFocus() {
        lastError = nil
        presenceCoordinator.manualFocusEnded()
        isFocusActive = false
        attemptShortcutBackup(.end)
        activeMode = nil
    }

    func runSlackTest(completion: ((Bool, String) -> Void)? = nil) {
        slackService.disableSlackDND()
        slackService.setStatus(text: "Focally test", expirationTimestamp: Int(Date().addingTimeInterval(300).timeIntervalSince1970), taskEmoji: ":brain:")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let success = self.slackService.connectionError == nil
            let message = self.slackService.lastActionMessage ?? (success ? "Slack integration succeeded" : (self.slackService.connectionError ?? "Slack integration failed"))
            completion?(success, message)
        }
    }

    static func performFromAppIntent(_ action: FocusIntegrationAction) async throws {
        await MainActor.run {
            FocusIntegrationService.shared.performDirectFocusAction(action, mode: nil)
        }

        if let error = await MainActor.run(body: { FocusIntegrationService.shared.lastError }) {
            throw error
        }
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

    private func attemptShortcutBackup(_ action: FocusIntegrationAction) {
        do {
            try shortcutBackup(action)
        } catch {
            logger.warning("Shortcut backup skipped: \(error.localizedDescription)")
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
    static var title: LocalizedStringResource = "Start Focus"
    static var description = IntentDescription("Turns on Focally's direct system Do Not Disturb integration.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await FocusIntegrationService.performFromAppIntent(.start)
        return .result(dialog: "Focus started.")
    }
}

@available(macOS 14.0, *)
struct EndFocusAppIntent: AppIntent {
    static var title: LocalizedStringResource = "End Focus"
    static var description = IntentDescription("Turns off Focally's direct system Do Not Disturb integration.")
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
        await MainActor.run {
            FocusTimerService.shared?.pauseSession()
        }
        return .result(dialog: "Focus paused.")
    }
}

@available(macOS 14.0, *)
struct ResumeFocusAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Focus"
    static var description = IntentDescription("Resumes the paused Focally focus session.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            FocusTimerService.shared?.resumeSession()
        }
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
