import Foundation
import UserNotifications

/// Schedules local notifications for task due dates via UNUserNotificationCenter.
///
/// Identifier is deterministic (`task-reminder-<uuid>`) so re-scheduling a task
/// replaces its pending request instead of duplicating it.
final class TaskReminderScheduler: TaskReminderScheduling {
    static let shared = TaskReminderScheduler()

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    static func identifier(for taskID: UUID) -> String {
        "task-reminder-\(taskID.uuidString)"
    }

    func scheduleReminder(taskID: UUID, title: String, dueDate: Date) {
        guard dueDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = NSLocalizedString("task_reminder_body", comment: "Task due reminder body")
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier(for: taskID), content: content, trigger: trigger)

        center.requestAuthorization(options: [.alert, .sound]) { [center] granted, error in
            guard granted else {
                if let error {
                    Logger.tasks.error("Notification authorization denied: \(error.localizedDescription)")
                }
                return
            }
            center.add(request) { error in
                if let error {
                    Logger.tasks.error("Failed to schedule task reminder: \(error.localizedDescription)")
                }
            }
        }
    }

    func cancelReminder(taskID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier(for: taskID)])
    }
}
