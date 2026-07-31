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
            let stagedURL = Self.stagingDirectory.appendingPathComponent("\(kind.bundleResourceName).shortcut")
            try? fileManager.createDirectory(at: Self.stagingDirectory, withIntermediateDirectories: true)
            try? fileManager.removeItem(at: stagedURL)
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
        do {
            let result = try runShortcutsCommand(arguments: ["list", "--show-identifiers"])
            let haystack = result.combinedOutput.lowercased()

            installedShortcutNames = Set(
                ShortcutKind.allCases
                    .map(\.installedShortcutName)
                    .filter { haystack.contains($0.lowercased()) }
            )
        } catch {
            installedShortcutNames = []
        }
    }

    func runShortcut(for action: FocusIntegrationAction) throws {
        let kind: ShortcutKind = action == .start ? .focusOn : .focusOff

        if !isInstalled(kind) {
            refreshInstallationState()
        }

        guard isInstalled(kind) else {
            return // Silently skip if not installed — DND direct is the primary method
        }

        let result = try runShortcutsCommand(arguments: ["run", kind.installedShortcutName])

        if result.terminationStatus != 0 {
            // Log but don't throw — DND direct is the primary method
            logger.warning("Managed shortcut backup failed for \(kind.displayName)")
        }
    }

    func isInstalled(_ kind: ShortcutKind) -> Bool {
        installedShortcutNames.contains(kind.installedShortcutName)
    }

    private static var stagingDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Focally/ManagedShortcuts", isDirectory: true)
    }

    private struct CommandResult {
        let combinedOutput: String
        let terminationStatus: Int32
    }

    private func runShortcutsCommand(arguments: [String]) throws -> CommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(bytes: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(bytes: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return CommandResult(
            combinedOutput: [stdout, stderr].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n"),
            terminationStatus: process.terminationStatus
        )
    }
}
