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
    private let defaults = UserDefaults.standard
    private let directDNDService: DNDService
    private let slackService: SlackService
    private static let enabledKey = "focusIntegrationEnabled"

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }

    var lastError: FocusIntegrationError?
    var isFocusActive = false
    private var activeMode: FocusMode?

    private init(dndService: DNDService = .shared, slackService: SlackService = SlackService()) {
        self.directDNDService = dndService
        self.slackService = slackService
        if defaults.object(forKey: Self.enabledKey) == nil {
            defaults.set(true, forKey: Self.enabledKey)
        }
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
    }

    func activateFocus(for mode: FocusMode) {
        activeMode = mode.sanitized()
        performCombinedFocusAction(.start, mode: activeMode)
    }

    func deactivateFocus() {
        performCombinedFocusAction(.end, mode: activeMode)
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
        return "Focally updates Slack status for every mode and only enables Slack/macOS Do Not Disturb for modes with DND turned on."
    }

    private func performCombinedFocusAction(_ action: FocusIntegrationAction, mode: FocusMode?) {
        lastError = nil
        performDirectFocusAction(action, mode: mode)
        performSlackFocusAction(action, mode: mode)
    }

    private func performDirectFocusAction(_ action: FocusIntegrationAction, mode: FocusMode?) {
        guard isEnabled else { return }

        let shouldToggleDND = mode?.enableDND == true
        switch action {
        case .start:
            guard shouldToggleDND else {
                isFocusActive = false
                return
            }
            directDNDService.activateDND()
            isFocusActive = directDNDService.isDNDActive
            logger.info("Direct DND enabled")
        case .end:
            guard shouldToggleDND else {
                isFocusActive = false
                return
            }
            directDNDService.deactivateDND()
            isFocusActive = directDNDService.isDNDActive
            logger.info("Direct DND disabled")
        }
    }

    private func performSlackFocusAction(_ action: FocusIntegrationAction, mode: FocusMode?) {
        guard slackService.isEnabled else { return }

        switch action {
        case .start:
            guard let mode else { return }
            let expiration = Int(Date().addingTimeInterval(TimeInterval(mode.sanitizedDurationMinutes * 60)).timeIntervalSince1970)
            slackService.setStatus(
                text: mode.statusText,
                expirationTimestamp: expiration,
                taskEmoji: mode.emoji,
                fallbackEmoji: slackService.savedStatusEmoji()
            )
            if mode.enableDND {
                slackService.setSlackDNDSnooze(minutes: mode.sanitizedDurationMinutes)
            }
        case .end:
            slackService.clearStatus()
            if mode?.enableDND == true {
                slackService.disableSlackDND()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let error = self?.slackService.connectionError {
                self?.logger.error("Slack integration failed: \(error)")
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
