import Foundation
import UserNotifications
import os.log

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "NotificationService")

    enum Event {
        case workSessionStarted(activity: String, durationMinutes: Int)
        case workAlmostOver(activity: String)
        case breakStarted
        case longBreakStarted
        case sessionEnded
    }

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                self.logger.error("Notification auth error: \(error.localizedDescription, privacy: .public)")
            } else {
                self.logger.info("Notification auth granted: \(granted, privacy: .public)")
            }
        }
    }

    func notify(_ event: Event) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()

        switch event {
        case .workSessionStarted(let activity, let duration):
            content.title = "Focus Session Started"
            content.body = "\(activity) - \(duration) min"
        case .workAlmostOver(let activity):
            content.title = "Almost Time for Break!"
            content.body = "Your \(activity) session is ending in 5 minutes"
        case .breakStarted:
            content.title = "Break Time"
            content.body = "Time for a short break. Stay relaxed."
        case .longBreakStarted:
            content.title = "Long Break Time"
            content.body = "Great work! Time for a longer break."
        case .sessionEnded:
            content.title = "Session Ended"
            content.body = "Your focus session has finished"
        }

        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request) { error in
            if let error {
                self.logger.error("Failed to post notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(.banner)
    }
}
