# TASK-010: Extract NotificationService from FocusTimerService

## Status: TODO

## Date: 2026-05-01

## Objective
Extract all `UNUserNotificationCenter` notification logic from `FocusTimerService` into a standalone `NotificationService`. FocusTimerService should call a simple `notify(event:)` method instead of building notifications itself.

## Files to Create
- `Focally/Services/NotificationService.swift`

## Files to Modify
- `Focally/Services/FocusTimerService.swift` — remove notification code, use `NotificationService`
- `Focally/OnItFocusApp.swift` — create `NotificationService`, pass to timer

## Detailed Specification

### New File: `NotificationService.swift`

```swift
import Foundation
import UserNotifications
import os.log

class NotificationService {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "NotificationService")
    
    enum Event {
        case workSessionStarted(activity: String, durationMinutes: Int)
        case workAlmostOver(activity: String)
        case breakStarted
        case longBreakStarted
        case sessionEnded
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
}
```

### Changes to FocusTimerService

Remove:
- `import UserNotifications`
- `enum NotificationName` (private)
- `private func postNotification(_ name: NotificationName)` method
- All UNMutableNotificationContent / UNNotificationRequest code

Add:
- `let notificationService: NotificationService` (injected via init)
- Replace `postNotification(.workSessionStarted)` with `notificationService.notify(.workSessionStarted(activity: currentActivity, durationMinutes: workDurationMinutes))`
- Replace all other `postNotification(...)` calls similarly

### Changes to OnItFocusApp.swift

- Remove `import UserNotifications` (handled by NotificationService now)
- Remove `UNUserNotificationCenter.current().delegate = self` from `applicationDidFinishLaunching`
- Remove `UNUserNotificationCenter.current().requestAuthorization(...)` call
- Remove `userNotificationCenter(_:willPresent:withCompletionHandler:)` delegate method
- Remove `UNUserNotificationCenterDelegate` conformance from AppDelegate
- Create `let notificationService = NotificationService()` in AppDelegate
- In `applicationDidFinishLaunching`, call `notificationService.requestAuthorization()`
- Set `UNUserNotificationCenter.current().delegate` in a small `NotificationDelegate` class inside `NotificationService.swift` or keep the delegate in AppDelegate but simplify

**IMPORTANT**: Keep the `UNUserNotificationCenterDelegate` in AppDelegate since it needs to present notifications in foreground. But the delegate implementation should be minimal — just calling `completionHandler(.banner)`. The service should set up the delegate.

**Revised approach**: Add the delegate to `NotificationService` itself:

```swift
class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    // ... existing code ...
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(.banner)
    }
}
```

This means AppDelegate can fully drop `UNUserNotificationCenterDelegate`.

## Acceptance Criteria
- [ ] `NotificationService.swift` created
- [ ] `FocusTimerService` has zero `import UserNotifications` or notification code
- [ ] AppDelegate no longer conforms to `UNUserNotificationCenterDelegate`
- [ ] `applicationDidFinishLaunching` calls `notificationService.requestAuthorization()`
- [ ] Notifications still appear when timer transitions happen
- [ ] Build succeeds
