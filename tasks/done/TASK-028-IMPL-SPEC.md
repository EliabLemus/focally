# TASK-028-IMPL-SPEC: macOS DND Integration for Codex

**ID:** TASK-028-IMPL
**Priority:** CRITICAL
**For:** Codex (coding agent)
**Estimated Time:** 1 hour

---

## 🎯 Objective

Integrate `DNDService` with `FocusTimerService` so that when a focus session starts, macOS notifications are **completely blocked** (no banners, no sounds, no badges), and restored when the session ends.

**User Requirement:**
- MacBook in focus = Only critical/emergency notifications shown
- Focus session ends = All notifications restored

---

## 📋 Tasks

### Task 1: Enhance DNDService.swift
**Add macOS Notification Center blocking capabilities**

**Changes:**
```swift
class DNDService: ObservableObject {
    @Published var isDNDActive = false

    // NEW: Add notification center property
    private var notificationCenter: UNUserNotificationCenter?

    // NEW: Add logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "DNDService")

    // Modify init()
    override init() {
        super.init()
        // NEW: Initialize notification center
        notificationCenter = UNUserNotificationCenter.current()
        isDNDActive = Self.checkDNDStatus()
    }

    func activateDND() {
        guard !isDNDActive else { return }

        // 1. Set state
        isDNDActive = true

        // 2. Set macOS DND (existing code)
        Self.setPreference("doNotDisturb", value: true as CFPropertyList)
        Self.setPreference("doNotDisturbDate", value: Date() as CFPropertyList)
        Self.commitChanges()
        Self.restartNotificationCenter()
        Self.restoreMenuBarIcon()

        // 3. NEW: Block macOS notifications
        blockMacOSNotifications()

        // 4. Update UI after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isDNDActive = Self.checkDNDStatus()
            self?.logger.info("DND activation result: \(self?.isDNDActive ?? false, privacy: .public)")
        }
    }

    func deactivateDND() {
        guard isDNDActive else { return }

        // 1. Set state
        isDNDActive = false

        // 2. Disable macOS DND (existing code)
        Self.setPreference("doNotDisturb", value: false as CFPropertyList)
        Self.setPreference("doNotDisturbDate", value: nil)
        Self.commitChanges()
        Self.restoreMenuBarIcon()

        // 3. NEW: Restore macOS notifications
        unblockMacOSNotifications()

        // 4. Update UI after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isDNDActive = Self.checkDNDStatus()
            self?.logger.info("DND deactivation result: \(self?.isDNDActive ?? false, privacy: .public)")
        }
    }

    // MARK: - NEW: Block macOS notifications

    private func blockMacOSNotifications() {
        guard let center = notificationCenter else {
            notificationCenter = UNUserNotificationCenter.current()
        }

        logger.info("Blocking macOS notifications")

        if #available(macOS 14.0, *) {
            // Method 1: Disable all notification delivery (simple, direct)
            center.setNotificationDeliveryEnabled(false)

            // Method 2: Set notification mode to critical only
            let mode = UNNotificationMode()
            mode.alertSetting = .criticalOnly    // Only critical alerts
            mode.soundSetting = .disabled     // No sounds
            mode.badgeSetting = .disabled       // No badge
            mode.bannerSetting = .disabled       // No banners
            mode.timeSensitiveSetting = .disabled  // No time-sensitive banners
            mode.alertSetting = .nil            // User default (not modified)
            mode.scheduledDeliverySetting = .enable  // Allow scheduled (critical) notifications
            center.setNotificationMode(mode)

            logger.info("macOS notifications blocked using setNotificationDeliveryEnabled(false) and UNNotificationMode(.criticalOnly)")
        } else {
            // Fallback for macOS < 14.0: Use existing CFPreferences method
            logger.warning("macOS < 14.0, CFPreferences method is best effort")
            Self.setPreference("dndStart", value: 0 as CFPropertyList)
            Thread.sleep(forTimeInterval: 0.2)
            Self.setPreference("dndEnd", value: 1440 as CFPropertyList)
            Thread.sleep(forTimeInterval: 0.2)
            Self.setPreference("dndStart", value: nil)
        }
    }

    // MARK: - NEW: Restore macOS notifications

    private func unblockMacOSNotifications() {
        guard let center = notificationCenter else {
            notificationCenter = UNUserNotificationCenter.current()
        }

        logger.info("Restoring macOS notifications")

        if #available(macOS 14.0, *) {
            // Method 1: Re-enable all notification delivery
            center.setNotificationDeliveryEnabled(true)

            // Method 2: Restore normal notification mode
            let mode = UNNotificationMode()
            mode.alertSetting = nil        // User default
            mode.soundSetting = nil        // User default
            mode.badgeSetting = nil        // User default
            mode.bannerSetting = nil        // User default
            mode.timeSensitiveSetting = nil  // User default
            mode.alertSetting = .nil        // User default
            mode.scheduledDeliverySetting = .enable  // Allow scheduled notifications
            center.setNotificationMode(mode)

            logger.info("macOS notifications restored using setNotificationDeliveryEnabled(true) and default UNNotificationMode")
        } else {
            // Fallback for macOS < 14.0: Use existing CFPreferences method
            logger.warning("macOS < 14.0, CFPreferences method is best effort")
            // No action needed - CFPreferences revert when preferences file changes
        }
    }

    // ... rest of existing code ...
}
```

