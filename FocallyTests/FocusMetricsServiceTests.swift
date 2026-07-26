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

    func testDailyMetrics_modeTypeBreakdown() {
        sut.recordSession(makeRecord(duration: 1200, modeID: FocusMode.focusTimeID))
        sut.recordSession(makeRecord(duration: 600, modeID: FocusMode.meetingID))
        sut.recordSession(makeRecord(duration: 300, modeID: FocusMode.inboxID))
        sut.recordSession(makeRecord(duration: 900, modeID: UUID()))

        let daily = sut.getDailyMetrics(for: Date())!
        XCTAssertEqual(daily.focusTimeDuration, 1200)
        XCTAssertEqual(daily.meetingDuration, 600)
        XCTAssertEqual(daily.inboxDuration, 300)
        XCTAssertEqual(daily.customDuration, 900)
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

    func testWeeklyMetrics_modeTypeBreakdown() {
        let monday = isoDate(year: 2026, month: 7, day: 20, hour: 9)

        sut.recordSession(makeRecord(startTime: monday, duration: 1200, modeID: FocusMode.focusTimeID))
        sut.recordSession(makeRecord(startTime: monday, duration: 900, modeID: FocusMode.meetingID))
        sut.recordSession(makeRecord(startTime: monday, duration: 300, modeID: FocusMode.inboxID))
        sut.recordSession(makeRecord(startTime: monday, duration: 600, modeID: UUID()))

        let weekly = sut.getWeeklyMetrics(for: monday)
        XCTAssertEqual(weekly?.focusTimeDuration, 1200)
        XCTAssertEqual(weekly?.meetingDuration, 900)
        XCTAssertEqual(weekly?.inboxDuration, 300)
        XCTAssertEqual(weekly?.customDuration, 600)
    }

    func testWeeklyMetrics_dayOfWeekFilter() {
        let monday = isoDate(year: 2026, month: 7, day: 20, hour: 9)
        let tuesday = isoDate(year: 2026, month: 7, day: 21, hour: 9)

        sut.recordSession(makeRecord(startTime: monday, duration: 1200, modeID: FocusMode.focusTimeID))
        sut.recordSession(makeRecord(startTime: tuesday, duration: 900, modeID: FocusMode.meetingID))

        let weekly = sut.getWeeklyMetrics(for: monday, dayOfWeeks: [2])
        XCTAssertEqual(weekly?.totalFocusTime, 1200)
        XCTAssertEqual(weekly?.focusTimeDuration, 1200)
        XCTAssertEqual(weekly?.meetingDuration, 0)
        XCTAssertEqual(weekly?.daysWithData, 1)
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

    func testMonthlyMetrics_modeTypeBreakdown() {
        let julyFirst = isoDate(year: 2026, month: 7, day: 1, hour: 9)

        sut.recordSession(makeRecord(startTime: julyFirst, duration: 1000, modeID: FocusMode.focusTimeID))
        sut.recordSession(makeRecord(startTime: julyFirst, duration: 800, modeID: FocusMode.meetingID))
        sut.recordSession(makeRecord(startTime: julyFirst, duration: 400, modeID: FocusMode.inboxID))
        sut.recordSession(makeRecord(startTime: julyFirst, duration: 200, modeID: UUID()))

        let monthly = sut.getMonthlyMetrics(for: julyFirst)
        XCTAssertEqual(monthly?.focusTimeDuration, 1000)
        XCTAssertEqual(monthly?.meetingDuration, 800)
        XCTAssertEqual(monthly?.inboxDuration, 400)
        XCTAssertEqual(monthly?.customDuration, 200)
    }

    func testMonthlyMetrics_dayOfMonthFilter() {
        let firstDay = isoDate(year: 2026, month: 7, day: 1, hour: 9)
        let fifteenthDay = isoDate(year: 2026, month: 7, day: 15, hour: 9)

        sut.recordSession(makeRecord(startTime: firstDay, duration: 1000, modeID: FocusMode.focusTimeID))
        sut.recordSession(makeRecord(startTime: fifteenthDay, duration: 500, modeID: FocusMode.meetingID))

        let monthly = sut.getMonthlyMetrics(for: firstDay, daysOfMonth: [15])
        XCTAssertEqual(monthly?.totalFocusTime, 500)
        XCTAssertEqual(monthly?.meetingDuration, 500)
        XCTAssertEqual(monthly?.focusTimeDuration, 0)
    }

    func testMonthlyMetrics_lastDayFilter() {
        let lastDay = isoDate(year: 2026, month: 7, day: 31, hour: 9)
        let earlierDay = isoDate(year: 2026, month: 7, day: 30, hour: 9)

        sut.recordSession(makeRecord(startTime: lastDay, duration: 700, modeID: FocusMode.focusTimeID))
        sut.recordSession(makeRecord(startTime: earlierDay, duration: 300, modeID: FocusMode.meetingID))

        let monthly = sut.getMonthlyMetrics(for: lastDay, daysOfMonth: [0])
        XCTAssertEqual(monthly?.totalFocusTime, 700)
        XCTAssertEqual(monthly?.focusTimeDuration, 700)
        XCTAssertEqual(monthly?.meetingDuration, 0)
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
        let modeType: FocusModeType
        switch modeID {
        case FocusMode.focusTimeID:
            modeType = .focusTime
        case FocusMode.meetingID:
            modeType = .meeting
        case FocusMode.inboxID:
            modeType = .inbox
        default:
            modeType = .custom
        }

        return FocusSessionRecord(
            modeType: modeType,
            modeID: modeID,
            startTime: startTime,
            endTime: startTime.addingTimeInterval(duration),
            duration: duration,
            pomodorosCompleted: pomodoros
        )
    }

    private func isoDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone.current
        return Calendar(identifier: .iso8601).date(from: components)!
    }
}
