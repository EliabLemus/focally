import Foundation
import Observation

// MARK: - Aggregated Metric Types

struct DailyMetrics: Codable, Equatable {
    let date: Date
    let pomodorosCompleted: Int
    let meetingTime: TimeInterval       // in seconds
    let totalFocusTime: TimeInterval    // in seconds

    var meetingTimeFormatted: String {
        Self.formatDuration(meetingTime)
    }

    var totalFocusTimeFormatted: String {
        Self.formatDuration(totalFocusTime)
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct WeeklyMetrics: Codable, Equatable {
    let weekStartDate: Date
    let pomodorosCompleted: Int
    let meetingTime: TimeInterval
    let totalFocusTime: TimeInterval
    let daysWithData: Int

    var meetingTimeFormatted: String { DailyMetrics.formatDuration(meetingTime) }
    var totalFocusTimeFormatted: String { DailyMetrics.formatDuration(totalFocusTime) }
    var avgDailyFocusTime: TimeInterval {
        daysWithData > 0 ? totalFocusTime / Double(daysWithData) : 0
    }
    var avgDailyFocusTimeFormatted: String {
        DailyMetrics.formatDuration(avgDailyFocusTime)
    }
}

struct MonthlyMetrics: Codable, Equatable {
    let monthStartDate: Date
    let pomodorosCompleted: Int
    let meetingTime: TimeInterval
    let totalFocusTime: TimeInterval
    let weeksWithData: Int

    var meetingTimeFormatted: String { DailyMetrics.formatDuration(meetingTime) }
    var totalFocusTimeFormatted: String { DailyMetrics.formatDuration(totalFocusTime) }
}

// MARK: - FocusMetricsService

/// Records completed focus sessions and aggregates daily/weekly/monthly metrics.
/// Storage: UserDefaults key `focally.metrics.records`.
@MainActor
@Observable
final class FocusMetricsService {
    static let shared = FocusMetricsService()

    // MARK: - Storage Keys

    private static let recordsKey = "focally.metrics.records"
    private static let maxRecords = 5000

    // MARK: - Published State

    private(set) var records: [FocusSessionRecord] = []

    // MARK: - Init

    private init() {
        loadRecords()
    }

    // MARK: - Recording

    /// Record a completed session. Called by `FocusTimerService` on session completion.
    func recordSession(_ session: FocusSessionRecord) {
        print("[Metrics] recordSession called with: \(session)")
        records.append(session)
        // Cap stored records to prevent unbounded growth (MVP).
        if records.count > Self.maxRecords {
            records.removeFirst(records.count - Self.maxRecords)
        }
        saveRecords()
        print("[Metrics] Saved \(records.count) records to UserDefaults")
    }

    // MARK: - Aggregation: Daily

    func getDailyMetrics(for date: Date) -> DailyMetrics? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)

        let dayRecords = records.filter { record in
            calendar.isDate(record.startTime, inSameDayAs: targetDay)
        }

        guard !dayRecords.isEmpty else { return nil }

        let pomodoros = dayRecords.compactMap(\.pomodorosCompleted).reduce(0, +)
        let meetingTime = dayRecords.filter { $0.isMeeting }.reduce(0) { $0 + $1.duration }
        let totalFocus = dayRecords.reduce(0) { $0 + $1.duration }

        return DailyMetrics(
            date: targetDay,
            pomodorosCompleted: pomodoros,
            meetingTime: meetingTime,
            totalFocusTime: totalFocus
        )
    }

    // MARK: - Aggregation: Weekly

    /// Returns weekly metrics for the week containing `date`.
    /// Week starts on Monday (ISO 8601).
    func getWeeklyMetrics(for date: Date) -> WeeklyMetrics? {
        let calendar = isoCalendar
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return nil
        }
        let weekStart = weekInterval.start

        let weekRecords = records.filter { record in
            weekInterval.contains(record.startTime)
        }

        guard !weekRecords.isEmpty else { return nil }

        let pomodoros = weekRecords.compactMap(\.pomodorosCompleted).reduce(0, +)
        let meetingTime = weekRecords.filter { $0.isMeeting }.reduce(0) { $0 + $1.duration }
        let totalFocus = weekRecords.reduce(0) { $0 + $1.duration }

        // Count unique days with data
        var daysWithSessions: Set<DateComponents> = []
        for record in weekRecords {
            let comps = calendar.dateComponents([.year, .month, .day], from: record.startTime)
            daysWithSessions.insert(comps)
        }

        return WeeklyMetrics(
            weekStartDate: weekStart,
            pomodorosCompleted: pomodoros,
            meetingTime: meetingTime,
            totalFocusTime: totalFocus,
            daysWithData: daysWithSessions.count
        )
    }

    // MARK: - Aggregation: Monthly

    /// Returns monthly metrics for the month containing `date`.
    func getMonthlyMetrics(for date: Date) -> MonthlyMetrics? {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            return nil
        }
        let monthStart = monthInterval.start

        let monthRecords = records.filter { record in
            monthInterval.contains(record.startTime)
        }

        guard !monthRecords.isEmpty else { return nil }

        let pomodoros = monthRecords.compactMap(\.pomodorosCompleted).reduce(0, +)
        let meetingTime = monthRecords.filter { $0.isMeeting }.reduce(0) { $0 + $1.duration }
        let totalFocus = monthRecords.reduce(0) { $0 + $1.duration }

        // Count unique weeks with data
        let iso = isoCalendar
        var weeksWithSessions: Set<Int> = []
        for record in monthRecords {
            let comps = iso.dateComponents([.yearForWeekOfYear, .weekOfYear], from: record.startTime)
            let hash = (comps.yearForWeekOfYear ?? 0) * 100 + (comps.weekOfYear ?? 0)
            weeksWithSessions.insert(hash)
        }

        return MonthlyMetrics(
            monthStartDate: monthStart,
            pomodorosCompleted: pomodoros,
            meetingTime: meetingTime,
            totalFocusTime: totalFocus,
            weeksWithData: weeksWithSessions.count
        )
    }

    // MARK: - Persistence (UserDefaults)

    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: Self.recordsKey) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        records = (try? decoder.decode([FocusSessionRecord].self, from: data)) ?? []
    }

    private func saveRecords() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        UserDefaults.standard.set(data, forKey: Self.recordsKey)
    }

    // MARK: - Test Helpers

    /// Clears all records. Intended for tests and "reset" operations.
    func clearAllRecords() {
        records.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.recordsKey)
    }

    // MARK: - Private

    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }
}
