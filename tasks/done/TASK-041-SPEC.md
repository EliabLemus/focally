# TASK-041: Fix DND and Slack Notification Issues

## Summary
Critical bugs identified from user logs in v0.7.31 that break core functionality:
1. **DND not activating** - Missing Accessibility entitlement causes TCC error
2. **Slack notifications failing** - Invalid notification IDs cause usernoted errors

## Root Causes Analysis

### Issue 1: Missing Accessibility Entitlement
**Log error (17:00:33):**
```
tccd attempted to call TCCAccessRequest for kTCCServiceAccessibility 
without the recommended com.apple.private.tcc.manager.check-by-audit-token entitlement
```

**Impact:** DNDService cannot activate system Do Not Disturb because TCC blocks the request.

**Current entitlements file:** `Focally/Focally.entitlements`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.automation.apple-events</key>
	<true/>
</dict>
</plist>
```

### Issue 2: Invalid Slack Notification IDs
**Log errors (17:00:52, 17:01:25):**
```
usernoted Found no match to delete for ["CC48-6F9A"]
usernoted Found no match to delete for ["7160-D222"]
```

**Impact:** SlackService is trying to delete notifications that don't exist, causing status updates to fail.

**Analysis needed:**
- Check if `SlackService.swift` creates notifications
- Identify where these IDs are generated
- Determine if notification deletion is necessary

## Implementation Requirements

### Fix 1: Add Accessibility Entitlement to Focally.entitlements
1. Update `Focally/Focally.entitlements` to include proper accessibility entitlements
2. For macOS apps, Accessibility is a system permission that requires:
   - The app to request permission via NSAppleEventsUsageDescription in Info.plist
   - User to grant permission in System Settings > Privacy & Security > Accessibility
3. The entitlement file should properly declare capabilities

**Note on macOS Accessibility:**
Unlike iOS, macOS Accessibility permissions are:
- Requested via Info.plist keys (`NSAppleEventsUsageDescription`)
- Granted by user in System Settings (not via entitlements alone)
- The entitlement error suggests the app is trying to check permissions incorrectly

**Fix approach:**
- Add `com.apple.security.automation.apple-events` (already present)
- Ensure Info.plist has proper description keys for Accessibility
- Fix DNDService to properly check permissions before attempting to activate

### Fix 2: Fix or Remove Slack Notification Deletion
**Investigation steps:**
1. Search `SlackService.swift` for notification-related code:
   - `UNUserNotificationCenter`
   - `removeDeliveredNotifications`
   - `removeAllDeliveredNotifications`
2. If notifications are not actually created, remove deletion code
3. If notifications are created, fix ID generation

**Likely fix:**
The error suggests notifications aren't being created, only deleted. Remove the deletion code entirely.

## Acceptance Criteria

### DND Fix
- [ ] TCC error `com.apple.private.tcc.manager.check-by-audit-token` no longer appears in Console.app
- [ ] DND activates when starting a focus session
- [ ] DND deactivates when ending a focus session
- [ ] User is prompted for Accessibility permission on first use (if not already granted)

### Slack Fix
- [ ] usernoted errors `Found no match to delete` no longer appear in Console.app
- [ ] Slack status updates successfully on session start
- [ ] Slack status clears successfully on session end
- [ ] Meeting category uses `:google-meet:` emoji correctly

### Meeting Category
- [ ] Meeting category appears in predefined tasks list
- [ ] MeetingDurationPicker is accessible and functional
- [ ] Meeting sessions use correct emoji `:google-meet:` in Slack

## Files to Modify
1. `Focally/Focally.entitlements` - Add accessibility entitlements
2. `Focally/Info.plist` - Add permission description keys (if missing)
3. `Focally/Services/SlackService.swift` - Fix notification deletion
4. `Focally/Services/DNDService.swift` - Fix permission checking

## Testing Checklist
- [ ] Build and install v0.7.32 with new entitlements
- [ ] Grant Accessibility permission in System Settings when prompted
- [ ] Start a focus session and verify DND activates
- [ ] Check Console.app for TCC errors (should be gone)
- [ ] Start a focus session with Slack enabled
- [ ] Verify Slack status updates to "In focus" with correct emoji
- [ ] Check Console.app for usernoted errors (should be gone)
- [ ] Start a meeting session
- [ ] Verify Slack status shows "En meeting" with `:google-meet:` emoji
- [ ] End all sessions and verify DND deactivates and Slack status clears

## Priority
**URGENT** - These issues break core functionality and prevent the app from working as intended.