import AppIntents
import Foundation
import Combine
import os.log

// MARK: - Focus Integration Mode

enum FocusIntegrationMode: String, CaseIterable, Identifiable {
    case directDND = "directDND"
    case appShortcuts = "appShortcuts"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .directDND: return "Direct System DND"
        case .appShortcuts: return "Managed Shortcuts"
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

// MARK: - Focus Integration Service

@MainActor
final class FocusIntegrationService: ObservableObject {
    static let shared = FocusIntegrationService()
    static let startActionName = "Start Focus"
    static let endActionName = "End Focus"

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "FocusIntegrationService")
    private let defaults = UserDefaults.standard
    private let managedShortcutsService = ManagedFocusShortcutsService.shared

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

    private init() {
        self.isEnabled = defaults.object(forKey: Self.kEnabled) as? Bool ?? false

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
        guard isEnabled else {
            logger.info("Focus integration disabled; skipping activation")
            return
        }

        lastError = nil

        switch mode {
        case .directDND:
            performDirectFocusAction(.start, source: "direct system DND")
        case .appShortcuts:
            performManagedShortcutAction(.start)
        }
    }

    func deactivateFocus() {
        guard isEnabled else {
            logger.info("Focus integration disabled; skipping deactivation")
            return
        }

        lastError = nil

        switch mode {
        case .directDND:
            performDirectFocusAction(.end, source: "direct system DND")
        case .appShortcuts:
            performManagedShortcutAction(.end)
        }
    }

    func runNativeShortcutTest(_ action: FocusIntegrationAction) {
        lastError = nil

        switch mode {
        case .directDND:
            performDirectFocusAction(action, source: "direct system DND")
        case .appShortcuts:
            performManagedShortcutAction(action)
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

    private func performDirectFocusAction(_ action: FocusIntegrationAction, source: String) {
        switch action {
        case .start:
            DNDService().activateDND()
            isFocusActive = true
            logger.info("Focus activated via \(source, privacy: .public)")
        case .end:
            DNDService().deactivateDND()
            isFocusActive = false
            logger.info("Focus deactivated via \(source, privacy: .public)")
        }
    }

    private func performManagedShortcutAction(_ action: FocusIntegrationAction) {
        do {
            try managedShortcutsService.runShortcut(for: action)
            isFocusActive = action == .start
            logger.info("Focus \(action == .start ? "activated" : "deactivated", privacy: .public) via managed shortcuts")
        } catch {
            isFocusActive = false
            lastError = .managedShortcutsUnavailable(error.localizedDescription)
            logger.error("Managed shortcut execution failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    var isUsingShortcutsAutomation: Bool {
        isEnabled && mode == .appShortcuts
    }

    var statusText: String {
        if !isEnabled {
            return "Disabled"
        }
        if let error = lastError {
            return error.localizedDescription
        }
        if mode == .appShortcuts {
            if managedShortcutsService.allManagedShortcutsInstalled {
                return isFocusActive ? "Managed shortcuts ran successfully" : "Managed shortcuts installed and ready"
            }
            return managedShortcutsService.setupSummary
        }
        if isFocusActive {
            return "Do Not Disturb Active"
        }
        return "Ready to turn on system DND"
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
