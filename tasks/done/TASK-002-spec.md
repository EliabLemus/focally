# TASK-002 Spec — Focally Bug Fixes & Features

## Context
Focally is a macOS menu-bar focus timer app (SwiftUI + AppKit). This spec covers 4 issues.

## Priority Order: Issue 4 → 3 → 2 → 1

---

## Issue 4: Debug DND and Slack (CRITICAL)

### Problem
DND (Do Not Disturb) toggle and Slack status updates may not be working. Need to:
1. Add detailed debug logging to DNDService and SlackService
2. Verify the AppleScript approach for DND is correct for macOS 14+
3. Verify Slack API integration (token, scope, API calls)

### DNDService Changes (`Focally/Services/DNDService.swift`)
- Add comprehensive `os.log` logging (not just `print`):
  - Log when `activateDND()` / `deactivateDND()` is called
  - Log accessibility permission check results
  - Log AppleScript execution (the script being run, stdout, stderr, exit code)
  - Log `AXIsProcessTrustedWithOptions` result
  - Log the `shouldSkipAccessibilityChecksUntilRelaunch` flag
- The current approach uses `key code 101/107` with `{control down, option down, command down}`. This is the macOS shortcut for Focus/DND. On macOS 14+ (Sonoma), this shortcut is set in System Settings > Keyboard > Keyboard Shortcuts > Focus. Verify this is still correct.
- IMPORTANT: The `shouldSkipAccessibilityChecksUntilRelaunch` flag means that if the FIRST accessibility check fails, ALL subsequent checks will fail until relaunch. This is likely the bug — if accessibility is not yet granted on first check, the app gives up. Fix: Don't set `shouldSkipAccessibilityChecksUntilRelaunch = true` on failure. Instead, always re-check accessibility (with prompt: false) each time `activateDND`/`deactivateDND` is called. Only cache the result of `AXIsProcessTrustedWithOptions`.

### SlackService Changes (`Focally/Services/SlackService.swift`)
- Add detailed logging:
  - Log when `setStatus()` is called (with token masked, text, emoji, expiration)
  - Log the full HTTP request URL and headers (mask token)
  - Log the HTTP response status code
  - Log the full response body for debugging
  - Log when `clearStatus()` is called
  - Log when `testConnection()` is called
- In `setStatus()`, also log the HTTP status code from the URLResponse (not just the JSON body)
- Add a `validateToken()` method that calls `auth.test` to verify the token is valid and has the right scopes
- In `testConnection()`, use `auth.test` instead of setting/clearing status (cleaner test)

### Entitlements
- Check if `Focally.entitlements` needs `com.apple.security.automation.apple-events` for AppleScript execution. Currently it's empty. Add it if needed.

---

## Issue 3: Close modal when saving settings

### Problem
Settings modal doesn't auto-close after saving.

### Changes in `OnItFocusApp.swift`
- In `saveSettings()` of `SettingsView`, after saving, dismiss the window.
- Since SettingsView is presented in an NSWindow (not a SwiftUI sheet), we need a different approach:
  - Add a closure `onSave: () -> Void` to `SettingsView`
  - Pass it from `makeSettingsWindow()` in `AppDelegate`
  - When save completes, call `onSave()` which closes the window

### SettingsView Changes
- Add `var onSave: (() -> Void)? = nil` property
- At the end of `saveSettings()`, call `onSave?()`

### AppDelegate Changes
- In `makeSettingsWindow()`, pass an `onSave` closure that closes the settings window:
  ```swift
  let settingsView = SettingsView(onSave: { [weak self] in
      self?.settingsWindow?.close()
  })
  ```

---

## Issue 2: Task selector in ActivityInputView

### Problem
When there are predefined tasks, user should be able to quickly pick one when starting a focus session.

### Changes in `ActivityInputView.swift`
- Load predefined tasks from UserDefaults (same key as SettingsView: `"predefinedTasks"`)
- If there are 2+ predefined tasks, show a `Picker` or horizontal scroll of task chips above the activity text field
- When a task is selected, auto-fill the activity name and emoji
- Pre-select the first task by default

### Implementation
- Add `@State private var predefinedTasks: [PredefinedTask] = []`
- Add `@State private var selectedTaskIndex: Int = 0` (or nil for custom)
- On appear, load tasks from UserDefaults
- If `predefinedTasks.count >= 2`, show a horizontal scrollable list of task chips
- Tapping a chip fills `activity` and `selectedEmoji`
- The task picker should be ABOVE the activity text field

### PredefinedTask struct
- Move or share the `PredefinedTask` struct. Currently it's `private` inside `SettingsView`. Make it a separate file at `Focally/Models/PredefinedTask.swift` or add it to an existing model file, accessible from both `SettingsView` and `ActivityInputView`.

---

## Issue 1: Show version in context menu

### Changes in `OnItFocusApp.swift`
- In `showContextMenu()`, add an "About Focally" menu item before the separator
- Show version: `Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")` or `Bundle.main.version`
- Show build: `Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")`
- Format: `About Focally (v0.4.0, build 3)` or similar
- This should be informational only (no action, or opens a small about dialog)

### project.yml Changes
- Update `MARKETING_VERSION` to `"0.4.0"` (next version)
- Update `CURRENT_PROJECT_VERSION` to `"4"` (next build)

---

## Build Instructions
```bash
cd /Users/openjaime/.openclaw/workspace/projects/focally
xcodegen generate
xcodebuild build -project Focally.xcodeproj -scheme Focally -configuration Debug \
    -destination 'platform=macOS' \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## Key Rules
- NSStatusBar (not MenuBarExtra) — right-click support needed
- Settings is NSWindow manual with NSHostingController
- NSMenuItem.target = self — always
- No external dependencies — only system frameworks
- Tokens in Keychain — never UserDefaults
- Code in English, comments in English
- macOS 14+ minimum
- Use `import os.log` for structured logging, not just `print()`
