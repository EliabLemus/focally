import AppIntents
import Foundation
import os.log

// MARK: - Focus Integration Mode

enum FocusIntegrationMode: String, CaseIterable, Identifiable {
    case directDND = "directDND"
    case appShortcuts = "appShortcuts"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .directDND: return "Direct System DND"
        case .appShortcuts: return "Focus Shortcuts"
        }
    }

    var isRecommended: Bool { self == .directDND }
}

// MARK: - Focus Integration Error

enum FocusIntegrationError: Error, LocalizedError {
    case nativeIntegrationUnavailable
    case managedShortcutsUnavailable(String)
    case processError(String)

    var errorDescription: String? {
        switch self {
        case .nativeIntegrationUnavailable:
            return "Focally couldn't update system Do Not Disturb with the current focus integration."
        case .managedShortcutsUnavailable(let detail):
            return detail
        case .processError(let detail):
            return "System error: \(detail)"
        }
    }
}

// MARK: - Focus Integration Action

enum FocusIntegrationAction {
    case start
    case end
}

extension FocusIntegrationAction: CustomStringConvertible {
    var description: String {
        switch self {
        case .start: return "start"
        case .end: return "end"
        }
    }
}

// MARK: - Focus Integration Service

@MainActor
final class FocusIntegrationService: ObservableObject {
    static let shared = FocusIntegrationService()
    static let startActionName = "Start Focus"
    static let endActionName = "End Focus"

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "FocusIntegrationService")
    private let defaults = UserDefaults.standard
    private let managedShortcutsService = ManagedFocusShortcutsService.shared
    private let directDNDService: DNDService
    private let slackService: SlackService

    private static let kMode = "focusIntegrationMode"
    private static let kEnabled = "focusIntegrationEnabled"

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.kEnabled) }
    }

    @Published var mode: FocusIntegrationMode {
        didSet { defaults.set(mode.rawValue, forKey: Self.kMode) }
    }

    @Published var lastError: FocusIntegrationError?
    @Published var isFocusActive: Bool = false
    @Published var lastShortcutIssue: String?

    private init(dndService: DNDService = .shared, slackService: SlackService = SlackService()) {
        self.directDNDService = dndService
        self.slackService = slackService
        self.isEnabled = true
        defaults.set(true, forKey: Self.kEnabled)

        let storedMode = defaults.string(forKey: Self.kMode)
        switch storedMode {
        case FocusIntegrationMode.directDND.rawValue, "legacyDND", "shortcuts", nil:
            self.mode = .directDND
        case FocusIntegrationMode.appShortcuts.rawValue:
            self.mode = .appShortcuts
        default:
            self.mode = .directDND
        }
    }

    func activateFocus() {
        performCombinedFocusAction(.start)
    }

    func deactivateFocus() {
        performCombinedFocusAction(.end)
    }

    func runNativeShortcutTest(_ action: FocusIntegrationAction) {
        lastError = nil
        lastShortcutIssue = nil
        performDirectFocusAction(action, source: "manual test")
    }

    func runSlackTest(completion: ((Bool, String) -> Void)? = nil) {
        slackService.disableSlackDND()
        slackService.setSlackFocusStatus(text: "In focus", emoji: "🎯")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let success = self.slackService.connectionError == nil
            let message = self.slackService.lastActionMessage ?? (success ? "Slack focus integration succeeded" : (self.slackService.connectionError ?? "Slack focus integration failed"))
            completion?(success, message)
        }
    }

    static func performFromAppIntent(_ action: FocusIntegrationAction) async throws {
        await MainActor.run {
            FocusIntegrationService.shared.performDirectFocusAction(action, source: "App Intent")
        }

        if let error = await MainActor.run(body: { FocusIntegrationService.shared.lastError }) {
            throw error
        }
    }

    var isUsingShortcutsAutomation: Bool {
        isEnabled && managedShortcutsService.allManagedShortcutsInstalled
    }

    var statusText: String {
        if let error = lastError {
            return error.localizedDescription
        }
        if isFocusActive {
            if let lastShortcutIssue, !lastShortcutIssue.isEmpty {
                return "Quiet mode is active. The shortcut backup needs attention."
            }
            return "Quiet mode is active and the shortcut backup was attempted."
        }
        if managedShortcutsService.allManagedShortcutsInstalled {
            return "Ready. Focally will turn on quiet mode directly and also try the bundled shortcuts."
        }
        return "Ready. Focally will turn on quiet mode directly and then try the bundled shortcuts."
    }

    private func performCombinedFocusAction(_ action: FocusIntegrationAction) {
        let slackEnabled = self.slackService.isEnabled
        logger.info("performCombinedFocusAction called. action=\(action, privacy: .public), slackEnabled=\(slackEnabled, privacy: .public)")
        lastError = nil
        lastShortcutIssue = nil

        performDirectFocusAction(action, source: "direct system DND")
        attemptManagedShortcutAction(action)
        performSlackFocusAction(action, durationMinutes: action == .start ? 25 : nil)
    }

    private func performDirectFocusAction(_ action: FocusIntegrationAction, source: String) {
        switch action {
        case .start:
            directDNDService.activateDND()
            isFocusActive = directDNDService.isDNDActive
            logger.info("Focus activated via \(source, privacy: .public)")
        case .end:
            directDNDService.deactivateDND()
            isFocusActive = directDNDService.isDNDActive
            logger.info("Focus deactivated via \(source, privacy: .public)")
        }
    }

    private func attemptManagedShortcutAction(_ action: FocusIntegrationAction) {
        do {
            try managedShortcutsService.runShortcut(for: action)
            logger.info("Managed shortcut backup succeeded for \(action == .start ? "start" : "end", privacy: .public)")
        } catch {
            let message = error.localizedDescription
            lastShortcutIssue = message
            logger.error("Managed shortcut backup failed: \(message, privacy: .public)")
        }
    }

    private func performSlackFocusAction(_ action: FocusIntegrationAction, durationMinutes: Int? = nil) {
        let slackEnabled = self.slackService.isEnabled
        let durationDescription = durationMinutes?.description ?? "nil"
        logger.info("performSlackFocusAction called. action=\(action, privacy: .public), durationMinutes=\(durationDescription, privacy: .public), slackEnabled=\(slackEnabled, privacy: .public)")
        guard slackEnabled else {
            logger.info("Skipping performSlackFocusAction: Slack is disabled")
            return
        }
        switch action {
        case .start:
            let duration = durationMinutes ?? 25
            logger.info("Starting Slack focus actions for \(duration, privacy: .public) minutes")
            slackService.setSlackDNDSnooze(minutes: duration)
            slackService.setSlackFocusStatus(text: "In focus", emoji: "🎯")
        case .end:
            logger.info("Ending Slack focus actions")
            slackService.clearStatus()
            slackService.disableSlackDND()
        }
    }
}

