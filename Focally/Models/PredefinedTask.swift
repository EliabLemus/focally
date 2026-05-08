import Foundation
import SwiftUI

struct PredefinedTask: Identifiable, Codable, Equatable {
    static let defaultsKey = "predefinedTasks"

    var id: UUID = UUID()
    var name: String
    var emoji: String
    var icon: String
    var iconBgColor: String
    var iconFgColor: String
    var durationMinutes: Int
    var cycles: Int

    static let defaultTasks: [PredefinedTask] = [
        PredefinedTask(name: "Pomodoro", emoji: "🍅", icon: "timer", iconBgColor: "FFE4E6", iconFgColor: "E11D48", durationMinutes: 25, cycles: 4),
        PredefinedTask(name: "Deep Coding", emoji: "💻", icon: "chevron.left.forwardslash.chevron.right", iconBgColor: "DBEAFE", iconFgColor: "2563EB", durationMinutes: 25, cycles: 4),
        PredefinedTask(name: "Technical Documentation", emoji: "📚", icon: "doc.text", iconBgColor: "FFEDD5", iconFgColor: "EA580C", durationMinutes: 50, cycles: 2),
        PredefinedTask(name: "Inbox Clearing", emoji: "📧", icon: "envelope", iconBgColor: "F3E8FF", iconFgColor: "9333EA", durationMinutes: 15, cycles: 1),
        PredefinedTask(name: "Quick Workout", emoji: "💪", icon: "figure.strengthtraining.traditional", iconBgColor: "DCFCE7", iconFgColor: "16A34A", durationMinutes: 10, cycles: 1)
    ]
}

@MainActor
final class PredefinedTaskStore: ObservableObject {
    @Published private(set) var tasks: [PredefinedTask] = [] {
        didSet { saveTasks() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.tasks = Self.loadTasks(from: defaults)
    }

    func add(_ task: PredefinedTask) {
        tasks.append(task)
    }

    func update(_ task: PredefinedTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
    }

    func remove(_ task: PredefinedTask) {
        tasks.removeAll { $0.id == task.id }
    }

    private func saveTasks() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        defaults.set(data, forKey: PredefinedTask.defaultsKey)
    }

    private static func loadTasks(from defaults: UserDefaults) -> [PredefinedTask] {
        guard let data = defaults.data(forKey: PredefinedTask.defaultsKey),
              let tasks = try? JSONDecoder().decode([PredefinedTask].self, from: data),
              !tasks.isEmpty else {
            return PredefinedTask.defaultTasks
        }

        return tasks
    }
}

extension PredefinedTask {
    /// Valida el emoji para Slack y retorna warnings si es necesario
    /// - Parameter slackService: Servicio de Slack para validar
    /// - Returns: Array de mensajes de warning (vacío si no hay problemas)
    func validateForSlack(slackService: SlackService) -> [String] {
        guard slackService.isConnected else { return [] }
        guard EmojiValidator.isValidForSlack(emoji, workspaceEmojis: slackService.workspaceEmojiCodes) else {
            return [
                "This emoji may not display correctly in Slack. Consider selecting an emoji from your workspace."
            ]
        }

        return []
    }
}
