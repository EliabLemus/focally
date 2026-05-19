import XCTest
@testable import Focally

// MARK: - HistoryService Tests (Test @testable import)

class HistoryServiceTests: XCTestCase {

    func testLoadEmptyDate() {
        let service = HistoryService.shared
        // Use a date far in past with no data
        let date = Date.distantPast
        let sessions = service.loadSessions(for: date)
        XCTAssertTrue(sessions.isEmpty)
    }

    func testSessionEntryCodable() throws {
        let entry = HistoryService.SessionEntry(
            id: UUID(),
            activity: "Testing",
            emoji: "🧪",
            durationMinutes: 25,
            startTime: Date(),
            endTime: Date().addingTimeInterval(25 * 60),
            round: 1
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(HistoryService.SessionEntry.self, from: data)

        XCTAssertEqual(decoded.activity, entry.activity)
        XCTAssertEqual(decoded.emoji, entry.emoji)
        XCTAssertEqual(decoded.durationMinutes, entry.durationMinutes)
        XCTAssertEqual(decoded.round, entry.round)
    }

    func testRecordAndLoad() {
        let service = HistoryService.shared
        let activity: String = "UnitTest-\(UUID().uuidString.prefix(8))"
        service.recordWorkSession(
            activity: activity,
            emoji: "🧪",
            durationMinutes: 1,
            round: 0,
            startTime: Date(),
            endTime: Date()
        )

        let sessions = service.loadTodaySessions()
        let recorded = sessions.last { $0.activity == activity }
        XCTAssertNotNil(recorded)
        XCTAssertEqual(recorded?.durationMinutes, 1)
    }
}
