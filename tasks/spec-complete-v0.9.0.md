# Task Spec: Complete Multi-language Implementation (v0.9.0)

**Context**: Subagent completed ~70% of v0.9.0 multi-language support. Build currently fails due to missing `LanguageSettingsView.swift`.

**What's Done**:
- ✅ Phase 1: Setup (resource folders, project.yml v0.9.0/build 69)
- ✅ Phase 2: AppLanguage.swift service with auto-detection
- ✅ Phase 3+4: ~110 keys in en/es/pt Localizable.strings
- ✅ 10 View files localized (FocusSetupView, SidebarView, etc.)

**What's Needed**:
- ❌ Phase 5: Create `LanguageSettingsView.swift`
- ❌ Phase 6: Complete strings extraction in remaining files
- ❌ Fix interpolated localization keys (dynamic vs format strings)
- ❌ Fix ThemeChoice hardcoded labels
- ❌ Build verification + tests

**Current Build Status**: FAILED (missing LanguageSettingsView)

---

## Instructions

1. **Create LanguageSettingsView.swift**:
   - Location: `Focally/Views/Settings/LanguageSettingsView.swift`
   - UI: List of 3 languages (EN/ES/PT) with checkmark for current
   - On tap: call `AppLanguage.shared.setLanguage(code)`
   - Pattern: Follow settings view patterns (VStack, rounded rectangles, proper styling)

2. **Complete strings extraction**:
   - `IntegrationsSettingsView.swift` — remaining strings (DND automation, buttons, emoji catalog)
   - `GeneralSettingsView.swift` — all labels
   - `AboutSettingsView.swift` — version/build/developed/copyright
   - `AppearanceSettingsView.swift` — title + theme labels
   - `MenuBarDropdownView.swift` — header, Quick Start, Add Mode, status labels

3. **Fix interpolated keys**:
   - WRONG: `Text(String(localized: "focus_break_next_\(timerService.shortBreakDurationMinutes)"))`
   - RIGHT: Use format strings in .strings files: `"focus_break_next" = "Next: %d min";`
   - Use `Text(String(format: String(localized: "focus_break_next"), timerService.shortBreakDurationMinutes))`

4. **Fix ThemeChoice hardcoded labels**:
   - Add `localizedLabel` computed property (similar to FocallyTab)
   - Update all ThemeChoice.label references to ThemeChoice.localizedLabel

5. **Build verification**:
   - Run: `xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release build`
   - Fix any errors until BUILD SUCCEEDED

6. **Test verification**:
   - Run: `xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS'`
   - Ensure TEST SUCCEEDED

---

## Key Patterns

- Use `@Environment(AppLanguage.self)` in LanguageSettingsView
- Use `Text("key", comment: "context")` for localization
- Fix interpolated keys with String(format:)
- Follow AGENTS.md patterns

---

## Success Criteria

- BUILD SUCCEEDED
- TEST SUCCEEDED
- No missing LanguageSettingsView errors
- All 5 remaining files fully localized
- Interpolated keys fixed
- ThemeChoice uses localized labels

---

## Notes

- Read subagent summary: `~/.hermes/cache/delegation/subagent-summary-0-20260724_095938_749970.txt`
- Check modified files list before editing
- Report progress after each step
- Stop if build fails after fix attempts

---

## Deliverable

Working implementation with BUILD SUCCEEDED + TEST SUCCEEDED.