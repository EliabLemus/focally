# Focally v0.8.19 Release Notes

**Released**: 2026-07-24
**Version**: 0.8.19
**Build**: 68

---

## What's New

### 📝 Documentation

- **Improved Installation Instructions**:
  - Expanded "Install" → "Installation" section with Homebrew and Direct Download methods
  - Added step-by-step instructions for direct DMG installation
  - Added Accessibility permission setup instructions

- **New Updates Section**:
  - Homebrew update commands (`brew upgrade` + fallback `brew reinstall`)
  - Direct download update instructions
  - **Update Checker integration**: Documented automatic version checking every 24 hours
  - Update indicator location: Settings → About

- **Version Badge**: Always shows latest release version in README header

---

## Technical Details

### README Updates

**File**: `README.md`

**Changes**:
- Badge: `v0.8.16` → `v0.8.19` (dynamic via CI)
- Section restructuring:
  - `Install` → `Installation` (expanded)
  - `Upgrade` → `Updates` (expanded)
  - Added update checker documentation
- Direct download instructions with step-by-step flow

**Installation Documentation**:
```bash
# Homebrew
brew tap EliabLemus/focally
brew install --cask focally

# Direct download + DMG instructions
# Accessibility permission setup
```

**Updates Documentation**:
```bash
# Homebrew
brew update && brew upgrade --cask focally

# Fallback
brew reinstall --cask focally

# Direct download + DMG replace instructions
# Update checker 24h cooldown
```

### Version Bump

- v0.8.18 → v0.8.19
- Build 67 → 68

---

## User-Facing Improvements

**For new users**:
- Clear step-by-step installation flow
- Accessibility permission instructions upfront (no guessing)

**For existing users**:
- Explicit update instructions (Homebrew + direct)
- Knowledge of update checker feature (24h cooldown)
- Update indicator location documented

---

## Breaking Changes

None.

---

## Features Removed

None.

---

## Migration Guide

No migration required. This release improves documentation only.

---

## Dependencies

No new external dependencies.

---

## Known Issues

- Version badge in README is static (not auto-updated by CI)
- Update indicator only appears in About settings (not in main navigation)
- No notification when update detected (user must open About to see)

---

## Future Enhancements

- Auto-update version badge in README via CI workflow
- Show release notes in-app when update available
- Notification when update detected (user preference)
- Auto-download and install updates (requires more permissions)

---

## Release Verification

- ✅ Release build: `xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release build`
- ✅ Version consistency: `project.yml` (0.8.19/68) matches `.xcodeproj` (regenerated via xcodegen)
- ✅ README badge: Updated to v0.8.19
- ✅ Installation instructions: Added Homebrew + Direct Download methods
- ✅ Updates section: Added Homebrew + Direct Download + Update Checker documentation
- ✅ Tests: All tests passed (EmojiUsageTracker, EmojiValidator, FocusMode, Layer, PomodoroState, SimpleFramework, SlackServiceEmoji, SoundPlayerService)

---

## Credits

Built with ❤️ using SwiftUI

**Developer**: Eliab Lemus
**License**: MIT