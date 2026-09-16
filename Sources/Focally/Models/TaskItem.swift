import Foundation

/// A to-do item that focus sessions (pomodoros) can be attributed to.
///
/// Tasks are local-only, lightweight, and ordered for a work queue:
/// actionable items first (soonest due date), completed items last.
struct TaskItem: Codable, Equatable, Identifiable {
    static let maxTitleLength = 200
    static let maxNotesLength = 2_000
    static let maxTasks = 500

    let id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var dueDate: Date?
    var completedAt: Date?
    var notes: String?

    init(id: UUID = UUID(),
         title: String,
         isCompleted: Bool = false,
         createdAt: Date = Date(),
         dueDate: Date? = nil,
         completedAt: Date? = nil,
         notes: String? = nil) {
        self.id = id
        self.title = TaskItem.sanitizedTitle(title) ?? ""
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.notes = notes.map { String($0.prefix(Self.maxNotesLength)) }
    }

    var sanitizedTitle: String { TaskItem.sanitizedTitle(title) ?? "" }

    var isValid: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= Self.maxTitleLength
    }

    static func sanitizedTitle(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxTitleLength))
    }
}

// MARK: - Ordering

extension Array where Element == TaskItem {
    /// Work-queue order: open tasks first (soonest due date, nil last, then creation),
    /// completed tasks at the end (most recently completed first).
    static func workQueueOrder(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        switch (lhs.isCompleted, rhs.isCompleted) {
        case (true, false): return false
        case (false, true): return true
        default: break
        }
        if lhs.isCompleted && rhs.isCompleted {
            let lhsDate = lhs.completedAt ?? lhs.createdAt
            let rhsDate = rhs.completedAt ?? rhs.createdAt
            return lhsDate > rhsDate
        }
        switch (lhs.dueDate, rhs.dueDate) {
        case let (lhsDue?, rhsDue?):
            if lhsDue != rhsDue { return lhsDue < rhsDue }
        case (nil, .some): return false
        case (.some, nil): return true
        default: break
        }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
