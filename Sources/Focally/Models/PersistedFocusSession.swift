import Foundation

struct PersistedFocusSession: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let maximumAge: TimeInterval = 7 * 24 * 60 * 60
    static let maximumPhaseDurationSeconds = 120 * 60
    static let maximumFutureSkew: TimeInterval = 5 * 60
    static let clockTolerance: TimeInterval = 5

    var schemaVersion: Int = Self.currentSchemaVersion
    var sessionID: UUID
    var modeSnapshot: FocusMode
    var sessionStartedAt: Date
    var phase: PomodoroState
    var phaseStartedAt: Date
    var phaseTargetEndDate: Date?
    var phaseDurationSeconds: Int
    var isPaused: Bool
    var pausedAt: Date?
    var pausedRemainingSeconds: Int?
    var currentRound: Int
    var pomodoroRounds: Int
    var accumulatedActiveSeconds: TimeInterval
    var accumulatedBreakSeconds: TimeInterval
    var accumulatedPausedSeconds: TimeInterval
    var savedAt: Date

    func isValid(at now: Date) -> Bool {
        guard schemaVersion == Self.currentSchemaVersion,
              phase == .work || phase == .shortBreak || phase == .longBreak,
              (1...Self.maximumPhaseDurationSeconds).contains(phaseDurationSeconds),
              (1...12).contains(pomodoroRounds),
              currentRound >= 0, currentRound <= pomodoroRounds,
              modeSnapshot == modeSnapshot.sanitized(),
              accumulatedActiveSeconds.isFinite, accumulatedActiveSeconds >= 0,
              accumulatedBreakSeconds.isFinite, accumulatedBreakSeconds >= 0,
              accumulatedPausedSeconds.isFinite, accumulatedPausedSeconds >= 0,
              sessionStartedAt <= phaseStartedAt,
              sessionStartedAt <= savedAt.addingTimeInterval(Self.clockTolerance),
              phaseStartedAt <= savedAt.addingTimeInterval(Self.clockTolerance),
              sessionStartedAt <= now.addingTimeInterval(Self.maximumFutureSkew),
              savedAt <= now.addingTimeInterval(Self.maximumFutureSkew),
              now.timeIntervalSince(sessionStartedAt) <= Self.maximumAge,
              now.timeIntervalSince(savedAt) <= Self.maximumAge else { return false }

        let expectedRounds = modeSnapshot.enablePomodoro ? modeSnapshot.sanitizedPomodoroRounds : 1
        guard pomodoroRounds == expectedRounds else { return false }
        switch phase {
        case .work:
            guard currentRound < pomodoroRounds,
                  phaseDurationSeconds == (modeSnapshot.enablePomodoro
                    ? modeSnapshot.sanitizedPomodoroWorkMinutes
                    : modeSnapshot.sanitizedDurationMinutes) * 60 else { return false }
        case .shortBreak:
            guard modeSnapshot.enablePomodoro, currentRound > 0, currentRound < pomodoroRounds,
                  phaseDurationSeconds == modeSnapshot.sanitizedPomodoroBreakMinutes * 60 else { return false }
        case .longBreak:
            guard modeSnapshot.enablePomodoro, currentRound > 0, currentRound < pomodoroRounds,
                  currentRound.isMultiple(of: 4),
                  phaseDurationSeconds == modeSnapshot.sanitizedPomodoroLongBreakMinutes * 60 else { return false }
        case .idle, .completed:
            return false
        }

        if isPaused {
            guard phaseTargetEndDate == nil,
                  let pausedAt, let pausedRemainingSeconds,
                  pausedAt >= phaseStartedAt,
                  pausedAt <= savedAt.addingTimeInterval(Self.clockTolerance),
                  pausedAt <= now.addingTimeInterval(Self.maximumFutureSkew),
                  (0...phaseDurationSeconds).contains(pausedRemainingSeconds),
                  accumulatedPausedSeconds <= pausedAt.timeIntervalSince(sessionStartedAt) + Self.clockTolerance else { return false }

            let wallElapsed = pausedAt.timeIntervalSince(phaseStartedAt)
            let minimumRemaining = TimeInterval(phaseDurationSeconds) - wallElapsed
            let maximumRemaining = minimumRemaining + accumulatedPausedSeconds
            guard wallElapsed >= -Self.clockTolerance,
                  TimeInterval(pausedRemainingSeconds) + Self.clockTolerance >= minimumRemaining,
                  TimeInterval(pausedRemainingSeconds) <= maximumRemaining + Self.clockTolerance else { return false }
        } else {
            guard let phaseTargetEndDate,
                  pausedAt == nil, pausedRemainingSeconds == nil,
                  phaseTargetEndDate >= phaseStartedAt,
                  phaseTargetEndDate.timeIntervalSince(savedAt) <= TimeInterval(phaseDurationSeconds) + Self.clockTolerance,
                  phaseTargetEndDate <= phaseStartedAt.addingTimeInterval(
                    TimeInterval(phaseDurationSeconds) + accumulatedPausedSeconds + Self.clockTolerance
                  ) else { return false }
        }
        return true
    }
}
