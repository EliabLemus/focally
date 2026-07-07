# TASK-043: Fix Slack DND by adding keychain entitlements

## Problem
Slack DND doesn't work in v0.7.32 because Focally lacks keychain entitlements.
Error: `Client has neither com.apple.application-identifier nor com.apple.security.application-groups nor keychain-access-groups entitlements`

## Root Cause
`Focally/Focally.entitlements` only has `com.apple.security.automation.apple-events` but needs `keychain-access-groups` to read the `slack-token` from the keychain.

## Tasks

### 1. Add Keychain Entitlements
File: `Focally/Focally.entitlements`

Add AFTER line 6 (after automation.apple-events):
```xml
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)app.focally.Focally</string>
    </array>
```

The final file should be:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)app.focally.Focally</string>
    </array>
</dict>
</plist>
```

### 2. Bump Version
File: `project.yml`
- `MARKETING_VERSION`: `"0.7.32"` → `"0.7.33"`
- `CURRENT_PROJECT_VERSION`: `"46"` → `"47"`

### 3. Commit Changes
```bash
git add Focally/Focally.entitlements project.yml
git commit -m "fix: add keychain-access-groups entitlement for Slack token"
```

### 4. Push
```bash
git push origin main
```

### 5. Tag
```bash
git tag v0.7.33 HEAD && git push origin v0.7.33
```

## Validation
After CI completes:
1. Download DMG
2. Verify SHA256
3. Update Homebrew cask
4. Report SHA256 to user

## Notes
- This is a CRITICAL fix for Slack DND functionality
- Entitlements are required for macOS sandbox to access keychain items
- The `$(AppIdentifierPrefix)` variable is automatically replaced by Xcode with the Team ID