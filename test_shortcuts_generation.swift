#!/usr/bin/env swift

import Foundation

// Test script to verify shortcut generation
// This script runs independently to test TestShortcutGenerator

print("Testing TestShortcutGenerator...")

// The shortcuts should be generated at: ~/Library/Application Support/Focally/Shortcuts/
let fileManager = FileManager.default
let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
let shortcutsDir = appSupportURL.appendingPathComponent("Focally/Shortcuts")

print("Checking for shortcuts at: \(shortcutsDir.path)")

let focusOnURL = shortcutsDir.appendingPathComponent("Focally Focus On.shortcut")
let focusOffURL = shortcutsDir.appendingPathComponent("Focally Focus Off.shortcut")

var allExist = true

if fileManager.fileExists(atPath: focusOnURL.path) {
    print("✅ Focally Focus On.shortcut exists")
    if let attributes = try? fileManager.attributesOfItem(atPath: focusOnURL.path) {
        let size = attributes[.size] as? Int64 ?? 0
        print("   Size: \(size) bytes")
    }
} else {
    print("❌ Focally Focus On.shortcut does NOT exist")
    allExist = false
}

if fileManager.fileExists(atPath: focusOffURL.path) {
    print("✅ Focally Focus Off.shortcut exists")
    if let attributes = try? fileManager.attributesOfItem(atPath: focusOffURL.path) {
        let size = attributes[.size] as? Int64 ?? 0
        print("   Size: \(size) bytes")
    }
} else {
    print("❌ Focally Focus Off.shortcut does NOT exist")
    allExist = false
}

if allExist {
    print("\n✅ All test shortcuts exist!")
    print("\nYou can now test them by:")
    print("1. Dragging them to the Shortcuts app to import")
    print("2. Running them to verify they work")
    print("3. Dragging them to Focally's drop zone (TASK-039)")
} else {
    print("\n❌ Shortcuts not found. They should be generated on first app launch.")
    print("Run Focally once to generate them, or check the logs for errors.")
}

print("\nDone.")
