# Focally v0.8.18 Release Notes

**Released**: 2026-07-24
**Version**: 0.8.18
**Build**: 67

---

## What's New

### 🐛 Bug Fixes

- **Short Break DND Restoration**: DND now properly deactivates during short breaks
  - Fixed: Added `deactivateFocusIntegration()` call in `startShortBreak()`
  - Previously, DND remained active during short breaks (only deactivated during long breaks)
  - Matches existing `startLongBreak()` behavior

### ✨ New Features

- **Auto Update Checker**: Background version checking with 24h cooldown
  - Checks GitHub Releases API (`EliabLemus/focally/releases/latest`)
  - Shows "Update available" indicator in About settings when new version detected
  - Caches results to avoid excessive API calls
  - Click to open download page for latest release
  - Proper SemVer comparison (e.g., `0.8.9` < `0.8.10`, `0.9.0` < `0.10.0`)

---

## Technical Details

### Update Checker Service

**File**: `Focally/Services/UpdateCheckerService.swift`

- Singleton `@MainActor @Observable` service
- GitHub API endpoint: `https://api.github.com/repos/EliabLemus/focally/releases/latest`
- UserDefaults keys: `focally.updateChecker.*` (prefixed per AGENTS.md conventions)
- Logger category: `Logger.update`
- Network error handling with graceful degradation

**Version comparison**:
- Parses version strings to `[Int]` arrays
- Compares component-by-component: `[0, 8, 15]` vs `[0, 8, 16]`
- Handles variable length (e.g., `0.8` vs `0.8.15`)

### Design System Compliance

- Uses `Color.focallyPrimary` for update indicator
- Uses `.font(.focallyCaption)` for version text
- System icon: `exclamationmark.triangle.fill`

---

## Setup Instructions

No setup required. Update checker runs automatically on app launch with 24h cooldown.

---

## Breaking Changes

None.

---

## Features Removed

None.

---

## Migration Guide

No migration required. Update checker is opt-in (background check on launch).

---

## Dependencies

No new external dependencies.

---

## Known Issues

- Update indicator only appears in About settings (not in main navigation)
- No notification when update detected (user must open About to see)
- Network errors logged but not surfaced to UI

---

## Future Enhancements

- Add "Check for updates" button in settings for manual refresh
- Show release notes in-app when update available
- Notification when update detected (user preference)
- Auto-download and install updates (requires more permissions)

---

## Release Verification

- ✅ Release build: `xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release build`
- ✅ Version consistency: `project.yml` (0.8.18/67) matches `.xcodeproj` (regenerated via xcodegen)
- ✅ SemVer comparison: Tested edge cases (0.8.9 < 0.8.10, 0.9.0 < 0.10.0)
- ✅ GitHub API: Verified endpoint returns JSON with `tag_name` and `html_url`
- ✅ UserDefaults caching: Keys prefixed with `focally.updateChecker.`
- ✅ Tests: All tests passed (EmojiUsageTracker, EmojiValidator, FocusMode, Layer, PomodoroState, SimpleFramework, SlackServiceEmoji, SoundPlayerService)

---

## Credits

Built with ❤️ using SwiftUI

**Developer**: Eliab Lemus
**License**: MIT