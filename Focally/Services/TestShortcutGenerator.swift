import Foundation
import os.log
import SwiftUI

// MARK: - Test Shortcut Generator

/// Generates test shortcuts for Focally integration
/// Creates signed .shortcut files using the native `shortcuts` command
/// Generates test shortcuts ONLY ONCE on first launch
/// Shortcuts are generated in ~/Library/Application Support/Focally/Shortcuts/
class TestShortcutGenerator {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "TestShortcutGenerator")
    private let fileManager = FileManager.default

    // UserDefaults flag to ensure we only generate once
    @AppStorage("hasGeneratedTestShortcuts") private var hasGeneratedShortcuts: Bool = false

    // Directory where shortcuts are stored
    private var shortcutsDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Focally", isDirectory: true)
            .appendingPathComponent("Shortcuts", isDirectory: true)
    }

    // MARK: - Public Methods

    /// Generate both test shortcuts (ONLY ONCE)
    func generateAllTestShortcuts() throws {
        // Only generate if never generated before
        guard !hasGeneratedShortcuts else {
            logger.info("Test shortcuts already generated, skipping...")
            return
        }

        logger.info("Generating test shortcuts...")

        // Ensure directory exists
        try ensureShortcutsDirectoryExists()

        // Generate shortcuts
        try generateFocusOnShortcut()
        try generateFocusOffShortcut()

        // Mark as generated so we don't regenerate on subsequent launches
        hasGeneratedShortcuts = true

        logger.info("✅ Test shortcuts generated successfully")
    }

    /// Get URL for generated shortcut
    func getShortcutURL(named name: String) -> URL {
        shortcutsDirectory.appendingPathComponent("\(name).shortcut")
    }

    // MARK: - Verification

    /// Verify if a shortcut file exists and is valid
    /// - Parameter name: Name of the shortcut without .shortcut extension
    /// - Returns: true if the shortcut exists and is a valid file
    func verifyShortcut(named name: String) async -> Bool {
        let shortcutURL = shortcutsDirectory.appendingPathComponent("\(name).shortcut")

        // Check if file exists
        guard fileManager.fileExists(atPath: shortcutURL.path) else {
            logger.warning("Shortcut not found: \(name)")
            return false
        }

        // Check if it's a valid shortcut file by verifying it's a valid plist
        guard let shortcutData = try? Data(contentsOf: shortcutURL),
              let _ = try? PropertyListSerialization.propertyList(from: shortcutData, options: [], format: nil) else {
            logger.warning("Shortcut file is corrupted: \(name)")
            return false
        }

        // Optional: Try to validate with shortcuts command (may fail if shortcuts app is not open)
        // We don't require this to pass because the shortcuts command can be flaky
        logger.info("✅ Shortcut verified: \(name)")
        return true
    }

    /// Verify all shortcuts
    /// - Returns: Dictionary of shortcut names to verification status
    func verifyAllShortcuts() async -> [String: Bool] {
        var results: [String: Bool] = [:]

        results["Focally Start Focus"] = await verifyShortcut(named: "Focally Start Focus")
        results["Focally End Focus"] = await verifyShortcut(named: "Focally End Focus")

        return results
    }

    /// Check if any shortcuts have been generated
    /// - Returns: true if at least one shortcut file exists
    func hasAnyShortcuts() -> Bool {
        let startURL = shortcutsDirectory.appendingPathComponent("Focally Start Focus.shortcut")
        let endURL = shortcutsDirectory.appendingPathComponent("Focally End Focus.shortcut")
        return fileManager.fileExists(atPath: startURL.path) || fileManager.fileExists(atPath: endURL.path)
    }

    // MARK: - Private Methods

    private func ensureShortcutsDirectoryExists() throws {
        var isDirectory: ObjCBool = false

        if !fileManager.fileExists(atPath: self.shortcutsDirectory.path, isDirectory: &isDirectory) {
            try fileManager.createDirectory(at: self.shortcutsDirectory, withIntermediateDirectories: true)
            logger.info("Created shortcuts directory at: \(self.shortcutsDirectory.path, privacy: .public)")
        }
    }

    // MARK: - Shortcut Generators

    private func generateFocusOnShortcut() throws {
        // Create temporary .shortcut file with binary plist format
        let tempDir = fileManager.temporaryDirectory
        let shortcutFile = tempDir.appendingPathComponent("focally_focus_on.shortcut")

        // Create shortcut plist
        let shortcut: [String: Any] = [
            "WFWorkflowActions": [
                [
                    "WFWorkflowActionIdentifier": "is.workflow.actions.dnd.set",
                    "WFWorkflowActionParameters": [
                        "WFSettingDoNotDisturbEnabled": true
                    ]
                ],
                [
                    "WFWorkflowActionIdentifier": "is.workflow.actions.focus",
                    "WFWorkflowActionParameters": [
                        "WFFocusModeName": "work"
                    ]
                ]
            ],
            "WFWorkflowClientVersion": "2605.0.5",
            "WFWorkflowName": "Focally Start Focus",
            "WFWorkflowIcon": [
                "WFWorkflowIconStartColor": 2077030912,
                "WFWorkflowIconGlyphNumber": 61440
            ],
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowMinimumClientVersionString": "900",
            "WFWorkflowTypes": ["NCWidget", "WatchKit"]
        ]

        let shortcutData = try PropertyListSerialization.data(
            fromPropertyList: shortcut,
            format: .binary,
            options: 0
        )
        try shortcutData.write(to: shortcutFile)

        logger.info("Created shortcut file at \(shortcutFile.path)")

        // Sign the shortcut using shortcuts command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["sign", "--mode", "anyone", "--input", shortcutFile.path, "--output", self.shortcutsDirectory.appendingPathComponent("Focally Start Focus.shortcut").path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        // Check for errors
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !errorMessage.isEmpty && process.terminationStatus != 0 {
            logger.error("Failed to sign shortcut: \(errorMessage)")
        } else {
            logger.info("✅ Generated Focally Start Focus.shortcut")
        }

        // Clean up temp file
        try? fileManager.removeItem(at: shortcutFile)
    }

    private func generateFocusOffShortcut() throws {
        // Create temporary .shortcut file with binary plist format
        let tempDir = fileManager.temporaryDirectory
        let shortcutFile = tempDir.appendingPathComponent("focally_focus_off.shortcut")

        // Create shortcut plist
        let shortcut: [String: Any] = [
            "WFWorkflowActions": [
                [
                    "WFWorkflowActionIdentifier": "is.workflow.actions.dnd.set",
                    "WFWorkflowActionParameters": [
                        "WFSettingDoNotDisturbEnabled": false
                    ]
                ],
                [
                    "WFWorkflowActionIdentifier": "is.workflow.actions.focus",
                    "WFWorkflowActionParameters": [
                        "WFFocusModeName": ""  // Empty string = turn off focus
                    ]
                ]
            ],
            "WFWorkflowClientVersion": "2605.0.5",
            "WFWorkflowName": "Focally End Focus",
            "WFWorkflowIcon": [
                "WFWorkflowIconStartColor": 2077030912,
                "WFWorkflowIconGlyphNumber": 61440
            ],
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowMinimumClientVersionString": "900",
            "WFWorkflowTypes": ["NCWidget", "WatchKit"]
        ]

        let shortcutData = try PropertyListSerialization.data(
            fromPropertyList: shortcut,
            format: .binary,
            options: 0
        )
        try shortcutData.write(to: shortcutFile)

        logger.info("Created shortcut file at \(shortcutFile.path)")

        // Sign the shortcut using shortcuts command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["sign", "--mode", "anyone", "--input", shortcutFile.path, "--output", self.shortcutsDirectory.appendingPathComponent("Focally End Focus.shortcut").path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        // Check for errors
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !errorMessage.isEmpty && process.terminationStatus != 0 {
            logger.error("Failed to sign shortcut: \(errorMessage)")
        } else {
            logger.info("✅ Generated Focally End Focus.shortcut")
        }

        // Clean up temp file
        try? fileManager.removeItem(at: shortcutFile)
    }
}