// MARK: - App Intents

@available(macOS 14.0, *)
struct StartFocusAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus"
    static var description = IntentDescription("Optional automation action that turns on Focally's direct system Do Not Disturb integration from the Shortcuts app.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await FocusIntegrationService.performFromAppIntent(.start)
        return .result(dialog: "Focus started.")
    }
}

@available(macOS 14.0, *)
struct EndFocusAppIntent: AppIntent {
    static var title: LocalizedStringResource = "End Focus"
    static var description = IntentDescription("Optional automation action that turns off Focally's direct system Do Not Disturb integration from the Shortcuts app.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await FocusIntegrationService.performFromAppIntent(.end)
        return .result(dialog: "Focus ended.")
    }
}

@available(macOS 14.0, *)
struct FocallyAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusAppIntent(),
            phrases: [
                "Start focus with \(.applicationName)",
                "Turn on focus with \(.applicationName)"
            ],
            shortTitle: "Start Focus",
            systemImageName: "moon.circle.fill"
        )

        AppShortcut(
            intent: EndFocusAppIntent(),
            phrases: [
                "End focus with \(.applicationName)",
                "Turn off focus with \(.applicationName)"
            ],
            shortTitle: "End Focus",
            systemImageName: "moon.zzz.fill"
        )
    }
}
