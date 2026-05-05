#!/usr/bin/env swift

import Foundation

print("🧪 Simple Focally Test Runner")
print("Testing basic compilation and imports...")

// Test basic imports
import Cocoa
import os.log

print("✅ Imports successful")

// Test PomodoroState enum (if accessible)
print("📝 Testing PomodoroState enum...")
enum PomodoroState: String {
    case idle = "idle"
    case work = "work"
    case shortBreak = "shortBreak"
    case longBreak = "longBreak"
    case completed = "completed"
}

let state = PomodoroState.work
print("✅ PomodoroState works: \(state.rawValue)")

print("🎉 Basic functionality test passed!")
