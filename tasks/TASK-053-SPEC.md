# TASK-053 — Per-session Quick Start draft

## Status

`done`

## Challenger pre-mortem and Driver synthesis

- Challenger run: `deleg_9017200c` (`zai/glm-5.2`).
- Outcome: timed out after 600 seconds and 12 tool calls without a verdict or structured findings. The timeout is **not** a PASS.
- Transcript evidence: the Challenger read the spec and relevant files, then investigated localization and `NSPopover`/sheet hosting but did not produce a synthesis.
- Driver decision: do not retry the same broad prompt. Continue with the frozen contract and explicitly cover the two material risks confirmed by repository inspection:
  1. do not add nested interactive controls inside the existing card/row `Button`; refactor the composition so default start, Quick Start, and edit controls have independent hit targets and accessibility actions;
  2. resolve Pomodoro overrides into both `durationMinutes` and `pomodoroWorkMinutes`, because `FocusTimerService` and `PresenceCoordinator` consume different duration fields.
- Additional Judge coverage: verify the exact persisted resolved snapshot and assert base-mode value equality before/after resolution and start.

## Harness assignment

```yaml
experiment_id: HARNESS-001
task_id: TASK-053
scope_class: non-trivial
driver:
  provider: openai-codex
  model: gpt-5.6-sol
challenger:
  provider: zai
  model: glm-5.2
judge:
  type: deterministic
```

The assignment is locked by the Human Owner. Do not swap models.

## Goal

Let a user start any focus mode with an optional per-session activity and duration override without editing or persisting changes to the saved mode.

## Current behavior

- Normal mode-card and menu-bar clicks call `FocusTimerService.startSession(mode:)` immediately.
- The active activity is always the mode name.
- Duration always comes from the saved mode; Pomodoro work duration comes from `pomodoroWorkMinutes`.
- Changing either value currently requires editing the saved mode.

## Required behavior

### Session draft

Create a value model `FocusSessionDraft` initialized from a base `FocusMode`.

- It carries the immutable base mode plus editable `activity` and `durationMinutes` values.
- Empty/whitespace activity resolves to the sanitized base-mode name.
- Non-empty activity is trimmed and becomes the session snapshot name.
- Duration resolves to the same supported work range as a mode: `5...120` minutes.
- Resolving a draft creates a new session-only `FocusMode` snapshot and never mutates the base mode or `FocusModeStore`.
- Preserve the mode ID, emoji, status text, DND settings, type descriptor, break settings, Pomodoro rounds and all unrelated properties.
- For non-Pomodoro modes, the resolved `durationMinutes` controls the work phase.
- For Pomodoro modes, the resolved duration controls the session's work phase by updating both `durationMinutes` and `pomodoroWorkMinutes` on the session snapshot; break durations and round count remain unchanged.

### Timer API

Add `FocusTimerService.startSession(draft:)` as the single Quick Start entry point. It resolves the draft and then uses the existing sanitized session-start path.

- Existing `startSession(mode:)` behavior remains unchanged.
- The resolved activity, duration and mode snapshot survive persistence/restoration through the existing durable-session snapshot.
- All existing integrations, metrics and lifecycle behavior keep using the resolved session snapshot.

### Main-window UX

- A normal click on a focus-mode card still starts immediately with saved defaults.
- A clearly discoverable secondary control on each card opens Quick Start for that mode.
- The sheet contains:
  - selected mode identity;
  - optional “What are you working on?” text field;
  - duration control constrained to `5...120` minutes;
  - Cancel and Start Session actions.
- Start Session starts the draft and dismisses the sheet.
- Cancel dismisses without starting or persisting anything.

### Menu-bar UX

- A normal row click still starts immediately with defaults.
- A compact secondary control opens the same Quick Start sheet for that mode.
- Starting from the popover uses the same draft model and timer API as the main window.

### Localization and accessibility

- Add every new user-visible string in English, Spanish and Portuguese.
- New controls have localized accessibility labels/tooltips where applicable.
- Do not introduce hard-coded English user-facing copy.

## Non-goals

- No App Intents or Shortcuts changes.
- No global hotkey.
- No mode editing or `FocusModeStore` persistence changes.
- No status-text, emoji, DND, Pomodoro-break, or round customization in Quick Start.
- No update to release version/build, README, backlog, branding, icons, or release automation.
- No push, PR, tag, release or publication.

## Safety invariants

- Tests must use isolated `UserDefaults` and inert timer/integration dependencies.
- Tests must not contact Slack, read/write Keychain, run Shortcuts, toggle system DND, post notifications, play sound, or mutate `UserDefaults.standard`/emoji history.
- Existing `.hermes/`, `build/`, disabled test artifacts and local Info.plist artifacts remain untouched.

## Authorized files

