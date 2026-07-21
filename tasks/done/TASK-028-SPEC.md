# TASK-028-SPEC: Slack + macOS DND Integration

**ID:** TASK-028
**Priority:** CRITICAL
**Estimated Time:** 2-3 hours
**Created:** 2026-05-05

---

## 🎯 Objective

Implement **macOS Do Not Disturb (DND) integration** to block all notifications during focus sessions, preventing interruptions on the MacBook during work periods.

**User Requirement:**
- Slack status updates ✅ (already working)
- DND activates on session start ✅ (already working)
- DND deactivates on session end ✅ (already working)
- **NEW: Block macOS notifications during focus session**
- **NEW: Restore macOS notifications after session ends**
- MacBook in focus = Only critical/emergency notifications shown

---

## 🔍 Current State Analysis

### What's Working
- `SlackService.setStatus()` updates Slack status ✅
- `DNDService.isDNDActive` toggles DND state ✅
- `SlackService` and `DNDService` are separate services ✅

### What's NOT Working
- macOS notifications are NOT being blocked when DND is active
- All notifications (including non-critical) come through
- No integration between DND state and macOS notification center

### Root Cause
`DNDService` only tracks state but doesn't control macOS notifications. Need to add methods that actually block/unblock `NSUserNotificationCenter`.

---

## 📋 Tasks

### 1. DNDService - Add macOS Notification Blocking

**File:** `Focally/Services/DNDService.swift`

**Add the following methods:**

```swift
class DNDService: ObservableObject {
    @Published var isDNDActive = false

    private var notificationCenter: NSUserNotificationCenter?

    override init() {
        super.init()
        notificationCenter = NSUserNotificationCenter.current()
    }

    func activateDND() {
        // 1. Set state to active
        isDNDActive = true

        // 2. BLOCK macOS notifications (NEW)
        blockMacOSNotifications()
    }

    func deactivateDND() {
        // 1. Set state to inactive
        isDNDActive = false

        // 2. RESTORE macOS notifications (NEW)
        unblockMacOSNotifications()
    }

    // MARK: - NEW: Block macOS notifications

    private func blockMacOSNotifications() {
        guard let center = notificationCenter else {
            notificationCenter = NSUserNotificationCenter.current()
        }

        if #available(macOS 14.0, *) {
            // Disable ALL notifications (except critical)
            center.setNotificationDeliveryEnabled(false)

            // Set notification mode to critical only
            let mode = UNNotificationMode()
            mode.alertSetting = .criticalOnly
            mode.soundSetting = .enabled
            mode.badgeSetting = .enabled
            mode.bannerSetting = .enabled
            center.setNotificationMode(mode)

            Logger.dnd.info("macOS notifications BLOCKED during DND")
        }
    }

    // MARK: - NEW: Restore macOS notifications

    private func unblockMacOSNotifications() {
        guard let center = notificationCenter else {
            notificationCenter = NSUserNotificationCenter.current()
        }

        if #available(macOS 14.0, *) {
            // Enable ALL notifications
            center.setNotificationDeliveryEnabled(true)

            // Restore normal notification mode
            let mode = UNNotificationMode()
            mode.alertSetting = nil  // User default
            mode.soundSetting = nil  // User default
            mode.badgeSetting = nil  // User default
            mode.bannerSetting = nil  // User default
            center.setNotificationMode(mode)

            Logger.dnd.info("macOS notifications RESTORED after DND")
        }
    }

    // MARK: - Existing methods (keep as is)

    // ... (keep existing methods if any)
}
```

### 2. FocusTimerService - Integrate DND Methods

**File:** `Focally/Services/FocusTimerService.swift`

**Add calls to DND methods at appropriate points:**

```swift
class FocusTimerService: ObservableObject {
    @EnvironmentObject var dndService: DNDService

    func startWorkSession(...) {
        // ... existing code ...

        // NEW: Activate DND (block notifications)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dndService.activateDND()
        }
    }

    func resetToIdle() {
        // ... existing code ...

        // NEW: Deactivate DND (restore notifications)
        self.dndService.deactivateDND()
    }

    func pauseSession() {
        // Optional: Deactivate DND on pause?
        // Keep simple for now - DND stays active
    }

    func resumeSession() {
        // Do nothing - DND remains active
    }
}
```

### 3. Update NotificationService for compatibility

**File:** `Focally/Services/NotificationService.swift`

**Ensure notifications still work when DND is NOT active:**

```swift
func notify(_ event: Event) {
    let center = UNUserNotificationCenter.current()
    let content = UNMutableNotificationContent()

    switch event {
    case .workSessionStarted(let activity, let duration):
        content.title = "Focus Session Started"
        content.body = "\(activity) - \(duration) min"
        // NOTE: This may be blocked if DND is active
        // That's OK - user wants to minimize interruptions during focus
    case .sessionEnded:
        content.title = "Session Completed"
        content.body = "Your focus session has finished"
        // This SHOULD still work (session ended, DND deactivated)
    }

    // ... rest of existing code ...
}
```

