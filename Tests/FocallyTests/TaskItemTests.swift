import XCTest
@testable import Focally

final class TaskItemTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    // MARK: - Sanitization

    func testTitleIsTrimmedAndLengthCapped() {
        let task = TaskItem(title: "  Fix login bug  ")
        XCTAssertEqual(task.sanitizedTitle, "Fix login bug")

        let long = TaskItem(title: String(repeating: "a", count: 500))
        XCTAssertEqual(long.sanitizedTitle.count, TaskItem.maxTitleLength)
    }

    func testBlankTitleIsInvalid() {
        XCTAssertFalse(TaskItem(title: "   ").isValid)
        XCTAssertTrue(TaskItem(title: "Real work").isValid)
    }

    // MARK: - Work queue ordering

    func testOpenTasksSortBeforeCompleted() {
        let done = TaskItem(title: "done", isCompleted: true, createdAt: date(2026, 9, 1))
        let open = TaskItem(title: "open", createdAt: date(2026, 9, 2))
        let sorted = [done, open].sorted(by: Array.workQueueOrder)
        XCTAssertEqual(sorted.map(\.title), ["open", "done"])
    }

    func testOpenTasksSortByDueDateWithNilDueLast() {
        let noDue = TaskItem(title: "no due", createdAt: date(2026, 9, 1))
        let later = TaskItem(title: "later", createdAt: date(2026, 9, 1), dueDate: date(2026, 9, 20))
        let sooner = TaskItem(title: "sooner", createdAt: date(2026, 9, 1), dueDate: date(2026, 9, 17))
        let sorted = [noDue, later, sooner].sorted(by: Array.workQueueOrder)
        XCTAssertEqual(sorted.map(\.title), ["sooner", "later", "no due"])
    }

    func testCompletedTasksSortByMostRecentlyCompletedFirst() {
        let old = TaskItem(title: "old", isCompleted: true, createdAt: date(2026, 9, 1),
                           completedAt: date(2026, 9, 10))
        let recent = TaskItem(title: "recent", isCompleted: true, createdAt: date(2026, 9, 1),
                              completedAt: date(2026, 9, 15))
        let sorted = [old, recent].sorted(by: Array.workQueueOrder)
        XCTAssertEqual(sorted.map(\.title), ["recent", "old"])
    }

    // MARK: - Codable round trip

    func testCodableRoundTripPreservesAllFields() throws {
        let task = TaskItem(title: "Ship release", createdAt: date(2026, 9, 16, 9, 30),
                            dueDate: date(2026, 9, 17, 18, 0), notes: "bump version")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode([task])
        let decoded = try decoder.decode([TaskItem].self, from: data)

        XCTAssertEqual(decoded, [task])
    }
}
