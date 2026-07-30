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

    private init() {}

    func isVideoCall(_ event: EKEvent) -> Bool {
        let searchableText = [
            event.location,
            event.url?.absoluteString,
            event.notes,
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")

        if Self.videoCallHosts.contains(where: searchableText.contains) {
            return true
        }

        let title = event.title?.lowercased() ?? ""
        return ["zoom", "video call", "videocall", "teams call"]
            .contains(where: title.contains)
    }
}
