import EventKit
import Foundation

final class CalendarEventAnalyzer: Sendable {
    static let shared = CalendarEventAnalyzer()

    private static let videoCallHosts = [
        "zoom.us",
        "meet.google.com",
        "teams.microsoft.com",
        "webex.com",
        "gotomeeting.com",
        "bluejeans.com",
    ]

    // ponytail: host→platform map kept flat; new platforms = one entry here + one in videoCallHosts
    private static let platformByHost: [String: String] = [
        "meet.google.com": "Meet",
        "zoom.us": "Zoom",
        "teams.microsoft.com": "Teams",
        "webex.com": "Webex",
    ]

    private init() {}

    /// Combined searchable text for a video-call signal (task 1.1): `structuredLocation`
    /// joins location/url/notes. (`EKEvent.conferenceUrl` is iOS-only — see conferencePlatform.)
    static func searchableText(for event: EKEvent) -> String {
        [
            event.location,
            event.structuredLocation?.title,
            event.url?.absoluteString,
            event.notes,
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")
    }

    func isVideoCall(_ event: EKEvent) -> Bool {
        let searchableText = Self.searchableText(for: event)

        if Self.videoCallHosts.contains(where: searchableText.contains) {
            return true
        }

        let title = event.title?.lowercased() ?? ""
        return ["zoom", "video call", "videocall", "teams call"]
            .contains(where: title.contains)
    }

    /// Task 1.2: platform name derived from the conference link of an event; nil → caller shows `:phone:` fallback.
    /// ponytail: `EKEvent.conferenceUrl` is iOS-only (unavailable in the macOS SDK, verified) — the macOS
    /// storage for conference links is `event.url` plus links in location/structuredLocation/notes, so we
    /// scan those; upgrade path if Apple ever ships conferenceUrl on macOS.
    func conferencePlatform(for event: EKEvent) -> String? {
        let text = Self.searchableText(for: event)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
              let url = detector
                  .matches(in: text, range: NSRange(text.startIndex..., in: text))
                  .compactMap(\.url)
                  .first(where: { conferencePlatform(from: $0) != nil })
        else { return nil }
        return conferencePlatform(from: url)
    }

    func conferencePlatform(from url: URL?) -> String? {
        guard let host = url?.host?.lowercased() else { return nil }
        return Self.platformByHost.first { host == $0.key || host.hasSuffix(".\($0.key)") }?.value
    }

    /// Task 1.3: fetch window for `fetchTodayEvents` — extends the start 24 h back
    /// so overnight events (started yesterday, still running) are included.
    static func fetchWindow(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        let extendedStart = calendar.date(byAdding: .hour, value: -24, to: start) ?? start
        return (extendedStart, end)
    }
}
