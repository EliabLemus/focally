import Foundation

struct CalendarEvent: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let isAllDay: Bool
    let meetLink: String?

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var timeRange: String {
        if isAllDay {
            return "All day"
        }

        return "\(Self.timeFormatter.string(from: startTime)) – \(Self.timeFormatter.string(from: endTime))"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
