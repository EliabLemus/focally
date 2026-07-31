import Foundation

// MARK: - FocusSessionRecord

/// A completed focus session, persisted by `FocusMetricsService` for analytics.
struct FocusSessionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let modeType: FocusModeType
    let modeID: UUID
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval // in seconds
    let pomodorosCompleted: Int?  // nil for non-pomodoro modes

    init(id: UUID = UUID(),
         modeType: FocusModeType,
         modeID: UUID,
         startTime: Date,
         endTime: Date,
         duration: TimeInterval,
         pomodorosCompleted: Int? = nil) {
        self.id = id
        self.modeType = modeType
        self.modeID = modeID
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.pomodorosCompleted = pomodorosCompleted
    }

    // MARK: - Convenience

    /// True if this session used the pomodoro cadence (has a pomodoro count).
    var isPomodoro: Bool { pomodorosCompleted != nil }

    /// True if this session belongs to a meeting mode.
    var isMeeting: Bool { modeType == .meeting }
}
