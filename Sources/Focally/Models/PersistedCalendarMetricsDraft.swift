import Foundation

struct PersistedCalendarMetricsDraft: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = currentSchemaVersion
    var recordID: UUID
    var meetingID: String
    var occurrenceStart: Date
    var scheduledEnd: Date
    var firstObservedAt: Date
    var lastObservedAt: Date
    var accumulatedObservedSeconds: TimeInterval
    var isObservationActive: Bool
    var savedAt: Date

    func isValid(at now: Date) -> Bool {
        let tolerance: TimeInterval = 300
        let sevenDays: TimeInterval = 7 * 24 * 60 * 60
        let dates = [occurrenceStart, scheduledEnd, firstObservedAt, lastObservedAt, savedAt]
        guard schemaVersion == Self.currentSchemaVersion,
              !meetingID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              dates.allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }),
              now.timeIntervalSinceReferenceDate.isFinite,
              scheduledEnd >= occurrenceStart,
              firstObservedAt <= lastObservedAt,
              savedAt >= lastObservedAt,
              firstObservedAt >= occurrenceStart.addingTimeInterval(-tolerance),
              firstObservedAt <= scheduledEnd.addingTimeInterval(tolerance),
              lastObservedAt >= occurrenceStart.addingTimeInterval(-tolerance),
              lastObservedAt <= scheduledEnd.addingTimeInterval(tolerance),
              accumulatedObservedSeconds.isFinite,
              accumulatedObservedSeconds >= 0,
              accumulatedObservedSeconds <= scheduledEnd.timeIntervalSince(occurrenceStart) + tolerance,
              savedAt <= now.addingTimeInterval(tolerance),
              now.timeIntervalSince(savedAt) <= sevenDays,
              now.timeIntervalSince(lastObservedAt) <= sevenDays else {
            return false
        }
        return true
    }
}
