import Foundation
import Combine
import os.log

// MARK: - Focus Integration Mode

enum FocusIntegrationMode: String, CaseIterable, Identifiable {
    case shortcuts = "shortcuts"
    case legacyDND = "legacyDND"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shortcuts: return "Apple Focus / Shortcuts"
        case .legacyDND: return "Legacy DND Fallback"
        }
    }

    var isRecommended: Bool { self == .shortcuts }
}

// MARK: - Focus Integration Error

enum FocusIntegrationError: Error, LocalizedError {
    case shortcutNotFound(String)
    case shortcutExecutionFailed(String)
    case processError(String)

    var errorDescription: String? {
        switch self {
        case .shortcutNotFound(let name):
            return "Shortcut \"\(name)\" not found. Create it in the Shortcuts app."
        case .shortcutExecutionFailed(let detail):
            return "Shortcut execution failed: \(detail)"
        case .processError(let detail):
            return "System error: \(detail)"
        }
    }
}

// MARK: - Focus Integration Service

class FocusIntegrationService: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "FocusIntegrationService")
    private let defaults = UserDefaults.standard

    // Keys
    private static let kMode = "focusIntegrationMode"
    private static let kEnabled = "focusIntegrationEnabled"
    private static let kStartShortcut = "focusStartShortcutName"
    private static let kEndShortcut = "focusEndShortcutName"

    // Published state
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.kEnabled) }
    }
    @Published var mode: FocusIntegrationMode {
        didSet { defaults.set(mode.rawValue, forKey: Self.kMode) }
    }
    @Published var startShortcutName: String {
        didSet { defaults.set(startShortcutName, forKey: Self.kStartShortcut) }
    }
    @Published var endShortcutName: String {
        didSet { defaults.set(endShortcutName, forKey: Self.kEndShortcut) }
    }
    @Published var lastError: FocusIntegrationError?
    @Published var isFocusActive: Bool = false

    // Default shortcut names
    static let defaultStartShortcut = "Focally Start Focus"
    static let defaultEndShortcut = "Focally End Focus"

    init() {
        self.isEnabled = defaults.object(forKey: Self.kEnabled) as? Bool ?? false
        let rawMode = defaults.string(forKey: Self.kMode) ?? FocusIntegrationMode.shortcuts.rawValue
        self.mode = FocusIntegrationMode(rawValue: rawMode) ?? .shortcuts
        self.startShortcutName = defaults.string(forKey: Self.kStartShortcut) ?? Self.defaultStartShortcut
        self.endShortcutName = defaults.string(forKey: Self.kEndShortcut) ?? Self.defaultEndShortcut
    }

    // MARK: - Activation / Deactivation

    func activateFocus() {
        guard isEnabled else {
            logger.info("Focus integration disabled; skipping activation")
            return
        }
        lastError = nil

        switch mode {
        case .shortcuts:
            runShortcut(named: startShortcutName) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.isFocusActive = true
                        self?.logger.info("Focus activated via Shortcuts")
                    case .failure(let error):
                        self?.lastError = error
                        self?.logger.error("Focus activation failed: \(error.localizedDescription)")
                    }
                }
            }
        case .legacyDND:
            // Legacy mode is handled by DNDService directly
            logger.info("Focus integration set to legacy DND; DNDService handles activation")
            isFocusActive = true
        }
    }

    func deactivateFocus() {
        guard isEnabled else {
            logger.info("Focus integration disabled; skipping deactivation")
            return
        }
        lastError = nil

        switch mode {
        case .shortcuts:
            runShortcut(named: endShortcutName) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.isFocusActive = false
                        self?.logger.info("Focus deactivated via Shortcuts")
                    case .failure(let error):
                        self?.lastError = error
                        self?.logger.error("Focus deactivation failed: \(error.localizedDescription)")
                    }
                }
            }
        case .legacyDND:
            logger.info("Focus integration set to legacy DND; DNDService handles deactivation")
            isFocusActive = false
        }
    }

    // MARK: - Test Actions

    func testActivation() {
        activateFocus()
    }

    func testDeactivation() {
        deactivateFocus()
    }

    // MARK: - Shortcuts Execution

    private func runShortcut(named name: String, completion: @escaping (Result<Void, FocusIntegrationError>) -> Void) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            completion(.failure(.shortcutNotFound(name)))
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", trimmedName]

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            logger.info("Running shortcut: \"\(trimmedName, privacy: .public)\"")
            try process.run()

            // Use a background thread to wait so we don't block main
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()

                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if process.terminationStatus == 0 {
                    completion(.success(()))
                } else {
                    let detail = errorMessage.isEmpty ? "Exit code \(process.terminationStatus)" : errorMessage
                    completion(.failure(.shortcutExecutionFailed(detail)))
                }
            }
        } catch {
            completion(.failure(.processError(error.localizedDescription)))
        }
    }

    // MARK: - Helpers

    /// Whether the shortcuts mode is active and integration is enabled
    var isUsingShortcuts: Bool {
        isEnabled && mode == .shortcuts
    }

    /// Status text for display in UI
    var statusText: String {
        if !isEnabled {
            return "Disabled"
        }
        if let error = lastError {
            return error.localizedDescription
        }
        if isFocusActive {
            return mode == .shortcuts ? "Focus Active (Shortcuts)" : "DND Active (Legacy)"
        }
        return mode == .shortcuts ? "Ready (Shortcuts)" : "Ready (Legacy)"
    }
}
