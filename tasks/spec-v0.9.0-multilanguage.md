# Task Spec: Multi-language Support (v0.9.0)

**Context**: Focally macOS focus timer app with 8,853 lines of Swift code. Currently English-only.
**Goal**: Add EN/ES/PT support with auto-detection and manual override.
**Spec**: `docs/product-specs/v0.9.0-multilanguage.md`
**Plan**: `docs/exec-plans/active/v0.9.0-multilanguage.md`

---

## Instructions for Codex

1. **Read spec first**: `docs/product-specs/v0.9.0-multilanguage.md`
2. **Follow plan**: `docs/exec-plans/active/v0.9.0-multilanguage.md` (6 phases)
3. **Update version**: `project.yml` → v0.9.0, build 69
4. **Run xcodegen**: After project.yml changes
5. **Build verification**: After each phase, run release build
6. **Test verification**: After Phase 6, run all tests
7. **No README updates**: Focus on implementation only (README will be updated later)

---

## Key Patterns (AGENTS.md)

- Use `@Observable` for state management (AppLanguage)
- Use UserDefaults with prefix `focally.language`
- Use `String(localized:)` with `comment` parameter for context
- Follow SwiftUI environment injection pattern
- Test build after each file modification

---

## Files to Create

- `Focally/Resources/en.lproj/Localizable.strings` (English)
- `Focally/Resources/es.lproj/Localizable.strings` (Spanish)
- `Focally/Resources/pt.lproj/Localizable.strings` (Portuguese)
- `Focally/Models/AppLanguage.swift` (language service)
- `Focally/Views/Settings/LanguageSettingsView.swift` (language selection UI)

---

## Files to Modify

- `Focally/project.yml` (add resource folders, v0.9.0/build 69)
- `Focally/OnItFocusApp.swift` (inject locale environment)
- `Focally/Views/Settings/SettingsPage.swift` (add Language subpage)
- All View files with hardcoded strings (~15 files):
  - `FocusSetupView.swift`
  - `IntegrationsSettingsView.swift`
  - `GeneralSettingsView.swift`
  - `AboutSettingsView.swift`
  - `TimerPage.swift`
  - `SidebarView.swift`
  - `FocusModeEditSheet.swift`
  - `AppSettingsSheet.swift`
  - `MainWindow.swift`

---

## Translation Samples

English (base):
```
"setup_title" = "Focally";
"timer_mode_focus_time" = "Focus Time";
"settings_language" = "Language";
```

Spanish:
```
"setup_title" = "Focally";
"timer_mode_focus_time" = "Tiempo de Enfoque";
"settings_language" = "Idioma";
```

Portuguese:
```
"setup_title" = "Focally";
"timer_mode_focus_time" = "Tempo de Foco";
"settings_language" = "Idioma";
```

See spec for complete translations.

---

## Verification

- Build: `xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release build`
- Tests: `xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS'`
- Manual: Test language switching + persistence

---

## Success Criteria

- 100% of user-facing strings localized
- Auto-detection works in <100ms
- Language switching updates UI in <50ms
- All tests pass
- No performance regression

---

## Notes

- This is a 6-10h implementation
- Follow the plan sequentially (Phase 1 → 6)
- Report progress after each phase
- Stop if build fails or tests fail
- Do NOT create PR or push (just implement locally)

---

## Deliverable

Working implementation in local working directory. No deployment.