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

    // MARK: - Private Methods

    private func ensureShortcutsDirectoryExists() throws {
        var isDirectory: ObjCBool = false

        if !fileManager.fileExists(atPath: shortcutsDirectory.path, isDirectory: &isDirectory) {
            try fileManager.createDirectory(at: shortcutsDirectory, withIntermediateDirectories: true)
            logger.info("Created shortcuts directory at: \(shortcutsDirectory.path, privacy: .public)")
        }
    }

    // MARK: - Shortcut Generators

    private func generateFocusOnShortcut() throws {
        // Create temporary workflow file
        let tempDir = fileManager.temporaryDirectory
        let workflowFile = tempDir.appendingPathComponent("focally_focus_on.workflow")

        // Create workflow JSON
        let workflow: [String: Any] = [
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
            "WFWorkflowIcon": [
                "WFWorkflowIconStartColor": 2077030912,
                "WFWorkflowIconGlyphNumber": 61440
            ],
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowMinimumClientVersionString": "900",
            "WFWorkflowTypes": ["NCWidget", "WatchKit"]
        ]

        let workflowData = try JSONSerialization.data(withJSONObject: workflow, options: .prettyPrinted)
        try workflowData.write(to: workflowFile)

        logger.info("Created workflow file at \(workflowFile.path)")

        // Sign the workflow using shortcuts command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["sign", "--input", workflowFile.path, "--output", shortcutsDirectory.appendingPathComponent("Focally Start Focus.shortcut").path]

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
        try? fileManager.removeItem(at: workflowFile)
    }

    private func generateFocusOffShortcut() throws {
        // Create temporary workflow file
        let tempDir = fileManager.temporaryDirectory
        let workflowFile = tempDir.appendingPathComponent("focally_focus_off.workflow")

        // Create workflow JSON
        let workflow: [String: Any] = [
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
            "WFWorkflowIcon": [
                "WFWorkflowIconStartColor": 2077030912,
                "WFWorkflowIconGlyphNumber": 61440
            ],
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowMinimumClientVersionString": "900",
            "WFWorkflowTypes": ["NCWidget", "WatchKit"]
        ]

        let workflowData = try JSONSerialization.data(withJSONObject: workflow, options: .prettyPrinted)
        try workflowData.write(to: workflowFile)

        logger.info("Created workflow file at \(workflowFile.path)")

        // Sign the workflow using shortcuts command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["sign", "--input", workflowFile.path, "--output", shortcutsDirectory.appendingPathComponent("Focally End Focus.shortcut").path]

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
        try? fileManager.removeItem(at: workflowFile)
    }
}
