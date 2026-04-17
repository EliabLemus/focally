import Foundation

struct FocusSession: Codable, Identifiable {
    let id: UUID
    let activity: String
    let emoji: String
    let durationMinutes: Int
    let startTime: Date
    var remainingSeconds: Int

    var totalSeconds: Int {
        durationMinutes * 60
    }

    var elapsedSeconds: Int {
        totalSeconds - remainingSeconds
    }

    init(activity: String, emoji: String, durationMinutes: Int) {
        self.id = UUID()
        self.activity = activity
        self.emoji = emoji
        self.durationMinutes = durationMinutes
        self.startTime = Date()
        self.remainingSeconds = durationMinutes * 60
    }
}
