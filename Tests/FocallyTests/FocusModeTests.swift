import XCTest
@testable import Focally

@MainActor
final class FocusModeTests: XCTestCase {
    func testBuiltInModesMatchExpectedDefaults() {
        XCTAssertEqual(FocusMode.builtInModes.map(\.name), ["Focus Time", "Meeting", "Inbox"])
        XCTAssertEqual(FocusMode.builtInModes.map(\.emoji), [":brain:", ":calendar:", ":email:"])
        XCTAssertEqual(FocusMode.builtInModes.map(\.durationMinutes), [25, 30, 15])
    }

    func testSanitizedModeClampsAndKeepsPomodoroIndependentWhenDNDIsOff() {
        let mode = FocusMode(
            id: FocusMode.focusTimeID,
            name: "Focus Time",
            emoji: "   ",
            statusText: "   ",
            durationMinutes: 999,
            enableMacOSDND: false,
            enableSlackDND: false,
            enablePomodoro: true,
            pomodoroWorkMinutes: 1,
            pomodoroBreakMinutes: 0,
            pomodoroLongBreakMinutes: 3,
            pomodoroRounds: 99
        )

        let sanitized = mode.sanitized()
        XCTAssertEqual(sanitized.emoji, ":brain:")
        XCTAssertEqual(sanitized.statusText, "Focus Time")
        XCTAssertEqual(sanitized.durationMinutes, 120)
        XCTAssertTrue(sanitized.enablePomodoro)
        XCTAssertEqual(sanitized.pomodoroWorkMinutes, 5)
        XCTAssertEqual(sanitized.pomodoroBreakMinutes, 1)
        XCTAssertEqual(sanitized.pomodoroRounds, 12)
    }

    func testStoreLoadsOnlyThreeOrderedModes() {
        let suiteName = "FocusModeStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        // Clear disk cache too (same path as FocusModeStore uses: ~/.focally/modes.json)
        let diskURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".focally/modes.json")
        try? FileManager.default.removeItem(at: diskURL)

        let store = FocusModeStore(defaults: defaults)
        let modeIDs = store.modes.map(\.id)
        // Check first 3 are built-in in correct order
        XCTAssertEqual(Array(modeIDs.prefix(3)), [FocusMode.focusTimeID, FocusMode.meetingID, FocusMode.inboxID])
        // No extra modes should exist (only built-ins)
        XCTAssertEqual(modeIDs.count, 3)
    }
}