- `Sources/Focally/Models/FocusSessionDraft.swift` (new)
- `Sources/Focally/Services/FocusTimerService.swift`
- `Sources/Focally/Views/Timer/QuickStartSheet.swift` (new)
- `Sources/Focally/Views/Timer/FocusModeCard.swift`
- `Sources/Focally/Views/Timer/IdleDashboardView.swift`
- `Sources/Focally/Views/MenuBar/MenuBarDropdownView.swift`
- `Sources/Focally/Resources/en.lproj/Localizable.strings`
- `Sources/Focally/Resources/es.lproj/Localizable.strings`
- `Sources/Focally/Resources/pt.lproj/Localizable.strings`
- `Tests/FocallyTests/FocusSessionDraftTests.swift` (new)
- `Tests/FocallyTests/FocusTimerServiceTests.swift` only if direct timer-entry coverage is needed
- `tasks/TASK-053-SPEC.md`

`Focally.xcodeproj/project.pbxproj` may be regenerated only for local verification, restored before the feature commit, and regenerated later in a separate integration commit.

## TDD slices

1. Draft resolution: activity fallback/trim, duration clamp, full property preservation, base mode unchanged.
2. Pomodoro override: resolved work duration changes while break durations/round count remain unchanged.
3. Timer entry point: `startSession(draft:)` starts and persists the exact resolved session snapshot with inert dependencies.
4. UI wiring and localization after model/service behavior is GREEN.

Production behavior changes require a failing focused test first. Record RED and GREEN honestly.

## Acceptance criteria

- AC-01: Normal clicks still start saved defaults immediately.
- AC-02: Secondary controls in both main window and menu bar open Quick Start.
- AC-03: Blank activity falls back to the base mode name; non-blank activity is trimmed and used only for the session.
- AC-04: Duration is constrained to `5...120` and controls the work phase for both standard and Pomodoro modes.
- AC-05: Quick Start never mutates or persists the saved base mode.
- AC-06: The resolved session snapshot preserves all unrelated mode properties and survives the existing persistence path.
- AC-07: Cancel has no side effect; Start uses `FocusTimerService.startSession(draft:)` and dismisses.
- AC-08: New UI copy and accessibility text are localized in EN/ES/PT.
- AC-09: Focused tests, full suite, clean Release build and scope checks pass without forbidden side effects.

## Judge commands

Focused RED/GREEN:

```bash
xcodegen generate
xcodebuild test -quiet \
  -project Focally.xcodeproj \
  -scheme Focally \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/focally-task053-focused \
  -only-testing:FocallyTests/FocusSessionDraftTests
```

Final gates:

```bash
xcodebuild test -quiet \
  -project Focally.xcodeproj \
  -scheme Focally \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/focally-task053-full

xcodebuild clean build -quiet \
  -project Focally.xcodeproj \
  -scheme Focally \
  -configuration Release \
  -derivedDataPath /tmp/focally-task053-release

git diff --check
git status --short
git diff --name-only 79f65f9...HEAD
```

Before local integration, produce a visual preview for Human Owner review because this task changes visible UI.

## Challenger output contract

```yaml
verdict: PASS | BLOCK
findings:
  - severity: blocker | high | medium | low
    file: exact/path
    line: 0
    evidence: concrete risk or observed behavior
    violated_criterion: AC-XX
    minimal_fix: smallest adequate correction
missing_tests: []
unverified_assumptions: []
```

## Result

- Implementation status: complete and integrated into local `main` after explicit Human Owner visual approval.
- Driver: `openai-codex/gpt-5.6-sol`; Challenger: `zai/glm-5.2`; Judge: deterministic host gates.
- TDD evidence:
  - Slice 1 RED: `FocusSessionDraftTests` exited 65 because `FocusSessionDraft` did not exist.
  - Slice 1 GREEN: draft resolution tests exited 0.
  - Slice 2 RED: timer test exited 65 because `startSession(draft:)` did not exist.
  - Slice 2 GREEN: model and timer-entry tests exited 0.
  - Review follow-up RED: custom Pomodoro mode initialized Quick Start from `durationMinutes=90` instead of effective `pomodoroWorkMinutes=25`; the focused test exited 65.
  - Review follow-up GREEN: corrected focused model/timer tests exited 0.
- Final Judge evidence:
  - focused tests: PASS;
  - full suite: 185 passed, 0 failed, 0 skipped;
  - clean Release build: PASS;
  - `git diff --check`: PASS;
  - EN/ES/PT `quick_start_*` key parity: PASS (9 keys each);
  - forbidden side-effect scan in the new focused tests: no matches.
- Challenger evidence:
  - pre-mortem `deleg_9017200c`: timeout without verdict; not counted as approval;
  - first final review `deleg_393cff38`: API timeout without structured verdict; not counted as approval;
  - bounded blocker-only final review `deleg_25ddf1bd`: `PASS`, zero blocker/high findings.
- Visual evidence: representative preview rendered from the implemented layout and Focally color assets at `/tmp/focally-task053-preview.png`; no clipping or overlap observed. The Human Owner approved it before local integration.
- Local integration: feature merge `fa215f5`; generated-project merge `ca66587`.
- Publication: no push, PR, tag, release, version bump, or external action.
