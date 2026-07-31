import Foundation

enum PomodoroState: String, Codable {
    case idle
    case work
    case shortBreak
    case longBreak
    case completed
}
