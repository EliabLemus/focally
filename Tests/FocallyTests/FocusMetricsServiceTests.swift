import XCTest
@testable import Focally

// MARK: - FocusMetricsService Tests

@MainActor
final class FocusMetricsServiceTests: XCTestCase {

    private var sut: FocusMetricsService!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "FocusMetricsServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        sut = FocusMetricsService(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        sut = nil
        defaults = nil
        suiteName = nil
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

    func testUpsertAppendsThenReplacesInPlaceAndFindsExactRecord() {
        let first = makeRecord(duration: 10)
        let targetID = UUID()
        let original = FocusSessionRecord(id: targetID, modeType: .focusTime, modeID: FocusMode.focusTimeID,
            startTime: Date(), endTime: Date().addingTimeInterval(20), duration: 20)
        let replacement = FocusSessionRecord(id: targetID, modeType: .calendarVideoCall,
            modeID: FocusModeType.calendarVideoCall.id, startTime: Date(),
            endTime: Date().addingTimeInterval(30), duration: 30, source: .calendar)
        sut.upsertSession(first)
        sut.upsertSession(original)
        sut.upsertSession(replacement)
        XCTAssertEqual(sut.records.map(\.id), [first.id, targetID])
        XCTAssertEqual(sut.session(withID: targetID), replacement)
    }

    func testUpsertRespectsFiveThousandRecordCap() throws {
        let initial = (1...5_000).map { makeRecord(duration: TimeInterval($0)) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode(initial), forKey: "focally.metrics.records")
        sut = FocusMetricsService(defaults: defaults)
        sut.upsertSession(makeRecord(duration: 5_001))
        XCTAssertEqual(sut.records.count, 5_000)
        XCTAssertEqual(sut.records.first?.duration, 2)
        XCTAssertEqual(sut.records.last?.duration, 5_001)
    }

    func testV2AggregatesUseActiveAndExposePauseAndBreakTotals() {
        let start = Date()
        sut.recordSession(FocusSessionRecord(modeType: .focusTime, modeID: FocusMode.focusTimeID,
            startTime: start, endTime: start.addingTimeInterval(2400), duration: 2400,
            activeDuration: 1500, pausedDuration: 600, breakDuration: 300))

        let daily = sut.getDailyMetrics(for: start)
        XCTAssertEqual(daily?.totalFocusTime, 1500)
        XCTAssertEqual(daily?.focusTimeDuration, 1500)
        XCTAssertEqual(daily?.totalPausedTime, 600)
        XCTAssertEqual(daily?.totalBreakTime, 300)
        XCTAssertEqual(sut.getWeeklyMetrics(for: start)?.totalPausedTime, 600)
        XCTAssertEqual(sut.getWeeklyMetrics(for: start)?.totalBreakTime, 300)
        XCTAssertEqual(sut.getMonthlyMetrics(for: start)?.totalPausedTime, 600)
        XCTAssertEqual(sut.getMonthlyMetrics(for: start)?.totalBreakTime, 300)
    }

