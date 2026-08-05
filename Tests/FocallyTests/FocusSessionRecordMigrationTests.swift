import XCTest
@testable import Focally

final class FocusSessionRecordMigrationTests: XCTestCase {
    private let id = "11111111-1111-1111-1111-111111111111"
    private let modeID = "22222222-2222-2222-2222-222222222222"

    func testV1ManualMigrationPreservesLegacySemanticsAndNilPomodoros() throws {
        let record = try decode(v1JSON(modeType: "focus_time", duration: 600))
        XCTAssertEqual(record.recordVersion, 1)
        XCTAssertEqual(record.duration, 600)
        XCTAssertEqual(record.activeDuration, 600)
        XCTAssertEqual(record.pausedDuration, 0)
        XCTAssertEqual(record.breakDuration, 0)
        XCTAssertEqual(record.source, .manual)
        XCTAssertNil(record.pomodorosCompleted)
    }

    func testV1CalendarMigrationInfersCalendarSource() throws {
        XCTAssertEqual(try decode(v1JSON(modeType: "calendar_video_call", duration: 1800)).source, .calendar)
    }

    func testV1RoundTripKeepsOriginalSemanticFields() throws {
        let original = try decode(v1JSON(modeType: "meeting", duration: 725, pomodoros: 3))
        let roundTrip = try decoder.decode(FocusSessionRecord.self, from: encoder.encode(original))
        XCTAssertEqual(roundTrip.id, original.id)
        XCTAssertEqual(roundTrip.modeType, original.modeType)
        XCTAssertEqual(roundTrip.modeID, original.modeID)
        XCTAssertEqual(roundTrip.startTime, original.startTime)
        XCTAssertEqual(roundTrip.endTime, original.endTime)
        XCTAssertEqual(roundTrip.duration, original.duration)
        XCTAssertEqual(roundTrip.pomodorosCompleted, original.pomodorosCompleted)
        XCTAssertEqual(roundTrip.recordVersion, 2)
    }

    func testV2ManualDecodesAllFieldsAndActiveDurationWins() throws {
        let record = try decode(v2JSON(source: "manual", duration: 2400, active: 1500, paused: 600, breaks: 300))
        XCTAssertEqual(record.recordVersion, 2)
        XCTAssertEqual(record.duration, 1500)
        XCTAssertEqual(record.activeDuration, 1500)
        XCTAssertEqual(record.pausedDuration, 600)
        XCTAssertEqual(record.breakDuration, 300)
        XCTAssertEqual(record.source, .manual)
    }

    func testV2CalendarAndRoundTripPreserveFields() throws {
        let original = try decode(v2JSON(source: "calendar", duration: 1800, active: 1800, paused: 0, breaks: 0))
        let roundTrip = try decoder.decode(FocusSessionRecord.self, from: encoder.encode(original))
        XCTAssertEqual(roundTrip, original)
        XCTAssertEqual(roundTrip.source, .calendar)
    }

    func testInitializerAlwaysCreatesV2AndCannotInflateDuration() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let record = FocusSessionRecord(modeType: .focusTime, modeID: UUID(), startTime: start,
            endTime: start.addingTimeInterval(2_400), duration: 2_400, recordVersion: 1,
            activeDuration: 1_500, pausedDuration: 600, breakDuration: 300)
        XCTAssertEqual(record.recordVersion, 2, "The public initializer is only for new v2 records")
        XCTAssertEqual(record.duration, 1_500)
        XCTAssertEqual(record.activeDuration, 1_500)
    }

    func testInvalidDurationsAndDatesAreRejected() {
        XCTAssertThrowsError(try decode(v2JSON(source: "manual", duration: -1, active: -1, paused: 0, breaks: 0)))
        XCTAssertThrowsError(try decode(v2JSON(source: "manual", duration: 5, active: 5, paused: -1, breaks: 0)))
        XCTAssertThrowsError(try decode(v2JSON(source: "manual", duration: 5, active: 5, paused: 0, breaks: 0,
                                               start: "2026-07-20T10:00:00Z", end: "2026-07-20T09:00:00Z")))
    }

    func testNonFiniteInitializerInputIsNormalizedBeforePersistence() throws {
        let record = FocusSessionRecord(modeType: .focusTime, modeID: UUID(), startTime: Date(), endTime: Date(),
                                        duration: .infinity, activeDuration: .nan,
                                        pausedDuration: -.infinity, breakDuration: .infinity)
        XCTAssertEqual(record.duration, 0)
        XCTAssertEqual(record.activeDuration, 0)
        XCTAssertEqual(record.pausedDuration, 0)
        XCTAssertEqual(record.breakDuration, 0)
        XCTAssertNoThrow(try encoder.encode(record))
    }

    func testNonFiniteEncodedNumbersCannotLoad() {
        for token in ["1e400", "-1e400"] {
            let json = v2JSON(source: "manual", duration: 5, active: 5, paused: 0, breaks: 0)
                .replacingOccurrences(of: "\"activeDuration\":5.0", with: "\"activeDuration\":\(token)")
                .replacingOccurrences(of: "\"activeDuration\":5", with: "\"activeDuration\":\(token)")
            XCTAssertThrowsError(try decode(json))
        }
    }

    func testUnknownFutureVersionIsRejected() {
        XCTAssertThrowsError(try decode(v2JSON(source: "manual", duration: 5, active: 5, paused: 0, breaks: 0,
                                               version: 99)))
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func decode(_ json: String) throws -> FocusSessionRecord {
        try decoder.decode(FocusSessionRecord.self, from: Data(json.utf8))
    }

    private func v1JSON(modeType: String, duration: Double, pomodoros: Int? = nil) -> String {
        let pomodoroField = pomodoros.map { ",\"pomodorosCompleted\":\($0)" } ?? ""
        return """
        {"id":"\(id)","modeType":"\(modeType)","modeID":"\(modeID)","startTime":"2026-07-20T09:00:00Z","endTime":"2026-07-20T10:00:00Z","duration":\(duration)\(pomodoroField)}
        """
    }

    private func v2JSON(source: String, duration: Double, active: Double, paused: Double, breaks: Double,
                        start: String = "2026-07-20T09:00:00Z", end: String = "2026-07-20T10:00:00Z",
                        version: Int = 2) -> String {
        """
        {"id":"\(id)","modeType":"focus_time","modeID":"\(modeID)","startTime":"\(start)","endTime":"\(end)","duration":\(duration),"recordVersion":\(version),"activeDuration":\(active),"pausedDuration":\(paused),"breakDuration":\(breaks),"source":"\(source)"}
        """
    }
}
