# TASK-008: Fix 5 user-reported bugs (v0.4.5)

## Status: IN PROGRESS

## Date: 2026-04-30

## Bugs to Fix

### Bug 1: Permission dialog keeps appearing
**Root cause**: `DNDService.restartNotificationCenter()` calls `NSRunningApplication.forceTerminate()` on `com.apple.notificationcenterui`. macOS shows a permission dialog every time because the app doesn't have the `com.apple.security.temporary-exception.mach-lookup.global-name` entitlement or Automation permission to kill other processes.

**Fix**: Remove `forceTerminate()` entirely. Instead of killing NotificationCenter, use `DistributedNotificationCenter` to post `dndprefs_changed` and use a small delay. The CFPreferences + notification approach should work without restarting NotificationCenter. If restart is absolutely needed, use `NSWorkspace.shared.open(URL)` to relaunch it instead of `forceTerminate()`.

### Bug 2: Saved tasks horizontal layout
**Root cause**: `ActivityInputView.predefinedTaskSection` uses `ScrollView(.horizontal)` + `HStack`. User wants vertical list with checkmark selection.

**Fix**: Change to vertical `VStack` list. Each task shows with a radio/check indicator. Tapping fills the activity field. Selected task highlighted with accent color + checkmark icon on the right.

### Bug 3: Work start sound is annoying
**Root cause**: `playSound(.workStart)` fires on session start, and `soundRepeatCount: 5` with 0.8s intervals creates 5 consecutive sounds. Work start sound is unnecessary and annoying.

**Fix**: 
- Remove `.workStart` sound entirely — only play sounds on session END (work → break) and break END (break → work). 
- Reduce default `soundRepeatCount` from 5 to 2.
- Change interval from 0.8s to 1.0s for cleaner feel.

### Bug 4: No notification when session finishes
**Root cause**: `FocusTimerService.postNotification()` uses `UNUserNotificationCenter` but **nobody calls `requestAuthorization(options:)`** anywhere in the app. Without authorization, notifications are silently dropped.

**Fix**: In `AppDelegate.applicationDidFinishLaunching`, add:
```swift
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
    if let error {
        print("[Focally] Notification auth error: \(error)")
    }
}
```
Also set the delegate to handle foreground notification display:
```swift
UNUserNotificationCenter.current().delegate = self
```
And implement `UNUserNotificationCenterDelegate` with `userNotificationCenter(_:willPresent:withCompletionHandler:)` to show notifications even when app is in foreground (since Focally lives in menu bar, it's always "in foreground" from the system's perspective).

### Bug 5: Version shows 0.4.2
**Root cause**: `project.yml` has `MARKETING_VERSION: "0.4.2"` — was never updated.

**Fix**: Update to `MARKETING_VERSION: "0.4.5"` and bump `CURRENT_PROJECT_VERSION` to `"6"`.

## Files to Modify

1. `Focally/Services/DNDService.swift` — Remove `forceTerminate()`, use notification-only approach
2. `Focally/Views/ActivityInputView.swift` — Vertical saved tasks list with checkmark
3. `Focally/Services/FocusTimerService.swift` — Remove workStart sound, reduce repeat count, fix interval
4. `Focally/OnItFocusApp.swift` — Add notification authorization + delegate
5. `project.yml` — Update version to 0.4.5

## Acceptance Criteria
- [ ] No permission dialogs when activating/deactivating DND
- [ ] Saved tasks shown vertically with checkmark selection
- [ ] No sound on work session start; sounds only on phase transitions (end of work, end of break)
- [ ] Notification appears when work session ends and when break ends
- [ ] Version shows 0.4.5 in About menu
- [ ] Build succeeds without errors
