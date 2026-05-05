import XCTest
@testable import Focally

// MARK: - PomodoroState Tests (Test @testable import with enums)

class PomodoroStateTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(PomodoroState.idle.rawValue, "idle")
        XCTAssertEqual(PomodoroState.work.rawValue, "work")
        XCTAssertEqual(PomodoroState.shortBreak.rawValue, "shortBreak")
        XCTAssertEqual(PomodoroState.longBreak.rawValue, "longBreak")
        XCTAssertEqual(PomodoroState.completed.rawValue, "completed")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(PomodoroState(rawValue: "work"), .work)
        XCTAssertNil(PomodoroState(rawValue: "invalid"))
    }
}