    func testLossyLoadingSkipsMalformedSiblingAndPreservesOrderAndRawStorage() throws {
        let first = makeRecord(duration: 60)
        let second = makeRecord(duration: 120)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let firstObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(first)) as? [String: Any])
        let secondObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(second)) as? [String: Any])
        let raw = try JSONSerialization.data(withJSONObject: [firstObject, ["broken": true], secondObject])
        defaults.set(raw, forKey: "focally.metrics.records")

        sut = FocusMetricsService(defaults: defaults)

        XCTAssertEqual(sut.records.map(\.id), [first.id, second.id])
        XCTAssertEqual(defaults.data(forKey: "focally.metrics.records"), raw)
    }

    func testAllValidLegacyRecordsLoadWithExactValues() throws {
        let raw = Data("""
        [{"id":"11111111-1111-1111-1111-111111111111","modeType":"focus_time","modeID":"\(FocusMode.focusTimeID.uuidString)","startTime":"2026-07-20T09:00:00Z","endTime":"2026-07-20T10:00:00Z","duration":725},
         {"id":"22222222-2222-2222-2222-222222222222","modeType":"meeting","modeID":"\(FocusMode.meetingID.uuidString)","startTime":"2026-07-20T10:00:00Z","endTime":"2026-07-20T11:00:00Z","duration":1811,"pomodorosCompleted":3}]
        """.utf8)
        defaults.set(raw, forKey: "focally.metrics.records")
        sut = FocusMetricsService(defaults: defaults)
        XCTAssertEqual(sut.records.map(\.recordVersion), [1, 1])
        XCTAssertEqual(sut.records.map(\.duration), [725, 1811])
        XCTAssertEqual(sut.records.map(\.activeDuration), [725, 1811])
    }

    func testMixedV1V2LoadRetainsOriginalOrderAndExactLegacyAggregate() throws {
        let v2 = FocusSessionRecord(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            modeType: .focusTime, modeID: FocusMode.focusTimeID,
            startTime: isoDate(year: 2026, month: 7, day: 20, hour: 11),
            endTime: isoDate(year: 2026, month: 7, day: 20, hour: 12), duration: 2_400,
            activeDuration: 1_500, pausedDuration: 600, breakDuration: 300)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let v2Object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(v2)) as? [String: Any])
        let v1Object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data("""
        {"id":"11111111-1111-1111-1111-111111111111","modeType":"focus_time","modeID":"\(FocusMode.focusTimeID.uuidString)","startTime":"2026-07-20T09:00:00Z","endTime":"2026-07-20T10:00:00Z","duration":725}
        """.utf8)) as? [String: Any])
        defaults.set(try JSONSerialization.data(withJSONObject: [v1Object, v2Object]), forKey: "focally.metrics.records")
        sut = FocusMetricsService(defaults: defaults)
        XCTAssertEqual(sut.records.map(\.recordVersion), [1, 2])
        let daily = try XCTUnwrap(sut.getDailyMetrics(for: isoDate(year: 2026, month: 7, day: 20, hour: 9)))
        XCTAssertEqual(daily.totalFocusTime, 2_225)
        XCTAssertEqual(daily.totalPausedTime, 600)
        XCTAssertEqual(daily.totalBreakTime, 300)
    }

    func testMutationAfterLegacyLoadLazilySavesEveryRecordAsV2() throws {
        let raw = Data("""
        [{"id":"11111111-1111-1111-1111-111111111111","modeType":"focus_time","modeID":"\(FocusMode.focusTimeID.uuidString)","startTime":"2026-07-20T09:00:00Z","endTime":"2026-07-20T10:00:00Z","duration":725}]
        """.utf8)
        defaults.set(raw, forKey: "focally.metrics.records")
        sut = FocusMetricsService(defaults: defaults)
        XCTAssertEqual(sut.records.first?.recordVersion, 1)
        sut.recordSession(makeRecord(duration: 60))
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let stored = try decoder.decode([FocusSessionRecord].self,
            from: XCTUnwrap(defaults.data(forKey: "focally.metrics.records")))
        XCTAssertEqual(stored.map(\.recordVersion), [2, 2])
        XCTAssertEqual(stored.first?.duration, 725)
    }

    func testMalformedOuterPayloadStaysStoredUntilExplicitMutation() {
        let raw = Data("{\"not\":\"an array\"}".utf8)
        defaults.set(raw, forKey: "focally.metrics.records")
        sut = FocusMetricsService(defaults: defaults)
        XCTAssertTrue(sut.records.isEmpty)
        XCTAssertEqual(defaults.data(forKey: "focally.metrics.records"), raw)

        sut.recordSession(makeRecord(duration: 60))
        XCTAssertNotEqual(defaults.data(forKey: "focally.metrics.records"), raw)
    }

    func testClearOnlyTouchesInjectedSuite() {
        let otherName = "FocusMetricsServiceTests.other.\(UUID().uuidString)"
        let other = UserDefaults(suiteName: otherName)!
        defer { other.removePersistentDomain(forName: otherName) }
        other.set(Data([1, 2, 3]), forKey: "focally.metrics.records")
        sut.recordSession(makeRecord(duration: 60))
        sut.clearAllRecords()
        XCTAssertNil(defaults.data(forKey: "focally.metrics.records"))
        XCTAssertEqual(other.data(forKey: "focally.metrics.records"), Data([1, 2, 3]))
    }

    func testExplicitMutationSavesV2AndCapsHistoryAtFiveThousandNewestRecords() throws {
        let initial = (1...5_000).map { makeRecord(duration: TimeInterval($0)) }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode(initial), forKey: "focally.metrics.records")
        sut = FocusMetricsService(defaults: defaults)
        sut.recordSession(makeRecord(duration: 5_001))
        XCTAssertEqual(sut.records.count, 5_000)
        XCTAssertEqual(sut.records.first?.duration, 2)
        XCTAssertEqual(sut.records.last?.duration, 5_001)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let stored = try decoder.decode([FocusSessionRecord].self,
            from: XCTUnwrap(defaults.data(forKey: "focally.metrics.records")))
        XCTAssertEqual(stored.count, 5_000)
        XCTAssertTrue(stored.allSatisfy { $0.recordVersion == 2 })
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

    func testWeeklyFilterAppliesToPauseAndBreakUsingSameRecords() {
        let monday = isoDate(year: 2026, month: 7, day: 20, hour: 9)
        let tuesday = isoDate(year: 2026, month: 7, day: 21, hour: 9)
        sut.recordSession(makeRecord(startTime: monday, duration: 100, paused: 20, breaks: 30))
        sut.recordSession(makeRecord(startTime: tuesday, duration: 200, paused: 40, breaks: 50))
        let weekly = sut.getWeeklyMetrics(for: monday, dayOfWeeks: [2])
        XCTAssertEqual(weekly?.totalFocusTime, 100)
        XCTAssertEqual(weekly?.totalPausedTime, 20)
        XCTAssertEqual(weekly?.totalBreakTime, 30)
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

    func testMonthlyFilterAppliesToPauseAndBreakUsingSameRecords() {
        let first = isoDate(year: 2026, month: 7, day: 1, hour: 9)
        let fifteenth = isoDate(year: 2026, month: 7, day: 15, hour: 9)
        sut.recordSession(makeRecord(startTime: first, duration: 100, paused: 20, breaks: 30))
        sut.recordSession(makeRecord(startTime: fifteenth, duration: 200, paused: 40, breaks: 50))
        let monthly = sut.getMonthlyMetrics(for: first, daysOfMonth: [15])
        XCTAssertEqual(monthly?.totalFocusTime, 200)
        XCTAssertEqual(monthly?.totalPausedTime, 40)
        XCTAssertEqual(monthly?.totalBreakTime, 50)
    }

    func testLegacyDailyWeeklyMonthlyTotalsRemainExactAndCalendarSourceDoesNotChangeBreakdown() throws {
        let date = isoDate(year: 2026, month: 7, day: 20, hour: 9)
        let raw = Data("""
        [{"id":"11111111-1111-1111-1111-111111111111","modeType":"focus_time","modeID":"\(FocusMode.focusTimeID.uuidString)","startTime":"2026-07-20T09:00:00Z","endTime":"2026-07-20T10:00:00Z","duration":725,"pomodorosCompleted":2},
         {"id":"22222222-2222-2222-2222-222222222222","modeType":"calendar_video_call","modeID":"\(FocusModeType.calendarVideoCall.id.uuidString)","startTime":"2026-07-20T10:00:00Z","endTime":"2026-07-20T11:00:00Z","duration":1811}]
        """.utf8)
        defaults.set(raw, forKey: "focally.metrics.records")
        sut = FocusMetricsService(defaults: defaults)
        for totals in [sut.getDailyMetrics(for: date).map { ($0.totalFocusTime, $0.meetingTime, $0.pomodorosCompleted, $0.calendarVideoCallDuration) },
                       sut.getWeeklyMetrics(for: date).map { ($0.totalFocusTime, $0.meetingTime, $0.pomodorosCompleted, $0.calendarVideoCallDuration) },
                       sut.getMonthlyMetrics(for: date).map { ($0.totalFocusTime, $0.meetingTime, $0.pomodorosCompleted, $0.calendarVideoCallDuration) }] {
            let value = try XCTUnwrap(totals)
            XCTAssertEqual(value.0, 2_536)
            XCTAssertEqual(value.1, 0)
            XCTAssertEqual(value.2, 2)
            XCTAssertEqual(value.3, 1_811)
        }
        XCTAssertEqual(sut.records.last?.source, .calendar)
        XCTAssertEqual(sut.getDailyMetrics(for: date)?.meetingDuration, 0)
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
        modeID: UUID = FocusMode.focusTimeID,
        paused: TimeInterval = 0,
        breaks: TimeInterval = 0
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
            pomodorosCompleted: pomodoros,
            pausedDuration: paused,
            breakDuration: breaks
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