**Acceptance Criteria:**
- [ ] `DNDService` has `notificationCenter: UNUserNotificationCenter?` property
- [ ] `DNDService` has `logger: Logger` property
- [ ] `activateDND()` calls `blockMacOSNotifications()` after setting DND preferences
- [ ] `deactivateDND()` calls `unblockMacOSNotifications()` after disabling DND preferences
- [ ] `blockMacOSNotifications()` uses `setNotificationDeliveryEnabled(false)` on macOS 14.0+
- [ ] `blockMacOSNotifications()` sets `UNNotificationMode(.criticalOnly)` for macOS 14.0+
- [ ] `unblockMacOSNotifications()` uses `setNotificationDeliveryEnabled(true)` on macOS 14.0+
- [ ] `unblockMacOSNotifications()` restores default `UNNotificationMode` on macOS 14.0+
- [ ] Code compiles without errors
- [ ] No syntax errors in Swift code

---

### Task 2: Integrate DND with FocusTimerService

**Add DND calls at session start/end**

**Changes to `FocusTimerService.swift`:**

```swift
class FocusTimerService: ObservableObject {
    // NEW: Add DND service
    let dndService: DNDService

    init(...) {
        // ... existing init code ...
        dndService = DNDService()  // NEW
    }

    func startWorkSession(activity: String, emoji: String, durationMinutes: Int) {
        // ... existing start code ...

        // NEW: Activate DND 0.5s after session starts
        // This gives UI time to update before notifications are blocked
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.dndService.activateDND()
        }
    }

    func resetToIdle() {
        // ... existing reset code ...

        // NEW: Deactivate DND
        self.dndService.deactivateDND()

        // ... rest of existing code ...
    }
}
```

**Acceptance Criteria:**
- [ ] `FocusTimerService` has `dndService: DNDService` property
- [ ] `startWorkSession()` calls `dndService.activateDND()` after 0.5s delay
- [ ] `resetToIdle()` calls `dndService.deactivateDND()`
- [ ] `activateDND()` is called AFTER session state is updated (to avoid race conditions)
- [ ] Code compiles without errors
- [ ] No syntax errors in Swift code

---

## 🔧 Implementation Notes

### Important: Timing of DND Activation
**Call `activateDND()` 0.5 seconds AFTER** session state is updated.

**Why:**
- Focus UI needs time to update first (show DND badge, update state icons)
- If notifications are blocked too early, UI changes might not be visible
- 0.5s is a good balance between UI responsiveness and blocking interruptions

**Implementation:**
```swift
func startWorkSession(...) {
    // 1. Update session state first
    currentActivity = activity
    currentEmoji = emoji
    durationMinutes = durationMinutes
    // ... other state updates ...

    // 2. Then activate DND after delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.dndService.activateDND()
    }
}
```

### Important: No DND on Pause/Resume
**Only activate DND when session STARTS.**
**Do NOT deactivate DND when session is PAUSED.**
**Only deactivate DND when session ENDS (resetToIdle).**

**Why:**
- User is still in focus session even when paused
- DND should remain active during pause
- Only end DND when the user explicitly ends the session

### Important: iOS/Mobile Devices Out of Scope
**This integration ONLY affects macOS.**
- iPhone, iPad, and other mobile devices are NOT affected
- Slack status will still update on all devices
- Only MacBook notifications are blocked

---

## 🧪 Testing Steps

### Manual Testing on nexus

1. **Start a focus session**
   - Expected: DND badge appears in ActiveFocusView
   - Expected: macOS notifications are blocked (no banners, no sounds)
   - Verify: Send a test notification from Messages → No banner should appear
   - Verify: Notification appears in Notification Center (but not as banner)

2. **Pause the session**
   - Expected: DND badge remains visible
   - Expected: macOS notifications remain blocked

