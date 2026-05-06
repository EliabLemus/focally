import Foundation
import os.log
import SwiftUI

// MARK: - Test Shortcut Generator

/// Generates test shortcuts for Focally integration
/// Creates binary plist .shortcut files that can be imported via drag & drop
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
            logger.info("Created shortcuts directory at: \(self.shortcutsDirectory.path, privacy: .public)")
        }
    }

    // MARK: - Shortcut Generators

    private func generateFocusOnShortcut() throws {
        let name = "Focally Focus On"
        let actions: [[String: Any]] = [
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
        ]

        let icon: [String: Any] = [
            "WFWorkflowIconStartColor": 2077030912,
            "WFWorkflowIconGlyphNumber": 61440
        ]

        let shortcutData = try buildShortcutPlist(
            name: name,
            actions: actions,
            icon: icon
        )

        let url = shortcutsDirectory.appendingPathComponent("\(name).shortcut")
        try shortcutData.write(to: url)
        logger.info("Generated \(name).shortcut at \(url.path, privacy: .public)")
    }

    private func generateFocusOffShortcut() throws {
        let name = "Focally Focus Off"
        let actions: [[String: Any]] = [
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
        ]

        let icon: [String: Any] = [
            "WFWorkflowIconStartColor": 2077030912,
            "WFWorkflowIconGlyphNumber": 61440
        ]

        let shortcutData = try buildShortcutPlist(
            name: name,
            actions: actions,
            icon: icon
        )

        let url = shortcutsDirectory.appendingPathComponent("\(name).shortcut")
        try shortcutData.write(to: url)
        logger.info("Generated \(name).shortcut at \(url.path, privacy: .public)")
    }

    // MARK: - Plist Builder

    private func buildShortcutPlist(name: String, actions: [[String: Any]], icon: [String: Any]) throws -> Data {
        let workflow: [String: Any] = [
            "WFWorkflowActions": actions,
            "WFWorkflowClientVersion": "2605.0.5",
            "WFWorkflowIcon": [
                "WFWorkflowIconStartColor": icon["WFWorkflowIconStartColor"] ?? 2077030912,
                "WFWorkflowIconGlyphNumber": icon["WFWorkflowIconGlyphNumber"] ?? 61440
            ],
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowMinimumClientVersionString": "900",
            "WFWorkflowInputContentItemClasses": ["WFAppStoreAppContentItem", "WFArticleContentItem", "WFContactContentItem", "WFDateContentItem", "WFEmailAddressContentItem", "WFFolderContentItem", "WFGenericFileContentItem", "WFImageContentItem", "WFiTunesProductContentItem", "WFLocationContentItem", "WFDCMapLinkContentItem", "WFAVAssetContentItem", "WFPDFContentItem", "WFPhoneNumberContentItem", "WFRichTextContentItem", "WFSafariWebPageContentItem", "WFStringContentItem", "WFURLContentItem"],
            "WFWorkflowOutputContentItemClasses": ["WFAppStoreAppContentItem", "WFArticleContentItem", "WFContactContentItem", "WFDateContentItem", "WFEmailAddressContentItem", "WFFolderContentItem", "WFGenericFileContentItem", "WFImageContentItem", "WFiTunesProductContentItem", "WFLocationContentItem", "WFDCMapLinkContentItem", "WFAVAssetContentItem", "WFPDFContentItem", "WFPhoneNumberContentItem", "WFRichTextContentItem", "WFSafariWebPageContentItem", "WFStringContentItem", "WFURLContentItem"],
            "WFWorkflowTypes": ["NCWidget", "WatchKit"]
        ]

        let plist = try PropertyListSerialization.data(
            fromPropertyList: workflow,
            format: .binary,
            options: 0
        )

        return plist
    }
}
