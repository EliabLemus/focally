import AppKit
import Foundation
import Observation
import os.log

@MainActor
@Observable
final class ManagedFocusShortcutsService {
    static let shared = ManagedFocusShortcutsService()

    enum ShortcutKind: String, CaseIterable, Identifiable {
        case focusOn
        case focusOff

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .focusOn: return "Focus On"
            case .focusOff: return "Focus Off"
            }
        }

        var bundleResourceName: String {
            switch self {
            case .focusOn: return "focally-focus-on-signed"
            case .focusOff: return "focally-focus-off-signed"
            }
        }

        var installedShortcutName: String {
            bundleResourceName
        }
    }

    private(set) var installedShortcutNames: Set<String> = []
    var lastError: String?

    private let logger = Logger.timer
    private let fileManager = FileManager.default

    private init() {
        refreshInstallationState()
    }

    var allInstalled: Bool {
        ShortcutKind.allCases.allSatisfy { installedShortcutNames.contains($0.installedShortcutName) }
    }

    /// Stage the bundled signed shortcuts and open them in Shortcuts.app for one-tap install.
    func installShortcuts() {
        lastError = nil

        let urls = ShortcutKind.allCases.compactMap { kind -> URL? in
            guard let resourceURL = Bundle.main.url(forResource: kind.bundleResourceName, withExtension: "shortcut") else {
                return nil
            }
            // Stage to Application Support so Shortcuts.app can read it
            // TASK-062 (c): staging prep is best-effort; the copy below has a
            // do/catch that reports the real failure path.
            let stagedURL = Self.stagingDirectory.appendingPathComponent("\(kind.bundleResourceName).shortcut")
            try? fileManager.createDirectory(at: Self.stagingDirectory, withIntermediateDirectories: true)
            try? fileManager.removeItem(at: stagedURL) // (c) removeItem tolerates a missing staged file.
            do {
                try fileManager.copyItem(at: resourceURL, to: stagedURL)
                return stagedURL
            } catch {
                return nil
            }
        }

        guard !urls.isEmpty else {
            lastError = "Could not find bundled shortcuts in app resources."
            return
        }

        // Open each in Shortcuts.app with a small delay between
        for (index, url) in urls.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(index * 400)) {
                NSWorkspace.shared.open(url)
            }
        }

        // Refresh after a delay to detect installation
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.refreshInstallationState()
        }
    }

    func refreshInstallationState() {
        Task { @MainActor [weak self] in
            let names = await Task.detached(priority: .utility) { () -> Set<String> in
                do {
                    let result = try Self.runShortcutsCommand(arguments: ["list", "--show-identifiers"])
                    let haystack = result.combinedOutput.lowercased()
                    return Set(
                        ShortcutKind.allCases
                            .map(\.installedShortcutName)
                            .filter { haystack.contains($0.lowercased()) }
                    )
                } catch {
                    return []
                }
            }.value
            self?.installedShortcutNames = names
        }
    }

    func runShortcut(for action: FocusIntegrationAction) async throws {
        let kind: ShortcutKind = action == .start ? .focusOn : .focusOff

        guard isInstalled(kind) else {
            refreshInstallationState()
            return // Silently skip if not installed — DND direct is the primary method
        }

        let shortcutName = kind.installedShortcutName
        let result = try await Task.detached(priority: .userInitiated) {
            try Self.runShortcutsCommand(arguments: ["run", shortcutName])
        }.value

        if result.terminationStatus != 0 {
            logger.warning("Managed shortcut backup failed for \(kind.displayName)")
        }
    }

    func isInstalled(_ kind: ShortcutKind) -> Bool {
        installedShortcutNames.contains(kind.installedShortcutName)
    }

    // MARK: - Generic "Set Focus by Name" shortcut (TASK-057 Layer 3)

    /// Bundled resource name of the single pre-signed generic shortcut that
    /// receives a Focus mode name as input and enables/disables it.
    static let focusByNameShortcutName = "focally-focus-by-name-signed"
    static let focusByNameRunTimeout: TimeInterval = 5

    /// Programmatic `shortcuts run` of the signed generic Focus shortcut.
    /// Bounded at 5 s; throws on timeout or non-zero exit — the caller
    /// (DNDReliabilityService) never retries.
    func runFocusByName(_ modeName: String) async throws {
        let shortcutName = Self.focusByNameShortcutName
        let input = modeName
        let timeout = Self.focusByNameRunTimeout
        let result = try await Task.detached(priority: .userInitiated) {
            try Self.runShortcutsCommand(arguments: ["run", shortcutName, "--input", input], timeout: timeout)
        }.value
        guard result.terminationStatus == 0 else {
            throw FocusIntegrationError.processError(
                "Focus-by-name shortcut exited with status \(result.terminationStatus)"
            )
        }
    }

    private static var stagingDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Focally/ManagedShortcuts", isDirectory: true)
    }

    private struct CommandResult: Sendable {
        let combinedOutput: String
        let terminationStatus: Int32
    }

    nonisolated private static func runShortcutsCommand(arguments: [String], timeout: TimeInterval = 8) throws -> CommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let completion = DispatchSemaphore(value: 0)

        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.terminationHandler = { _ in completion.signal() }

        try process.run()
        guard completion.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            _ = completion.wait(timeout: .now() + 1)
            throw FocusIntegrationError.processError("Shortcuts command timed out")
        }

        let stdout = String(bytes: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(bytes: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return CommandResult(
            combinedOutput: [stdout, stderr].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n"),
            terminationStatus: process.terminationStatus
        )
    }
}

// MARK: - TASK-057 DND Layer 3 escalation

extension ManagedFocusShortcutsService: FocusShortcutEscalating {}
