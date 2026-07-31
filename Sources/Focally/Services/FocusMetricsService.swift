import Foundation
import Observation

// MARK: - Aggregated Metric Types

struct DailyMetrics: Codable, Equatable {
    let date: Date
    let pomodorosCompleted: Int
    let meetingTime: TimeInterval       // in seconds
    let totalFocusTime: TimeInterval    // in seconds
    let focusTimeDuration: TimeInterval
    let meetingDuration: TimeInterval
    let inboxDuration: TimeInterval
    let customDuration: TimeInterval
    let customTypeDurations: [UUID: TimeInterval]
    let calendarVideoCallDuration: TimeInterval

    var meetingTimeFormatted: String {
        Self.formatDuration(meetingTime)
    }

    var totalFocusTimeFormatted: String {
        Self.formatDuration(totalFocusTime)
    }

    var focusTimeDurationFormatted: String {
        Self.formatDuration(focusTimeDuration)
    }

    var meetingDurationFormatted: String {
        Self.formatDuration(meetingDuration)
    }

    var inboxDurationFormatted: String {
        Self.formatDuration(inboxDuration)
    }

    var customDurationFormatted: String {
        Self.formatDuration(customDuration)
    }

    func durationForType(_ descriptor: FocusTypeDescriptor) -> TimeInterval {
        switch descriptor {
        case .builtIn(let type):
            switch type {
            case .focusTime: return focusTimeDuration
            case .meeting: return meetingDuration
            case .inbox: return inboxDuration
            case .custom: return customDuration
            case .calendarVideoCall: return calendarVideoCallDuration
            case .userCustom: return 0
            }
        case .custom(let type):
            return customTypeDurations[type.id, default: 0]
        }
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
    let focusTimeDuration: TimeInterval
    let meetingDuration: TimeInterval
    let inboxDuration: TimeInterval
    let customDuration: TimeInterval
    let customTypeDurations: [UUID: TimeInterval]
    let calendarVideoCallDuration: TimeInterval

    var meetingTimeFormatted: String { DailyMetrics.formatDuration(meetingTime) }
    var totalFocusTimeFormatted: String { DailyMetrics.formatDuration(totalFocusTime) }
    var focusTimeDurationFormatted: String { DailyMetrics.formatDuration(focusTimeDuration) }
    var meetingDurationFormatted: String { DailyMetrics.formatDuration(meetingDuration) }
    var inboxDurationFormatted: String { DailyMetrics.formatDuration(inboxDuration) }
    var customDurationFormatted: String { DailyMetrics.formatDuration(customDuration) }
    var avgDailyFocusTime: TimeInterval {
        daysWithData > 0 ? totalFocusTime / Double(daysWithData) : 0
    }
    var avgDailyFocusTimeFormatted: String {
        DailyMetrics.formatDuration(avgDailyFocusTime)
    }

    func durationForType(_ descriptor: FocusTypeDescriptor) -> TimeInterval {
        switch descriptor {
        case .builtIn(let type):
            switch type {
            case .focusTime: return focusTimeDuration
            case .meeting: return meetingDuration
            case .inbox: return inboxDuration
            case .custom: return customDuration
            case .calendarVideoCall: return calendarVideoCallDuration
            case .userCustom: return 0
            }
        case .custom(let type):
            return customTypeDurations[type.id, default: 0]
        }
    }
}

struct MonthlyMetrics: Codable, Equatable {
    let monthStartDate: Date
    let pomodorosCompleted: Int
    let meetingTime: TimeInterval
    let totalFocusTime: TimeInterval
    let weeksWithData: Int
    let focusTimeDuration: TimeInterval
    let meetingDuration: TimeInterval
    let inboxDuration: TimeInterval
    let customDuration: TimeInterval
    let customTypeDurations: [UUID: TimeInterval]
    let calendarVideoCallDuration: TimeInterval

