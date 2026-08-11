import XCTest
@testable import Focally

final class FocusSessionDraftTests: XCTestCase {
    func testBlankActivityFallsBackToSanitizedModeNameAndClampsDuration() {
        let baseMode = FocusMode(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "  Deep Work  ",
            emoji: ":brain:",
            statusText: "Heads down",
            durationMinutes: 25,
            enableMacOSDND: true,
            enableSlackDND: true,
            typeDescriptor: .builtIn(.focusTime)
        )
        let original = baseMode
        var draft = FocusSessionDraft(mode: baseMode)
        draft.activity = "   \n"
        draft.durationMinutes = 1

        let resolved = draft.resolvedMode()

        XCTAssertEqual(resolved.name, "Deep Work")
        XCTAssertEqual(resolved.durationMinutes, 5)
        XCTAssertEqual(baseMode, original)
    }

    func testNonBlankActivityIsTrimmedAndUpperDurationIsClamped() {
        let baseMode = FocusMode(name: "Focus", durationMinutes: 25)
        var draft = FocusSessionDraft(mode: baseMode)
        draft.activity = "  Ship TASK-053  "
        draft.durationMinutes = 999

        let resolved = draft.resolvedMode()

        XCTAssertEqual(resolved.name, "Ship TASK-053")
        XCTAssertEqual(resolved.durationMinutes, 120)
        XCTAssertEqual(baseMode.name, "Focus")
        XCTAssertEqual(baseMode.durationMinutes, 25)
    }

    func testPomodoroDraftInitialDurationUsesSavedWorkDuration() {
        let baseMode = FocusMode(
            name: "Pomodoro",
            durationMinutes: 90,
            enablePomodoro: true,
            pomodoroWorkMinutes: 25,
            pomodoroBreakMinutes: 5,
            pomodoroRounds: 4
        )

        let draft = FocusSessionDraft(mode: baseMode)

        XCTAssertEqual(draft.durationMinutes, 25)
    }

    func testPomodoroOverrideChangesOnlySessionWorkDuration() {
        let baseMode = FocusMode(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            name: "Pomodoro",
            emoji: ":tomato:",
            statusText: "Focusing",
            durationMinutes: 50,
            enableMacOSDND: true,
            enableSlackDND: false,
            enablePomodoro: true,
            pomodoroWorkMinutes: 50,
            pomodoroBreakMinutes: 7,
            pomodoroLongBreakMinutes: 20,
            pomodoroRounds: 6,
            breakLabel: ":coffee: Reset",
            typeDescriptor: .builtIn(.userCustom)
        )
        let original = baseMode
        var draft = FocusSessionDraft(mode: baseMode)
        draft.activity = "Write launch brief"
        draft.durationMinutes = 35

        let resolved = draft.resolvedMode()

        XCTAssertEqual(resolved.id, baseMode.id)
        XCTAssertEqual(resolved.name, "Write launch brief")
        XCTAssertEqual(resolved.durationMinutes, 35)
        XCTAssertEqual(resolved.pomodoroWorkMinutes, 35)
        XCTAssertEqual(resolved.pomodoroBreakMinutes, 7)
        XCTAssertEqual(resolved.pomodoroLongBreakMinutes, 20)
        XCTAssertEqual(resolved.pomodoroRounds, 6)
        XCTAssertEqual(resolved.emoji, ":tomato:")
        XCTAssertEqual(resolved.statusText, "Focusing")
        XCTAssertTrue(resolved.enableMacOSDND)
        XCTAssertFalse(resolved.enableSlackDND)
        XCTAssertEqual(resolved.breakLabel, ":coffee: Reset")
        XCTAssertEqual(resolved.typeDescriptor, .builtIn(.userCustom))
        XCTAssertEqual(baseMode, original)
    }

    func testNonPomodoroOverrideLeavesPomodoroConfigurationUntouched() {
        let baseMode = FocusMode(
            name: "Meeting",
            durationMinutes: 30,
            enablePomodoro: false,
            pomodoroWorkMinutes: 45,
            pomodoroBreakMinutes: 8,
            pomodoroLongBreakMinutes: 25,
            pomodoroRounds: 3
        )
        var draft = FocusSessionDraft(mode: baseMode)
        draft.durationMinutes = 20

        let resolved = draft.resolvedMode()

        XCTAssertEqual(resolved.durationMinutes, 20)
        XCTAssertEqual(resolved.pomodoroWorkMinutes, 45)
        XCTAssertEqual(resolved.pomodoroBreakMinutes, 8)
        XCTAssertEqual(resolved.pomodoroLongBreakMinutes, 25)
        XCTAssertEqual(resolved.pomodoroRounds, 3)
    }
}
