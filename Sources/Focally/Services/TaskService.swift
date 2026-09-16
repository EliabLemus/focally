import Foundation
import Observation

/// Protocol abstraction for scheduling local reminders so the behavior is testable.
@MainActor
protocol TaskReminderScheduling: AnyObject {
    func scheduleReminder(taskID: UUID, title: String, dueDate: Date)
    func cancelReminder(taskID: UUID)
}

@MainActor
@Observable
final class TaskService {
    static let shared = TaskService(reminderScheduler: TaskReminderScheduler.shared)

    private(set) var tasks: [TaskItem] = []

    private let fileURL: URL
    private let fileManager: FileManager
    private let now: () -> Date
    private let reminderScheduler: TaskReminderScheduling?

    init(fileURL: URL? = nil,
         fileManager: FileManager = .default,
         now: @escaping () -> Date = Date.init,
         reminderScheduler: TaskReminderScheduling? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.fileManager = fileManager
        self.now = now
        self.reminderScheduler = reminderScheduler
        load()
    }

    static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".focally", isDirectory: true)
            .appendingPathComponent("tasks.json")
    }

    // MARK: - CRUD

    @discardableResult
    func addTask(title: String, dueDate: Date? = nil, notes: String? = nil) -> TaskItem? {
        guard let sanitized = TaskItem.sanitizedTitle(title) else { return nil }
        guard tasks.count < TaskItem.maxTasks else { return nil }
        let task = TaskItem(title: sanitized, createdAt: now(), dueDate: dueDate, notes: notes)
        tasks.append(task)
        sortInPlace()
        persist()
        scheduleReminderIfNeeded(for: task)
        return task
    }

    func updateTask(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }), task.isValid else { return }
        var updated = task
        if updated.isCompleted, updated.completedAt == nil {
            updated.completedAt = now()
        }
        if !updated.isCompleted {
            updated.completedAt = nil
        }
        tasks[index] = updated
        sortInPlace()
        persist()
        scheduleReminderIfNeeded(for: updated)
    }

    func removeTask(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        persist()
        reminderScheduler?.cancelReminder(taskID: id)
    }

    func toggleComplete(_ id: UUID) {
        guard var task = task(withID: id) else { return }
        if task.isCompleted {
            task.isCompleted = false
            task.completedAt = nil
        } else {
            task.isCompleted = true
            task.completedAt = now()
        }
        updateTask(task)
    }

    func move(from offsets: IndexSet, to offset: Int) {
        tasks.move(fromOffsets: offsets, toOffset: offset)
        persist()
    }

    func task(withID id: UUID) -> TaskItem? {
        tasks.first { $0.id == id }
    }

    var openTasks: [TaskItem] { tasks.filter { !$0.isCompleted } }
    var completedTasks: [TaskItem] { tasks.filter { $0.isCompleted } }
    var overdueTasks: [TaskItem] {
        let date = now()
        return openTasks.filter { guard let due = $0.dueDate else { return false }; return due < date }
    }

    // MARK: - Time attribution (reads FocusMetricsService records; single source of truth)

    func timeSpent(on taskID: UUID, records: [FocusSessionRecord]) -> TimeInterval {
        records
            .filter { $0.taskID == taskID }
            .reduce(0) { $0 + $1.activeDuration }
    }

    func completedPomodoros(on taskID: UUID, records: [FocusSessionRecord]) -> Int {
        records
            .filter { $0.taskID == taskID }
            .compactMap(\.pomodorosCompleted)
            .reduce(0, +)
    }

    // MARK: - Reminders

    private func scheduleReminderIfNeeded(for task: TaskItem) {
        guard !task.isCompleted, let due = task.dueDate else {
            reminderScheduler?.cancelReminder(taskID: task.id)
            return
        }
        reminderScheduler?.scheduleReminder(taskID: task.id, title: task.sanitizedTitle, dueDate: due)
    }

    // MARK: - Persistence (~/.focally/tasks.json)

    private func sortInPlace() {
        tasks.sort(by: Array.workQueueOrder)
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([TaskItem].self, from: data)
            tasks = Array(decoded.prefix(TaskItem.maxTasks)).filter(\.isValid)
            sortInPlace()
        } catch {
            // A corrupt tasks file must not crash the app; start empty (same policy
            // as SessionPersistenceService for active_session.json).
            tasks = []
        }
    }

    private func persist() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(tasks).write(to: fileURL, options: .atomic)
        } catch {
            // Persistence is best-effort; an I/O failure must not crash the app.
        }
    }
}
