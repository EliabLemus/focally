import Foundation
import Combine
import os.log
import AppKit

// MARK: - Shortcut Drop Handler

class ShortcutDropHandler: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "ShortcutDropHandler")
    private let fileManager = FileManager.default

    // Published state
    @Published var lastMessage: String = ""
    @Published var isProcessing: Bool = false
    @Published var lastError: String?

    // URL to Shortcuts library
    private var shortcutsLibraryURL: URL {
        fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Shortcuts", isDirectory: true)
    }

    init() {
        // Ensure Shortcuts directory exists
        try? ensureShortcutsDirectoryExists()
    }

    // MARK: - Public Methods

    /// Import a shortcut file from the given URL
    func importShortcut(from url: URL) {
        guard url.pathExtension == "shortcut" else {
            handleError("Not a .shortcut file")
            return
        }

        isProcessing = true
        lastMessage = ""
        lastError = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                // Ensure destination directory exists
                try self.ensureShortcutsDirectoryExists()

                // Copy file to ~/Library/Shortcuts/
                let destinationURL = self.shortcutsLibraryURL.appendingPathComponent(url.lastPathComponent)
                try self.fileManager.copyItem(at: url, to: destinationURL)

                self.logger.info("Copied shortcut to: \(destinationURL.path, privacy: .public)")

                // Build deep link URL
                guard let deeplinkURL = self.buildImportDeepLink(for: destinationURL) else {
                    throw ShortcutDropError.invalidDeepLink
                }

                self.logger.info("Opening deep link: \(deeplinkURL.absoluteString, privacy: .public)")

                // Open deep link
                self.openDeepLink(deeplinkURL)

                DispatchQueue.main.async {
                    self.lastMessage = "✅ Shortcut installed successfully"
                    self.isProcessing = false

                    // Clear success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.lastMessage = ""
                    }
                }
            } catch {
                self.handleError(error.localizedDescription)
            }
        }
    }

    /// Check if a URL is a valid shortcut file
    func isValidShortcutFile(_ url: URL) -> Bool {
        url.pathExtension == "shortcut"
    }

    // MARK: - Private Methods

    private func ensureShortcutsDirectoryExists() throws {
        var isDirectory: ObjCBool = false

        if !fileManager.fileExists(atPath: shortcutsLibraryURL.path, isDirectory: &isDirectory) {
            try fileManager.createDirectory(at: shortcutsLibraryURL, withIntermediateDirectories: true)
            logger.info("Created Shortcuts directory at: \(self.shortcutsLibraryURL.path, privacy: .public)")
        } else if !isDirectory.boolValue {
            throw ShortcutDropError.directoryNotDirectory
        }
    }

    private func buildImportDeepLink(for url: URL) -> URL? {
        // shortcuts://import-shortcut?url=file:///Users/.../file.shortcut&name=filename&silent=true
        // IMPORTANT: macOS file URLs require TRIPLE slashes: file:///

        var components = URLComponents(string: "shortcuts://import-shortcut")

        // Build file URL with triple slash
        let filePath = url.path
        let fileURLString = "file:///\(filePath)"

        components?.queryItems = [
            URLQueryItem(name: "url", value: fileURLString),
            URLQueryItem(name: "name", value: url.deletingPathExtension().lastPathComponent),
            URLQueryItem(name: "silent", value: "true")
        ]

        return components?.url
    }

    private func openDeepLink(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func handleError(_ message: String) {
        logger.error("Shortcut import failed: \(message, privacy: .public)")

        DispatchQueue.main.async { [weak self] in
            self?.lastError = message
            self?.isProcessing = false

            // Clear error message after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self?.lastError = nil
            }
        }
    }
}

// MARK: - Shortcut Drop Error

enum ShortcutDropError: LocalizedError {
    case notAShortcutFile
    case copyFailed(String)
    case directoryNotDirectory
    case invalidDeepLink

    var errorDescription: String? {
        switch self {
        case .notAShortcutFile:
            return "Not a .shortcut file"
        case .copyFailed(let detail):
            return "Failed to copy shortcut: \(detail)"
        case .directoryNotDirectory:
            return "Shortcuts directory exists but is not a directory"
        case .invalidDeepLink:
            return "Could not build import deep link"
        }
    }
}
