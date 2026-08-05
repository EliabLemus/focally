# TASK-045: v0.9.7 Trust Core Correctness

## Objective
Fix the small, verified correctness failures in the current session flow without redesigning persistence, timers, DND internals, Slack architecture, metrics schemas, or release automation.

## Base
- Repository worktree: `/tmp/focally-trust-core`
- Branch: `fix/trust-core-v097`
- Base commit: `90c68e0`
- Audit input: `/tmp/focally-audit-trust-core.md`

## Safety and scope
- Do not push, tag, release, or modify Homebrew.
- Do not modify files outside the authorized list.
- Do not bump app version/build.
- Do not touch `DNDService.swift`, `FocusIntegrationService.swift`, Calendar, Slack, update checker, README, or release workflow.
- Do not implement durable-session persistence in this task.
- Follow TDD where practical.

## Authorized files
- `Sources/Focally/Views/Timer/TimerPage.swift`
- `Sources/Focally/Services/FocusTimerService.swift`
- `Sources/Focally/Models/FocusMode.swift`
- `Tests/FocallyTests/FocusModeTests.swift`
- Create: `Tests/FocallyTests/FocusTimerServiceTests.swift`
- `tasks/TASK-045-SPEC.md`

`Focally.xcodeproj/project.pbxproj` is generated. You may run `xcodegen generate` locally for tests, but restore this generated file before committing. Final integration will regenerate it once after all lanes merge.

## Required changes

### 1. Keep active UI visible during breaks
In `TimerPage.body`, route to `ActiveFocusView` whenever `timerService.hasSession` is true. `IdleDashboardView` must only render when there is no active work or break session.

Do not modify `ActiveFocusView`; it already handles work, short break, and long break states.

### 2. Count the final Pomodoro
In `FocusTimerService.handlePhaseComplete()`, set `currentRound = completedRounds` before natural terminal completion calls `endSession()`.

A 1-round session records 1 completed Pomodoro. A 4-round session records 4, not 3.

### 3. Make Pomodoro independent of macOS DND
This is an intentional product behavior change, even though the current test encodes the old coupling.

In `FocusMode.sanitized()`, preserve `enablePomodoro` independently of `enableMacOSDND`. A user must be able to use Pomodoro while leaving macOS DND disabled.

Update the existing test name and expectation. Keep all clamping, legacy decoding, Slack DND, mode typing, and Codable behavior unchanged.

### 4. Do not deactivate unrelated system DND
`FocusTimerService.endSession()` currently calls `deactivateFocusIntegration()` and later unconditionally calls `dndService.deactivateDND()` after state cleanup.

Remove the unconditional direct DND teardown. `FocusIntegrationService.deactivateFocus()` already owns integration teardown and respects the active mode. Align natural completion with `resetToIdle()` behavior.

Do not modify DNDService or FocusIntegrationService in this lane.

## Tests

### FocusModeTests
- Rename `testSanitizedModeClampsAndDisablesPomodoroWhenDNDIsOff` to reflect independent behavior.
- For `enableMacOSDND: false` and `enablePomodoro: true`, assert sanitized mode keeps Pomodoro enabled.
- Preserve all clamp assertions.

### FocusTimerServiceTests
Add focused regression coverage without sleeping for real timer durations.

Required behaviors:
1. `hasSession` is true for `.work`, `.shortBreak`, and `.longBreak`; false for `.idle` and `.completed`.
2. A single-round Pomodoro natural completion records one completed Pomodoro.
3. A four-round Pomodoro natural completion records four completed Pomodoros.
4. A non-terminal work completion advances to break with `currentRound == 1`.
5. Round four of an eight-round sequence selects long break.
6. Ending a mode with DND disabled does not directly force system DND off.

You may add the smallest possible `internal` or `#if DEBUG` test seam inside `FocusTimerService` to advance a phase deterministically. Do not expose a public API. Avoid real network calls and do not wait on one-second timers.

If behavior 6 cannot be tested without redesigning dependencies owned by TASK-047, document it explicitly in Result and cover it in the later integration test; still make the minimal source fix here.

## Verification
Run from `/tmp/focally-trust-core`:

```bash
xcodegen generate
xcodebuild test \
  -project Focally.xcodeproj \
  -scheme Focally \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

Then restore generated project churn before commit:

```bash
git restore Focally.xcodeproj/project.pbxproj
```

Run `git status --short` and verify only authorized files remain.

## Acceptance criteria
- Breaks never route to IdleDashboardView.
- Final Pomodoro is counted.
- Pomodoro works without macOS DND.
- End session does not directly disable DND outside FocusIntegrationService ownership.
- Existing and new tests pass.
- No version change, push, tag, release, Homebrew update, or generated-project commit.
- One focused commit: `fix: correct trust-critical focus session behavior`.

## Result
- Status: implemented; pending host test rerun
- Summary: Kept the active timer UI visible through breaks, counted the terminal Pomodoro before metrics recording, decoupled Pomodoro from macOS DND, removed direct DND teardown from `endSession()`, and isolated timer tests from real DND, notification, sound, and focus integrations through minimal injected protocols and inert recording stubs.
- Files modified: `Sources/Focally/Views/Timer/TimerPage.swift`, `Sources/Focally/Services/FocusTimerService.swift`, `Sources/Focally/Models/FocusMode.swift`, `Tests/FocallyTests/FocusModeTests.swift`, `tasks/TASK-045-SPEC.md`
- Files created: `Tests/FocallyTests/FocusTimerServiceTests.swift`
- Tests:
  - `xcodegen generate` — passed; generated project churn restored.
  - Host `xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` — passed: 60 tests, 0 failures.
  - `swiftc -frontend -parse` for the changed service and test files — passed.
  - `git diff --check` — passed.
- Commit: pending review; required message: `fix: correct trust-critical focus session behavior`.
- Notes / deferred items: The unconditional direct DND teardown was removed and integration-owned teardown remains. `FocusTimerServiceTests` verifies `endSession()` calls the integration stub exactly once and the direct DND stub zero times; all timer tests use inert stubs and do not invoke host notifications, DND, Shortcuts, Slack, or sound. No release or publication action occurred.