3. **Resume the session**
   - Expected: DND badge remains visible
   - Expected: macOS notifications remain blocked

4. **End the session** (click Finish or reset)
   - Expected: DND badge disappears
   - Expected: macOS notifications are restored (banners, sounds work normally)

5. **Test multiple sessions**
   - Start → Wait → End → Start → Wait → End
   - Expected: DND toggles correctly each time
   - Expected: No crashes or errors

6. **Test system DND vs app DND**
   - Enable macOS DND manually (in System Preferences)
   - Start a focus session
   - Expected: Both macOS DND and app DND are active
   - Expected: No crashes or conflicts

### Console.app Verification

**Look for these logs:**
```
DNDService: Blocking macOS notifications
DNDService: Activating Do Not Disturb via CFPreferences
DNDService: macOS notifications blocked using setNotificationDeliveryEnabled(false) and UNNotificationMode(.criticalOnly)
DNDService: DND activation result: true
DNDService: Restoring macOS notifications
DNDService: macOS notifications restored using setNotificationDeliveryEnabled(true) and default UNNotificationMode
```

---

## ✅ Out of Scope

- **NOT adding:** iOS mobile DND (out of scope)
- **NOT adding:** Slack status blocking during focus (already works, not needed)
- **NOT adding:** @AppStorage for DND state (use @Published only for runtime state)
- **NOT adding:** Permanent DND settings in macOS System Preferences (use per-session blocking)

---

## 📊 Success Criteria

### Functional Requirements
- [ ] Focus session starts → macOS notifications blocked after 0.5s
- [ ] Session paused → DND remains active
- [ ] Session ended → macOS notifications restored immediately
- [ ] DND badge/indicator visible in ActiveFocusView during sessions
- [ ] DND badge/indicator disappears after sessions end
- [ ] No crashes during DND transitions

### Technical Requirements
- [ ] `NSUserNotificationCenter.setNotificationDeliveryEnabled(false)` called on macOS 14.0+
- [ ] `UNNotificationMode(.criticalOnly)` set on macOS 14.0+
- [ ] `NSUserNotificationCenter.setNotificationDeliveryEnabled(true)` called on macOS 14.0+
- [ ] Default `UNNotificationMode` restored on macOS 14.0+
- [ ] DNDService and FocusTimerService integrated (no compilation errors)
- [ ] Logger.info() calls added for debugging

### User Experience
- [ ] User can still see critical/emergency notifications during focus
- [ ] User receives NO interruptions from normal notifications during focus
- [ ] Transitions are smooth (0.5s delay before blocking)
- [ ] No jarring notification sounds when DND activates

---

## 🎯 Definition of Done

**TASK-028-IMPL is COMPLETE when:**
1. All acceptance criteria above are met
2. Code compiles and builds successfully
3. Manual testing confirms notifications are blocked/restored as expected
4. Console.app logs show expected DND blocking/unblocking
5. No new bugs introduced by this feature

---

## 📝 Implementation Order

1. ✅ **Spec written** (this document)
2. ⏳ **Delegar a Codex** (next step)
3. ⏳ **Codex implements** Task 1 + Task 2
4. ⏳ **Manual testing on nexus**
5. ⏳ **Bug fixes if any**
6. ✅ **Task complete**

---

## 🚀 Next Steps for Codex

1. **Read** `Focally/Services/DNDService.swift`
2. **Modify** `DNDService.swift` to add:
   - `notificationCenter: UNUserNotificationCenter?` property
   - `logger: Logger` property
   - `blockMacOSNotifications()` method
   - `unblockMacOSNotifications()` method
   - Update `activateDND()` to call `blockMacOSNotifications()`
   - Update `deactivateDND()` to call `unblockMacOSNotifications()`

3. **Read** `Focally/Services/FocusTimerService.swift`
4. **Modify** `FocusTimerService.swift` to add:
   - `dndService: DNDService` property in `init()`
   - Call `dndService.activateDND()` in `startWorkSession()` with 0.5s delay
   - Call `dndService.deactivateDND()` in `resetToIdle()` (no delay)

5. **Build and test** on nexus

---

## 📁 Files to Modify

### Primary Files
- `Focally/Services/DNDService.swift`
- `Focally/Services/FocusTimerService.swift`

### Related Files (may need verification)
- `Focally/Views/Timer/ActiveFocusView.swift` (uses `dndService.isDNDActive`)
- `Focally/Services/NotificationService.swift` (should still work with DND active)

---

**SPEC COMPLETE** - Ready for Codex implementation