    var meetingTimeFormatted: String { DailyMetrics.formatDuration(meetingTime) }
    var totalFocusTimeFormatted: String { DailyMetrics.formatDuration(totalFocusTime) }
    var focusTimeDurationFormatted: String { DailyMetrics.formatDuration(focusTimeDuration) }
    var meetingDurationFormatted: String { DailyMetrics.formatDuration(meetingDuration) }
    var inboxDurationFormatted: String { DailyMetrics.formatDuration(inboxDuration) }
    var customDurationFormatted: String { DailyMetrics.formatDuration(customDuration) }

    func durationForType(_ descriptor: FocusTypeDescriptor) -> TimeInterval {
        switch descriptor {
        case .builtIn(let type):
            switch type {
            case .focusTime: return focusTimeDuration
            case .meeting: return meetingDuration
            case .inbox: return inboxDuration
            case .custom: return customDuration
            case .calendarVideoCall: return calendarVideoCallDuration
            case .userCustom: return 0
            }
        case .custom(let type):
            return customTypeDurations[type.id, default: 0]
        }
    }
}

private struct ModeTypeBreakdown {
    let focusTimeDuration: TimeInterval
    let meetingDuration: TimeInterval
    let inboxDuration: TimeInterval
    let customDuration: TimeInterval
    let calendarVideoCallDuration: TimeInterval
    let customTypeDurations: [UUID: TimeInterval]
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
        let breakdown = modeTypeBreakdown(for: dayRecords)

        return DailyMetrics(
            date: targetDay,
            pomodorosCompleted: pomodoros,
            meetingTime: meetingTime,
            totalFocusTime: totalFocus,
            focusTimeDuration: breakdown.focusTimeDuration,
            meetingDuration: breakdown.meetingDuration,
            inboxDuration: breakdown.inboxDuration,
            customDuration: breakdown.customDuration,
            customTypeDurations: breakdown.customTypeDurations,
            calendarVideoCallDuration: breakdown.calendarVideoCallDuration
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
        let weekRecords = records.filter { record in
            weekInterval.contains(record.startTime)
        }

        return makeWeeklyMetrics(
            weekRecords: weekRecords,
            weekStart: weekInterval.start,
            calendar: calendar
        )
    }

    /// Returns weekly metrics for the week containing `date`, filtered to matching weekdays.
    func getWeeklyMetrics(for date: Date, dayOfWeeks: Set<Int>) -> WeeklyMetrics? {
        let calendar = isoCalendar
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return nil
        }

        let weekRecords = records.filter { record in
            let weekday = calendar.component(.weekday, from: record.startTime)
            let matchesDayOfWeek = dayOfWeeks.isEmpty || dayOfWeeks.contains(weekday)
            return weekInterval.contains(record.startTime) && matchesDayOfWeek
        }

        return makeWeeklyMetrics(
            weekRecords: weekRecords,
            weekStart: weekInterval.start,
            calendar: calendar
        )
    }

    // MARK: - Aggregation: Monthly

    /// Returns monthly metrics for the month containing `date`.
    func getMonthlyMetrics(for date: Date) -> MonthlyMetrics? {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            return nil
        }
        let monthRecords = records.filter { record in
            monthInterval.contains(record.startTime)
        }

