import Foundation

enum PomodoroState: String, Codable {
    case idle
    case work
    case shortBreak
    case longBreak
    case completed
}

struct FocusSession: Codable, Identifiable {
    let id: UUID
    let activity: String
    let emoji: String
    let durationMinutes: Int
    let startTime: Date
    var remainingSeconds: Int
    let pomodoroState: PomodoroState
    let currentRound: Int
    let totalRoundsUntilLongBreak: Int
    let isAutoStartEnabled: Bool

    var totalSeconds: Int {
        durationMinutes * 60
    }

    var elapsedSeconds: Int {
        totalSeconds - remainingSeconds
    }

    init(activity: String, emoji: String, durationMinutes: Int, 
         pomodoroState: PomodoroState = .idle,
         currentRound: Int = 0,
         totalRoundsUntilLongBreak: Int = 3,
         isAutoStartEnabled: Bool = true) {
        self.id = UUID()
        self.activity = activity
        self.emoji = emoji
        self.durationMinutes = durationMinutes
        self.startTime = Date()
        self.remainingSeconds = durationMinutes * 60
        self.pomodoroState = pomodoroState
        self.currentRound = currentRound
        self.totalRoundsUntilLongBreak = totalRoundsUntilLongBreak
        self.isAutoStartEnabled = isAutoStartEnabled
    }
}
