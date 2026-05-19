import Foundation

// MARK: - Formatters and Helpers

extension GoogleCalendarService {
    private static let googleDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = .current
        return formatter
    }()

    private static let googleDateTimeFallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = .current
        return formatter
    }()

    private static let googleDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    private static func makeCalendarEvent(from item: GoogleCalendarItem) -> CalendarEvent? {
        guard let start = parseEventDate(from: item.start) else {
            return nil
        }

        guard let end = parseEventDate(from: item.end) else {
            return nil
        }

        let isAllDay = item.start.date != nil

        let eventTitle: String = {
            guard let summary = item.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !summary.isEmpty else {
                return "Untitled Event"
            }
            return summary
        }()

        return CalendarEvent(
            id: item.id,
            title: eventTitle,
            startTime: start,
            endTime: end,
            isAllDay: isAllDay,
            meetLink: item.hangoutLink
        )
    }

    private static func parseEventDate(from value: GoogleCalendarDateValue) -> Date? {
        if let dateTime = value.dateTime {
            return googleDateTimeFormatter.date(from: dateTime) ?? googleDateTimeFallbackFormatter.date(from: dateTime)
        }

        guard let dateOnly = value.date, let date = googleDayFormatter.date(from: dateOnly) else {
            return nil
        }

        return Calendar.current.startOfDay(for: date)
    }

    private static let formURLEncodedAllowedCharacters: CharacterSet = {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._*")
        return allowed
    }()

    private static func formURLEncodedValue(for string: String) -> String {
        let escaped = string.addingPercentEncoding(withAllowedCharacters: formURLEncodedAllowedCharacters) ?? string
        return escaped.replacingOccurrences(of: " ", with: "+")
    }
}