---

## 🎯 Acceptance Criteria

### Functional Requirements
- [ ] **Focus session starts → macOS notifications BLOCKED**
  - No banners, no sounds, no badges for normal notifications
  - Only critical/emergency notifications should come through

- [ ] **Focus session ends → macOS notifications RESTORED**
  - All notifications恢复正常
  - Banners, sounds, badges all work again

- [ ] **Slack status still updates** during sessions
  - Start session → Slack status updates
  - End session → Slack status clears
  - No regression in Slack functionality

- [ ] **DND indicator shows** in UI
  - `dndService.isDNDActive == true` during sessions
  - Badge/indicator visible in ActiveFocusView
  - Badge/indicator disappears after session ends

- [ ] **No crashes or errors** during DND transitions
  - No errors in Console.app
  - No crashes when toggling DND

### Technical Requirements
- [ ] Uses `NSUserNotificationCenter.setNotificationDeliveryEnabled()` (macOS 14.0+)
- [ ] Uses `UNNotificationMode` with `.criticalOnly` for focus
- [ ] Calls methods on main thread (using `DispatchQueue.main.async`)
- [ ] Graceful error handling if Notification Center unavailable
- [ ] Logs actions for debugging (use existing Logger)

---

## 🔧 Implementation Notes

### Important: Timing
- **Delay DND activation by 0.5 seconds** after session starts
  - This gives the session UI time to update first
  - Prevents jarring experience

### Important: User Defaults
- **Do NOT use `@AppStorage` for DND state** during session
  - Use `@Published var isDNDActive` for in-app indicator only
  - `setNotificationDeliveryEnabled()` doesn't persist - it's runtime-only
  - This is correct behavior (DND is per-session, not a permanent setting)

### Important: Fallback
- **If `setNotificationDeliveryEnabled()` fails**, continue gracefully
  - The app should still work
  - Log the error
  - Don't crash

### Important: macOS 14.0+
- **Check availability:** `if #available(macOS 14.0, *) { ... }`
- **If macOS 13.x or older:** Show a message or skip gracefully
- **Focally deployment target is macOS 14.0**, so this should always work

---

## 🧪 Testing Steps

### Manual Testing on nexus

1. **Start a focus session**
   - Expected: DND badge appears in ActiveFocusView
   - Expected: macOS notifications are blocked (no banners/sounds)

2. **Test notification blocking**
   - Send a notification from another app (e.g., Calendar, Slack, Messages)
   - Expected: No banner, no sound appears
   - Expected: Notification appears in Notification Center but not as banner

3. **End the focus session**
   - Click "Finish" button
   - Expected: DND badge disappears
   - Expected: macOS notifications are restored
   - Expected: Normal banners appear again

4. **Test multiple sessions**
   - Start → Wait → Finish → Start → Wait → Finish
   - Expected: DND toggles correctly each time
   - Expected: No errors or crashes

5. **Test Slack integration still works**
   - Start session → Check Slack status (should show focus emoji)
   - End session → Check Slack status (should clear)
   - Expected: No regression

### Console.app Logs
- Look for errors from Focally related to NSUserNotificationCenter
- Verify "macOS notifications BLOCKED" and "RESTORED" logs appear
- Check for any errors during DND transitions

---

## 📚 References

### Apple Documentation
- **UNNotificationMode:** https://developer.apple.com/documentation/usernotifications/unnotificationmode
- **setNotificationDeliveryEnabled:** https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/3847350-setnotificationdeliveryenabled

### Existing Code
- `DNDService.swift` - Current state (only tracks state, doesn't block notifications)
- `FocusTimerService.swift` - Session start/end methods
- `ActiveFocusView.swift` - Shows DND badge (uses `dndService.isDNDActive`)

---

## ✅ Out of Scope

- **Permanent DND settings in macOS System Preferences**
  - We only block during Focally sessions, not globally
  - User controls this separately in System Settings

- **App-specific DND settings in macOS Notification Center**
  - We use global notification blocking, not per-app settings
  - This is simpler and meets requirements

- **Focus modes on other devices (iPhone, iPad)**
  - Only concerned with MacBook notifications
  - Mobile devices are out of scope

---

## 🚀 Success Criteria

### When Complete
- **macOS notifications are blocked during focus sessions** ✅
- **Notifications are restored after sessions end** ✅
- **Slack status still updates correctly** ✅
- **No crashes or errors** ✅
- **User can verify blocking works** (by testing with other apps) ✅

### Definition of "Done"
- All code changes implemented
- Built successfully on nexus
- Manually tested at least once
- All acceptance criteria met

---

## 📝 Implementation Order

1. **DNDService.swift** - Add `blockMacOSNotifications()` and `unblockMacOSNotifications()` methods
2. **FocusTimerService.swift** - Add DND calls at session start/end
3. **Build** - Verify no compilation errors
4. **Manual testing** - Test blocking and restoration on nexus
5. **Documentation** - Update user-facing docs if needed

---

**SPEC COMPLETE** - Ready for implementation
