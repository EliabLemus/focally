import Foundation

struct FocusSessionDraft: Equatable {
    let mode: FocusMode
    var activity: String
    var durationMinutes: Int

    init(mode: FocusMode, activity: String = "", durationMinutes: Int? = nil) {
        let sanitizedMode = mode.sanitized()
        self.mode = mode
        self.activity = activity
        self.durationMinutes = durationMinutes
            ?? (sanitizedMode.enablePomodoro
                ? sanitizedMode.sanitizedPomodoroWorkMinutes
                : sanitizedMode.sanitizedDurationMinutes)
    }

    func resolvedMode() -> FocusMode {
        var resolved = mode.sanitized()
        let trimmedActivity = activity.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDuration = min(max(durationMinutes, 5), 120)

        if !trimmedActivity.isEmpty {
            resolved.name = trimmedActivity
        }
        resolved.durationMinutes = resolvedDuration
        if resolved.enablePomodoro {
            resolved.pomodoroWorkMinutes = resolvedDuration
        }

        return resolved.sanitized()
    }
}
