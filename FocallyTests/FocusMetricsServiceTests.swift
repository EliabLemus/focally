import XCTest
@testable import Focally

// MARK: - FocusMetricsService Tests

@MainActor
final class FocusMetricsServiceTests: XCTestCase {

    private var sut: FocusMetricsService!

    override func setUp() async throws {
        try await super.setUp()
        // Reset the singleton's data for each test
        sut = FocusMetricsService.shared
        sut.clearAllRecords()
    }

    override func tearDown() async throws {
        sut.clearAllRecords()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Recording

    func testRecordSession_addsRecord() {
        let record = makeRecord(duration: 600)
        sut.recordSession(record)

        XCTAssertEqual(sut.getDailyMetrics(for: Date())?.totalFocusTime, 600)
    }

    func testRecordSession_multipleRecords() {
        sut.recordSession(makeRecord(duration: 300))
        sut.recordSession(makeRecord(duration: 600))

        let daily = sut.getDailyMetrics(for: Date())
        XCTAssertEqual(daily?.totalFocusTime, 900)
    }

    // MARK: - Daily Aggregation

    func testDailyMetrics_noData_returnsNil() {
        XCTAssertNil(sut.getDailyMetrics(for: Date()))
    }

    func testDailyMetrics_pomodoroCount() {
        sut.recordSession(makeRecord(duration: 1500, pomodoros: 4, modeID: FocusMode.focusTimeID))
        sut.recordSession(makeRecord(duration: 300, pomodoros: nil, modeID: FocusMode.meetingID))

        let daily = sut.getDailyMetrics(for: Date())
        XCTAssertEqual(daily?.pomodorosCompleted, 4)
        XCTAssertEqual(daily?.meetingTime, 300)
        XCTAssertEqual(daily?.totalFocusTime, 1800)
    }

    func testDailyMetrics_dateBoundary() {
        // Record for yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        sut.recordSession(makeRecord(startTime: yesterday, duration: 600))

        // Today should have no data
        XCTAssertNil(sut.getDailyMetrics(for: Date()))
        // Yesterday should have data
        XCTAssertNotNil(sut.getDailyMetrics(for: yesterday))
    }

    // MARK: - Weekly Aggregation

    func testWeeklyMetrics_noData_returnsNil() {
        XCTAssertNil(sut.getWeeklyMetrics(for: Date()))
    }

    func testWeeklyMetrics_aggregatesWeek() {
        sut.recordSession(makeRecord(duration: 1500, pomodoros: 2, modeID: FocusMode.focusTimeID))
        sut.recordSession(makeRecord(duration: 1800, pomodoros: 3, modeID: FocusMode.focusTimeID))

        let weekly = sut.getWeeklyMetrics(for: Date())
        XCTAssertEqual(weekly?.pomodorosCompleted, 5)
        XCTAssertEqual(weekly?.totalFocusTime, 3300)
        XCTAssertEqual(weekly?.daysWithData, 1)
    }

    func testWeeklyMetrics_multipleDays() {
        let calendar = Calendar.current
        let today = Date()

        // Record today
        sut.recordSession(makeRecord(startTime: today, duration: 600))
        // Record 3 days ago (same week typically)
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        sut.recordSession(makeRecord(startTime: threeDaysAgo, duration: 900))

        let weekly = sut.getWeeklyMetrics(for: today)
        XCTAssertGreaterThanOrEqual(weekly!.daysWithData, 1)
    }

    // MARK: - Monthly Aggregation

    func testMonthlyMetrics_noData_returnsNil() {
        XCTAssertNil(sut.getMonthlyMetrics(for: Date()))
    }

    func testMonthlyMetrics_aggregatesMonth() {
        sut.recordSession(makeRecord(duration: 1500, pomodoros: 4))
        sut.recordSession(makeRecord(duration: 1800, pomodoros: 6))

        let monthly = sut.getMonthlyMetrics(for: Date())
        XCTAssertEqual(monthly?.pomodorosCompleted, 10)
        XCTAssertEqual(monthly?.totalFocusTime, 3300)
    }

    func testMonthlyMetrics_crossMonthBoundary() {
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!

        sut.recordSession(makeRecord(startTime: lastMonth, duration: 600))

        // This month should be empty
        XCTAssertNil(sut.getMonthlyMetrics(for: Date()))
        // Last month should have data
        XCTAssertNotNil(sut.getMonthlyMetrics(for: lastMonth))
    }

    // MARK: - Duration Formatting

    func testFormatDuration_minutes() {
        XCTAssertEqual(DailyMetrics.formatDuration(900), "15m")
        XCTAssertEqual(DailyMetrics.formatDuration(300), "5m")
    }

    func testFormatDuration_hours() {
        XCTAssertEqual(DailyMetrics.formatDuration(5400), "1h 30m")
        XCTAssertEqual(DailyMetrics.formatDuration(3600), "1h 0m")
    }

    // MARK: - Helpers

    private func makeRecord(
        startTime: Date = Date(),
        duration: TimeInterval,
        pomodoros: Int? = nil,
        modeID: UUID = FocusMode.focusTimeID
    ) -> FocusSessionRecord {
        FocusSessionRecord(
            modeName: "Test",
            modeID: modeID,
            startTime: startTime,
            endTime: startTime.addingTimeInterval(duration),
            duration: duration,
            pomodorosCompleted: pomodoros
        )
    }
}
