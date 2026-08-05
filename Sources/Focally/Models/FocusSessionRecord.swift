import Foundation

enum FocusSessionSource: String, Codable, Equatable {
    case manual
    case calendar
}

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
    let recordVersion: Int
    let activeDuration: TimeInterval
    let pausedDuration: TimeInterval
    let breakDuration: TimeInterval
    let source: FocusSessionSource

    init(
        id: UUID = UUID(),
        modeType: FocusModeType,
        modeID: UUID,
        startTime: Date,
        endTime: Date,
        duration: TimeInterval,
        pomodorosCompleted: Int? = nil,
        recordVersion _: Int = 2,
        activeDuration: TimeInterval? = nil,
        pausedDuration: TimeInterval = 0,
        breakDuration: TimeInterval = 0,
        source: FocusSessionSource = .manual
    ) {
        let active = Self.normalized(activeDuration ?? duration)
        self.id = id
        self.modeType = modeType
        self.modeID = modeID
        self.startTime = startTime
        self.endTime = max(endTime, startTime)
        self.duration = active
        self.pomodorosCompleted = pomodorosCompleted
        self.recordVersion = 2
        self.activeDuration = active
        self.pausedDuration = Self.normalized(pausedDuration)
        self.breakDuration = Self.normalized(breakDuration)
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case id, modeType, modeID, startTime, endTime, duration, pomodorosCompleted
        case recordVersion, activeDuration, pausedDuration, breakDuration, source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let modeType = try container.decode(FocusModeType.self, forKey: .modeType)
        let modeID = try container.decode(UUID.self, forKey: .modeID)
        let startTime = try container.decode(Date.self, forKey: .startTime)
        let endTime = try container.decode(Date.self, forKey: .endTime)
        guard endTime >= startTime else {
            throw DecodingError.dataCorruptedError(forKey: .endTime, in: container,
                debugDescription: "Session end time precedes its start time")
        }
        let legacyDuration = try container.decode(TimeInterval.self, forKey: .duration)
        guard Self.isValid(legacyDuration) else {
            throw DecodingError.dataCorruptedError(forKey: .duration, in: container,
                debugDescription: "Duration must be finite and nonnegative")
        }

        self.id = id
        self.modeType = modeType
        self.modeID = modeID
        self.startTime = startTime
        self.endTime = endTime
        self.pomodorosCompleted = try container.decodeIfPresent(Int.self, forKey: .pomodorosCompleted)

        let hasAnyV2Field = container.contains(.recordVersion)
            || container.contains(.activeDuration)
            || container.contains(.pausedDuration)
            || container.contains(.breakDuration)
            || container.contains(.source)
        if !hasAnyV2Field {
            recordVersion = 1
            duration = legacyDuration
            activeDuration = legacyDuration
            pausedDuration = 0
            breakDuration = 0
            source = modeType == .calendarVideoCall ? .calendar : .manual
            return
        }

        let version = try container.decode(Int.self, forKey: .recordVersion)
        guard version == 2 else {
            throw DecodingError.dataCorruptedError(forKey: .recordVersion, in: container,
                debugDescription: "Unsupported focus session record version \(version)")
        }
        let active = try container.decode(TimeInterval.self, forKey: .activeDuration)
        let paused = try container.decode(TimeInterval.self, forKey: .pausedDuration)
        let breaks = try container.decode(TimeInterval.self, forKey: .breakDuration)
        guard Self.isValid(active), Self.isValid(paused), Self.isValid(breaks) else {
            throw DecodingError.dataCorruptedError(forKey: .activeDuration, in: container,
                debugDescription: "Session durations must be finite and nonnegative")
        }
        recordVersion = version
        duration = active
        activeDuration = active
        pausedDuration = paused
        breakDuration = breaks
        source = try container.decode(FocusSessionSource.self, forKey: .source)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(modeType, forKey: .modeType)
        try container.encode(modeID, forKey: .modeID)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(activeDuration, forKey: .duration)
        try container.encodeIfPresent(pomodorosCompleted, forKey: .pomodorosCompleted)
        try container.encode(2, forKey: .recordVersion)
        try container.encode(activeDuration, forKey: .activeDuration)
        try container.encode(pausedDuration, forKey: .pausedDuration)
        try container.encode(breakDuration, forKey: .breakDuration)
        try container.encode(source, forKey: .source)
    }

    private static func isValid(_ duration: TimeInterval) -> Bool {
        duration.isFinite && duration >= 0
    }

    private static func normalized(_ duration: TimeInterval) -> TimeInterval {
        isValid(duration) ? duration : 0
    }

    // MARK: - Convenience

    /// True if this session used the pomodoro cadence (has a pomodoro count).
    var isPomodoro: Bool { pomodorosCompleted != nil }

    /// True if this session belongs to a meeting mode.
    var isMeeting: Bool { modeType == .meeting }
}
