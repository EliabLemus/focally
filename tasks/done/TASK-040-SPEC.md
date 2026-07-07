# TASK-040: Fix DND and Slack Notification Issues (URGENT)

## Summary
Critical issues identified from user logs in v0.7.31:
1. DND not activating due to missing Accessibility entitlement
2. Slack notifications failing with invalid notification IDs

## Root Causes

### 1. Missing Accessibility Entitlement
**Log error:**
```
tccd attempted to call TCCAccessRequest for kTCCServiceAccessibility 
without the recommended com.apple.private.tcc.manager.check-by-audit-token entitlement
```

**Impact:** System DND cannot be activated because the app lacks proper Accessibility permissions.

**Current state:** `Focally/Focally.entitlements` only has:
```xml
<key>com.apple.security.automation.apple-events</key>
<true/>
```

### 2. Invalid Notification IDs
**Log errors:**
```
usernoted Found no match to delete for ["CC48-6F9A"]
usernoted Found no match to delete for ["7160-D222"]
```

**Impact:** Slack status updates failing due to broken notification flow.

**Analysis needed:** 
- Check if `SlackService.swift` uses UNUserNotificationCenter
- Identify where notification IDs are generated
- Fix ID generation or remove unnecessary notification deletion

## Requirements

### Fix 1: Add Accessibility Entitlement
1. Update `Focally/Focally.entitlements` to include Accessibility permission
2. Add proper entitlements for macOS Accessibility control
3. Test DND activation with new entitlements

### Fix 2: Fix Slack Notification IDs
1. Identify where notification IDs are generated in `SlackService.swift`
2. Fix ID generation to use valid UUID format
3. Remove unnecessary notification deletion if not needed
4. Test Slack status updates with fixed notification IDs

## Implementation Notes

### Accessibility Entitlement Format
For macOS, the entitlement should include:
```xml
<key>com.apple.security.automation.apple-events</key>
<true/>
```

Note: Accessibility permissions on macOS are typically requested via the system permission prompt, not via entitlements. However, the error suggests the entitlement is missing.

### Notification ID Format
Valid UNNotificationRequest IDs should be simple strings (UUIDs work), but the deletion error suggests the IDs don't match any existing notifications.

**Options:**
- Remove notification deletion code entirely (if not needed)
- Fix ID generation to use proper format: `UUID().uuidString`
- Check if notifications are being created before deletion

## Testing Checklist
- [ ] Verify DND activates when starting a session
- [ ] Verify Slack status updates successfully
- [ ] Check Console.app for TCC errors (should be gone)
- [ ] Check Console.app for usernoted errors (should be gone)
- [ ] Test meeting category with `:google-meet:` emoji

## Priority
**URGENT** - This breaks core functionality of the app.