        return makeMonthlyMetrics(
            monthRecords: monthRecords,
            monthStart: monthInterval.start
        )
    }

    /// Returns monthly metrics for the month containing `date`, filtered to matching day numbers.
    /// Use `0` in `daysOfMonth` to include the last day of the month.
    func getMonthlyMetrics(for date: Date, daysOfMonth: Set<Int>) -> MonthlyMetrics? {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            return nil
        }

        let lastDayOfMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        let monthRecords = records.filter { record in
            guard monthInterval.contains(record.startTime) else {
                return false
            }

            let day = calendar.component(.day, from: record.startTime)
            let isLastDay = day == lastDayOfMonth && daysOfMonth.contains(0)
            return daysOfMonth.isEmpty || daysOfMonth.contains(day) || isLastDay
        }

        return makeMonthlyMetrics(
            monthRecords: monthRecords,
            monthStart: monthInterval.start
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

    private func makeWeeklyMetrics(
        weekRecords: [FocusSessionRecord],
        weekStart: Date,
        calendar: Calendar
    ) -> WeeklyMetrics? {
        guard !weekRecords.isEmpty else { return nil }

        let pomodoros = weekRecords.compactMap(\.pomodorosCompleted).reduce(0, +)
        let meetingTime = weekRecords.filter { $0.isMeeting }.reduce(0) { $0 + $1.duration }
        let totalFocus = weekRecords.reduce(0) { $0 + $1.duration }
        let breakdown = modeTypeBreakdown(for: weekRecords)

        var daysWithSessions: Set<DateComponents> = []
        for record in weekRecords {
            let components = calendar.dateComponents([.year, .month, .day], from: record.startTime)
            daysWithSessions.insert(components)
        }

        return WeeklyMetrics(
            weekStartDate: weekStart,
            pomodorosCompleted: pomodoros,
            meetingTime: meetingTime,
            totalFocusTime: totalFocus,
            daysWithData: daysWithSessions.count,
            focusTimeDuration: breakdown.focusTimeDuration,
            meetingDuration: breakdown.meetingDuration,
            inboxDuration: breakdown.inboxDuration,
            customDuration: breakdown.customDuration,
            customTypeDurations: breakdown.customTypeDurations,
            calendarVideoCallDuration: breakdown.calendarVideoCallDuration
        )
    }

    private func makeMonthlyMetrics(
        monthRecords: [FocusSessionRecord],
        monthStart: Date
    ) -> MonthlyMetrics? {
        guard !monthRecords.isEmpty else { return nil }

        let pomodoros = monthRecords.compactMap(\.pomodorosCompleted).reduce(0, +)
        let meetingTime = monthRecords.filter { $0.isMeeting }.reduce(0) { $0 + $1.duration }
        let totalFocus = monthRecords.reduce(0) { $0 + $1.duration }
        let breakdown = modeTypeBreakdown(for: monthRecords)

        let iso = isoCalendar
        var weeksWithSessions: Set<Int> = []
        for record in monthRecords {
            let components = iso.dateComponents([.yearForWeekOfYear, .weekOfYear], from: record.startTime)
            let hash = (components.yearForWeekOfYear ?? 0) * 100 + (components.weekOfYear ?? 0)
            weeksWithSessions.insert(hash)
        }

        return MonthlyMetrics(
            monthStartDate: monthStart,
            pomodorosCompleted: pomodoros,
            meetingTime: meetingTime,
            totalFocusTime: totalFocus,
            weeksWithData: weeksWithSessions.count,
            focusTimeDuration: breakdown.focusTimeDuration,
            meetingDuration: breakdown.meetingDuration,
            inboxDuration: breakdown.inboxDuration,
            customDuration: breakdown.customDuration,
            customTypeDurations: breakdown.customTypeDurations,
            calendarVideoCallDuration: breakdown.calendarVideoCallDuration
        )
    }

    private func modeTypeBreakdown(for records: [FocusSessionRecord]) -> ModeTypeBreakdown {
        var focusTime: TimeInterval = 0
        var meeting: TimeInterval = 0
        var inbox: TimeInterval = 0
        var custom: TimeInterval = 0
        var calendarVideoCall: TimeInterval = 0
        var customTypes: [UUID: TimeInterval] = [:]

        for record in records {
            let descriptor = FocusModeStore.typeDescriptor(forModeID: record.modeID)
                ?? .builtIn(record.modeType)

            switch descriptor {
            case .builtIn(let type):
                switch type {
                case .focusTime: focusTime += record.duration
                case .meeting: meeting += record.duration
                case .inbox: inbox += record.duration
                case .custom: custom += record.duration
                case .calendarVideoCall: calendarVideoCall += record.duration
                case .userCustom: break
                }
            case .custom(let type):
                customTypes[type.id, default: 0] += record.duration
            }
        }

        return ModeTypeBreakdown(
            focusTimeDuration: focusTime,
            meetingDuration: meeting,
            inboxDuration: inbox,
            customDuration: custom,
            calendarVideoCallDuration: calendarVideoCall,
            customTypeDurations: customTypes
        )
    }
}
