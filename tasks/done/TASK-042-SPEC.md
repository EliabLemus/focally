# TASK-042: Fix DND and Slack Issues (URGENT)

## Summary
Critical bugs identified from user logs in v0.7.31 that break core functionality.

## Root Causes Analysis

### Issue 1: DND Not Activating
**Log error:**
```
tccd attempted to call TCCAccessRequest for kTCCServiceAccessibility
without the recommended com.apple.private.tcc.manager.check-by-audit-token entitlement
```

**Analysis:**
- `DNDService.swift` uses `CFPreferences` to modify Notification Center preferences directly
- This approach **does NOT require Accessibility permissions**
- The TCC error is likely from legacy code or system testing
- **Real issue:** CFPreferences modification may fail silently due to missing entitlements or permission prompts

**Entitlements review:**
Current `Focally/Focally.entitlements`:
```xml
<key>com.apple.security.automation.apple-events</key>
<true/>
```

This is for Apple Events (Shortcuts), not for CFPreferences modification.

### Issue 2: Slack Status Not Updating
**User reports:** Slack status doesn't update when starting focus sessions.

**Log errors:**
```
usernoted Found no match to delete for ["CC48-6F9A"]
usernoted Found no match to delete for ["7160-D222"]
```

**Analysis:**
- These are APNs remote notification IDs (format: 4 chars-4 chars)
- `NotificationService.swift` creates local notifications with UUIDs
- **NO code in Focally deletes notifications**
- These errors are likely system noise from other apps or leftover notification attempts

**Real issue:** Slack status updates failing due to:
- Invalid Slack token
- Network errors
- Missing error handling in API calls

### Issue 3: Meeting Category Not Visible
**User reports:** Meeting category doesn't appear in predefined tasks.

**Analysis:**
- `MeetingDurationPicker.swift` was added in v0.7.28
- `PredefinedTask.swift` should include meeting task
- Migration code should add meeting task if missing

## Implementation Requirements

### Fix 1: Add Entitlements for CFPreferences
**Rationale:** CFPreferences modification of system preferences requires proper entitlements.

**Changes:**
1. Update `Focally/Focally.entitlements` to include:
```xml
<key>com.apple.security.automation.apple-events</key>
<true/>
```
(This is already present and correct for Apple Events)

2. Update `Focally/Info.plist` to add permission descriptions:
```xml
<key>NSAppleEventsUsageDescription</key>
<string>Focally needs AppleEvents to control Do Not Disturb mode.</string>
```
(This is already present - CORRECT)

3. **NO changes needed to entitlements** - CFPreferences doesn't require special entitlements for user preferences.

### Fix 2: Improve DNDService Error Handling
**Rationale:** CFPreferences operations can fail silently. Need better logging and error detection.

**Changes to `DNDService.swift`:**
1. Check if `CFPreferencesSetValue` succeeds
2. Add error logging when preferences fail
3. Verify DND actually activated after `checkDNDStatus()`
4. Add user-facing error message when DND activation fails

**Implementation:**
```swift
func activateDND() {
    guard !isDNDActive else { return }
    logger.info("Activating Do Not Disturb via CFPreferences")

    // Attempt to set preferences
    Self.setPreference("doNotDisturb", value: true as CFPropertyList)
    Self.setPreference("doNotDisturbDate", value: Date() as CFPropertyList)

    // Commit and check if successful
    Self.commitChanges()
    let success = Self.restartNotificationCenter()

    if !success {
        logger.error("Failed to activate DND - restart notification center failed")
        // TODO: Show error to user
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let self else { return }
        let actuallyActive = Self.checkDNDStatus()
        if !actuallyActive {
            self.logger.error("DND activation failed - status still inactive")
            // TODO: Show error to user
        }
        self.isDNDActive = actuallyActive
    }

    isDNDActive = true
}
```

### Fix 3: Add Better Slack Error Handling
**Rationale:** User doesn't know why Slack status fails to update.

**Changes to `SlackService.swift`:**
1. Ensure all API errors are logged with full context
2. Check for HTTP 401 (invalid token) and show clear error
3. Check for network errors and show clear error
4. Add user-facing error message when Slack integration fails

**Key areas to improve:**
- Line 161: `logger.error("Slack setStatus failed. httpStatus=\(statusCode), error=\(errorMsg)")`
- Add: Show error in UI via `connectionError` (already implemented)
- Verify `connectionError` is displayed to user in settings

### Fix 4: Ensure Meeting Category is Added
**Rationale:** Migration code should add meeting task to predefined tasks.

**Changes to `PredefinedTask.swift`:**
1. Verify `migrateTasksIfNeeded()` includes meeting task
2. Check if meeting task is being added correctly
3. Test migration on fresh install

## Testing Checklist
- [ ] Install v0.7.32 fresh
- [ ] Start a focus session and check Console.app for TCC errors
- [ ] Start a focus session and verify DND activates (control center shows moon icon)
- [ ] Check Console.app for DND activation success/failure logs
- [ ] Enable Slack integration with valid token
- [ ] Start a focus session and verify Slack status updates
- [ ] Check Console.app for Slack API success/error logs
- [ ] Start a meeting session and verify `:google-meet:` emoji appears
- [ ] Verify meeting category appears in predefined tasks list

## Files to Modify
1. `Focally/Services/DNDService.swift` - Add error handling and logging
2. `Focally/Services/SlackService.swift` - Improve error messages
3. `Focally/Models/PredefinedTask.swift` - Verify meeting task migration

## Files NOT to Modify
- `Focally/Focally.entitlements` - Entitlements are already correct
- `Focally/Info.plist` - Permission descriptions are already correct
- `Focally/Services/NotificationService.swift` - No issues found

## Priority
**URGENT** - DND is a core feature that's broken.