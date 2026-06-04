import Foundation
import SwiftUI

enum TaskType: String, Codable, CaseIterable {
    case pomodoro
    case deepWork
    case meeting

    var displayName: String {
        switch self {
        case .pomodoro:
            return "Pomodoro"
        case .deepWork:
            return "Deep Work"
        case .meeting:
            return "Meeting"
        }
    }
}

struct PredefinedTask: Identifiable, Codable, Equatable {
    static let defaultsKey: String = "predefinedTasks"
    static let meetingDurations: [Int] = [15, 30, 45, 60, 90, 120]

    var id: UUID = UUID()
    var name: String
    var emoji: String
    var icon: String
    var iconBgColor: String
    var iconFgColor: String
    var durationMinutes: Int
    var cycles: Int
    var taskType: TaskType
    var availableDurations: [Int]

    init(id: UUID = UUID(),
         name: String,
         emoji: String,
         icon: String,
         iconBgColor: String,
         iconFgColor: String,
         durationMinutes: Int = 25,
         cycles: Int = 1,
         taskType: TaskType = .pomodoro,
         availableDurations: [Int] = []) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.icon = icon
        self.iconBgColor = iconBgColor
        self.iconFgColor = iconFgColor
        self.durationMinutes = durationMinutes
        self.cycles = cycles
        self.taskType = taskType
        self.availableDurations = Self.normalizeDurations(
            availableDurations,
            fallbackDuration: durationMinutes,
            taskType: taskType
        )
    }

    static let defaultTasks: [PredefinedTask] = [
        PredefinedTask(name: "Pomodoro", emoji: "🍅", icon: "timer", iconBgColor: "FFE4E6", iconFgColor: "E11D48", durationMinutes: 25, cycles: 4, taskType: .pomodoro),
        PredefinedTask(name: "Deep Coding", emoji: "💻", icon: "chevron.left.forwardslash.chevron.right", iconBgColor: "DBEAFE", iconFgColor: "2563EB", durationMinutes: 25, cycles: 4, taskType: .deepWork),
        PredefinedTask(name: "Technical Documentation", emoji: "📚", icon: "doc.text", iconBgColor: "FFEDD5", iconFgColor: "EA580C", durationMinutes: 50, cycles: 2, taskType: .deepWork),
        PredefinedTask(name: "Inbox Clearing", emoji: "📧", icon: "envelope", iconBgColor: "F3E8FF", iconFgColor: "9333EA", durationMinutes: 15, cycles: 1, taskType: .deepWork),
        PredefinedTask(name: "Quick Workout", emoji: "💪", icon: "figure.strengthtraining.traditional", iconBgColor: "DCFCE7", iconFgColor: "16A34A", durationMinutes: 10, cycles: 1, taskType: .deepWork),
        PredefinedTask(
            name: "Meeting",
            emoji: "📅",
            icon: "calendar",
            iconBgColor: "E0F2FE",
            iconFgColor: "0369A1",
            durationMinutes: 30,
            cycles: 1,
            taskType: .meeting,
            availableDurations: meetingDurations
        )
    ]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case icon
        case iconBgColor
        case iconFgColor
        case durationMinutes
        case cycles
        case taskType
        case availableDurations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let name = try container.decode(String.self, forKey: .name)
        let emoji = try container.decode(String.self, forKey: .emoji)
        let icon = try container.decode(String.self, forKey: .icon)
        let iconBgColor = try container.decode(String.self, forKey: .iconBgColor)
        let iconFgColor = try container.decode(String.self, forKey: .iconFgColor)
        let durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        let cycles = try container.decode(Int.self, forKey: .cycles)
        let decodedTaskType = try container.decodeIfPresent(TaskType.self, forKey: .taskType)
        let taskType = decodedTaskType ?? Self.inferLegacyTaskType(name: name)
        let decodedDurations = try container.decodeIfPresent([Int].self, forKey: .availableDurations) ?? []

        self.init(
            id: id,
            name: name,
            emoji: emoji,
            icon: icon,
            iconBgColor: iconBgColor,
            iconFgColor: iconFgColor,
            durationMinutes: durationMinutes,
            cycles: cycles,
            taskType: taskType,
            availableDurations: decodedDurations
        )
    }

    private static func inferLegacyTaskType(name: String) -> TaskType {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "pomodoro" {
            return .pomodoro
        }
        if normalized.contains("meeting") {
            return .meeting
        }
        return .deepWork
    }

    internal static func normalizeDurations(_ durations: [Int], fallbackDuration: Int, taskType: TaskType) -> [Int] {
        let sanitized = durations.filter { $0 > 0 }.sorted()
        if !sanitized.isEmpty {
            return sanitized
        }
        if taskType == .meeting {
            return meetingDurations
        }
        return [fallbackDuration]
    }
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
        migrateTasksIfNeeded()
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

    private func migrateTasksIfNeeded() {
        var didChange = false
        var migratedTasks = tasks.map { task -> PredefinedTask in
            let normalizedDurations = PredefinedTask.normalizeDurations(
                task.availableDurations,
                fallbackDuration: task.durationMinutes,
                taskType: task.taskType
            )
            if normalizedDurations != task.availableDurations {
                didChange = true
            }
            return PredefinedTask(
                id: task.id,
                name: task.name,
                emoji: task.emoji,
                icon: task.icon,
                iconBgColor: task.iconBgColor,
                iconFgColor: task.iconFgColor,
                durationMinutes: task.durationMinutes,
                cycles: task.cycles,
                taskType: task.taskType,
                availableDurations: normalizedDurations
            )
        }

        if migratedTasks.first(where: { $0.taskType == .meeting }) == nil {
            migratedTasks.append(
                PredefinedTask(
                    name: "Meeting",
                    emoji: "📅",
                    icon: "calendar",
                    iconBgColor: "E0F2FE",
                    iconFgColor: "0369A1",
                    durationMinutes: 30,
                    cycles: 1,
                    taskType: .meeting,
                    availableDurations: PredefinedTask.meetingDurations
                )
            )
            didChange = true
        }

        if didChange {
            tasks = migratedTasks
        }
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
