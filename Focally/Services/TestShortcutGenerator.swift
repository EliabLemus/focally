import AppKit
import Foundation
import os.log

struct ManagedShortcutCommandResult {
    let stdout: String
    let stderr: String
    let terminationStatus: Int32

    var combinedOutput: String {
        [stdout, stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }
}

enum ManagedShortcutError: LocalizedError {
    case bundledShortcutMissing(String)
    case shortcutNotPrepared(String)
    case stagingFailed(String)
    case notInstalled(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .bundledShortcutMissing(let detail):
            return detail
        case .shortcutNotPrepared(let detail):
            return detail
        case .stagingFailed(let detail):
            return detail
        case .notInstalled(let detail):
            return detail
        case .executionFailed(let detail):
            return detail
        }
    }
}

@MainActor
final class ManagedFocusShortcutsService: ObservableObject {
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

        var signedFileName: String {
            switch self {
            case .focusOn: return "focally-focus-on-signed.shortcut"
            case .focusOff: return "focally-focus-off-signed.shortcut"
            }
        }

        var bundleResourceName: String {
            signedFileName.replacingOccurrences(of: ".shortcut", with: "")
        }

        var installedShortcutName: String {
            bundleResourceName
        }
    }

    @Published private(set) var installedShortcutNames: Set<String> = []
    @Published private(set) var preparedShortcutURLs: [ShortcutKind: URL] = [:]
    @Published var isPreparing: Bool = false
    @Published var isVerifying: Bool = false
    @Published var lastError: String?
    @Published var lastWarning: String?

    private let logger = Logger.timer
    private let fileManager = FileManager.default

    private init() {
        refreshPreparedShortcutState()
        refreshInstallationState()
    }

    var shortcutsRootDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Focally", isDirectory: true)
            .appendingPathComponent("ManagedShortcuts", isDirectory: true)
    }

    var stagedShortcutsDirectory: URL {
        shortcutsRootDirectory.appendingPathComponent("BundledSigned", isDirectory: true)
    }

    var allSignedShortcutsExist: Bool {
        ShortcutKind.allCases.allSatisfy { preparedShortcutURLs[$0] != nil }
    }

    var allManagedShortcutsInstalled: Bool {
        ShortcutKind.allCases.allSatisfy { installedShortcutNames.contains($0.installedShortcutName) }
    }

    var setupSummary: String {
        if allManagedShortcutsInstalled {
            return "Managed shortcuts are installed and ready to run from Focally."
        }

        if allSignedShortcutsExist {
            return "Bundled signed shortcuts are ready. Open them once in Shortcuts and press Add for each one."
        }

        if isPreparing {
            return "Preparing bundled signed shortcuts…"
        }

        return "Stage the bundled signed shortcuts first, then import them once in Shortcuts."
    }

    func stagedShortcutURL(for kind: ShortcutKind) -> URL {
        stagedShortcutsDirectory.appendingPathComponent(kind.signedFileName)
    }

    func bundledShortcutURL(for kind: ShortcutKind) throws -> URL {
        if let resourceURL = Bundle.main.url(forResource: kind.bundleResourceName, withExtension: "shortcut") {
            return resourceURL
        }

        throw ManagedShortcutError.bundledShortcutMissing(
            "Focally couldn't find the bundled \(kind.displayName) " +
            "shortcut inside the app resources."
        )
    }

    func isInstalled(_ kind: ShortcutKind) -> Bool {
        installedShortcutNames.contains(kind.installedShortcutName)
    }

    func prepareSignedShortcuts() {
        isPreparing = true
        lastError = nil
        lastWarning = nil

        defer {
            refreshPreparedShortcutState()
            isPreparing = false
        }

        do {
            try ensureDirectoriesExist()

            for kind in ShortcutKind.allCases {
                let bundledURL = try bundledShortcutURL(for: kind)
                let stagedURL = stagedShortcutURL(for: kind)
                try stageBundledShortcut(from: bundledURL, to: stagedURL)
            }

            logger.info("Staged bundled managed Focus shortcuts in \(self.stagedShortcutsDirectory.path)")
        } catch {
            lastError = error.localizedDescription
            logger.error("Failed to stage managed shortcuts: \(error.localizedDescription)")
        }
    }

    func openSignedShortcutsForImport() {
        guard allSignedShortcutsExist else {
            lastError = ManagedShortcutError.shortcutNotPrepared(
                "Stage the bundled signed shortcuts before opening them in Shortcuts."
            ).localizedDescription
            return
        }

        let urls = ShortcutKind.allCases.compactMap { preparedShortcutURLs[$0] }
        guard !urls.isEmpty else { return }

        for (index, url) in urls.enumerated() {
            let delay = DispatchTime.now() + .milliseconds(index * 350)
            DispatchQueue.main.asyncAfter(deadline: delay) { [weak self] in
                self?.revealSignedShortcutsInFinder()
            }
        }
    }

    func revealSignedShortcutsInFinder() {
        guard allSignedShortcutsExist else {
            lastError = ManagedShortcutError.shortcutNotPrepared(
                "Stage the bundled signed shortcuts before revealing them in Finder."
            ).localizedDescription
            return
        }

        let urls = ShortcutKind.allCases.compactMap { preparedShortcutURLs[$0] }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func prepareAndOpenForImport() {
        prepareSignedShortcuts()

        guard lastError == nil else { return }
        openSignedShortcutsForImport()
    }

    func refreshInstallationState() {
        isVerifying = true
        defer { isVerifying = false }

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
            lastError = error.localizedDescription
            logger.error("Failed to verify installed shortcuts: \(error.localizedDescription)")
        }
    }

    func runShortcut(for action: FocusIntegrationAction) throws {
        let kind: ShortcutKind = action == .start ? .focusOn : .focusOff

        if !isInstalled(kind) {
            refreshInstallationState()
        }

        guard isInstalled(kind) else {
            throw ManagedShortcutError.notInstalled(
                "\(kind.displayName) shortcut is not installed yet. Stage the bundled " +
                "file, open it in Shortcuts, and press Add first."
            )
        }

        let result = try runShortcutsCommand(arguments: ["run", kind.installedShortcutName])

        guard result.terminationStatus == 0 else {
            throw ManagedShortcutError.executionFailed(
                result.combinedOutput.isEmpty
                    ? "shortcuts run failed for \(kind.installedShortcutName)."
                    : result.combinedOutput
            )
        }

        let warningText = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !warningText.isEmpty {
            lastWarning = warningText
        }
    }

    private func refreshPreparedShortcutState() {
        preparedShortcutURLs = Dictionary(uniqueKeysWithValues: ShortcutKind.allCases.compactMap { kind in
            let url = stagedShortcutURL(for: kind)
            return fileManager.fileExists(atPath: url.path) ? (kind, url) : nil
        })
    }

    private func ensureDirectoriesExist() throws {
        try fileManager.createDirectory(at: stagedShortcutsDirectory, withIntermediateDirectories: true)
    }

    private func stageBundledShortcut(from sourceURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            let sourceData = try Data(contentsOf: sourceURL)
            let destinationData = try Data(contentsOf: destinationURL)
            if sourceData == destinationData {
                return
            }

            try fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw ManagedShortcutError.stagingFailed(
                "Focally couldn't stage the bundled shortcut files for import: " +
                "\(error.localizedDescription)"
            )
        }
    }

    private func runShortcutsCommand(arguments: [String]) throws -> ManagedShortcutCommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return ManagedShortcutCommandResult(
            stdout: String(bytes: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            stderr: String(bytes: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            terminationStatus: process.terminationStatus
        )
    }
}

typealias TestShortcutGenerator = ManagedFocusShortcutsService
