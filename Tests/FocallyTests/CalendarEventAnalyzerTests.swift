import EventKit
import XCTest

@testable import Focally

/// Lane B — tasks 1.1–1.3 (calendar-first-call-detection).
final class CalendarEventAnalyzerTests: XCTestCase {
    private let analyzer = CalendarEventAnalyzer.shared

    private func makeEvent(
        title: String = "Sync",
        start: Date = Date(),
        end: Date = Date().addingTimeInterval(3600)
    ) -> EKEvent {
        let event = EKEvent(eventStore: EKEventStore())
        event.title = title
        event.startDate = start
        event.endDate = end
        return event
    }

    // MARK: 1.1 — conferenceUrl / structuredLocation feed isVideoCall

    func testConferenceUrlOnlyMeetingIsVideoCall() {
        let event = makeEvent()
        // ponytail: `EKEvent.conferenceUrl` is iOS-only; on macOS the conference
        // link lives in `event.url` (equivalent storage, same signal).
        event.url = URL(string: "https://meet.google.com/abc-defg-hij")!

        let meeting = CalendarMeeting(event: event)
        XCTAssertTrue(meeting.hasVideoCall)
        XCTAssertEqual(meeting.conferencePlatform, "Meet")
    }

    func testPlatformFromNotesLink() {
        let event = makeEvent()
        event.notes = "Join: https://teams.microsoft.com/l/meetup-join/abc"

        let meeting = CalendarMeeting(event: event)
        XCTAssertTrue(meeting.hasVideoCall)
        XCTAssertEqual(meeting.conferencePlatform, "Teams")
    }

    func testStructuredLocationOnlyMeetingIsVideoCall() {
        let event = makeEvent()
        let location = EKStructuredLocation()
        location.title = "https://zoom.us/j/123456"
        event.structuredLocation = location

        XCTAssertTrue(analyzer.isVideoCall(event))
    }

    func testPlainEventIsNotVideoCall() {
        let event = makeEvent(title: "Lunch")
        XCTAssertFalse(analyzer.isVideoCall(event))
    }

    // MARK: 1.2 — conferencePlatform derivation by host

    func testConferencePlatformByHost() {
        XCTAssertEqual(analyzer.conferencePlatform(from: URL(string: "https://meet.google.com/x")!), "Meet")
        XCTAssertEqual(analyzer.conferencePlatform(from: URL(string: "https://us02web.zoom.us/j/1")!), "Zoom")
        XCTAssertEqual(analyzer.conferencePlatform(from: URL(string: "https://teams.microsoft.com/l/x")!), "Teams")
        XCTAssertEqual(analyzer.conferencePlatform(from: URL(string: "https://mycompany.webex.com/meet/x")!), "Webex")
    }

    func testConferencePlatformNilWithoutKnownHost() {
        XCTAssertNil(analyzer.conferencePlatform(from: nil))
        XCTAssertNil(analyzer.conferencePlatform(from: URL(string: "https://example.com")!))

        let meeting = CalendarMeeting(
            id: "1", title: "t", startTime: Date(), endTime: Date(), isAllDay: false, hasVideoCall: false
        )
        XCTAssertNil(meeting.conferencePlatform)
    }

    // MARK: 1.3 — fetch window covers overnight events

    func testFetchWindowAt0100IncludesYesterday2200Event() {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 13
        components.hour = 1
        let calendar = Calendar.current
        let at0100 = calendar.date(from: components)!

        let window = CalendarEventAnalyzer.fetchWindow(for: at0100, calendar: calendar)

        // Overnight event: started yesterday 22:00, ends today 02:00.
        let eventStart = calendar.date(byAdding: .day, value: -1, to: at0100)!
            .addingTimeInterval(21 * 3600) // 22:00 yesterday local
        let eventEnd = at0100.addingTimeInterval(3600)

        XCTAssertTrue(eventStart >= window.start, "overnight start must fall inside the fetch window")
        XCTAssertTrue(eventEnd > window.start)
        XCTAssertLessThan(eventStart, window.end)
        XCTAssertEqual(window.end, window.start.addingTimeInterval(48 * 3600))
    }

    func testFetchWindowExtendsExactly24HoursBack() {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 13
        components.hour = 15
        let calendar = Calendar.current
        let date = calendar.date(from: components)!

        let window = CalendarEventAnalyzer.fetchWindow(for: date, calendar: calendar)
        XCTAssertEqual(window.start, calendar.startOfDay(for: date).addingTimeInterval(-24 * 3600))
        XCTAssertEqual(window.end, calendar.startOfDay(for: date).addingTimeInterval(24 * 3600))
    }
}
