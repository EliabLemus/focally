# TASK-048 — Durable, target-date-based focus sessions

## Status

Ready for implementation in branch `feat/durable-sessions` and worktree `/tmp/focally-durable-session`.

## Baseline

- Base commit: `deb986a`
- Stable published release remains `v0.9.6` build `79`.
- Wave 1 is locally integrated and protected by:
  - branch `safety/wave1-validated-20260804-234959`
  - bundle `/Users/openjaime/backups/focally/focally-wave1-validated-20260804-234959.bundle`
- This task must not publish anything.

## Goal

Replace the decrement-only, in-memory countdown with a durable session state machine whose source of truth is an absolute phase target date. Active and paused sessions must survive sleep, crash, quit, and relaunch without losing time or triggering duplicate historical side effects.

## Non-goals

- Do not change metrics record schema or metrics views; TASK-049 handles honest metrics after this task.
- Do not refactor Calendar, Slack, DND, update checking, App Intents, Quick Start, presence precedence, or settings UI.
- Do not add account/cloud/SwiftData/SQLite.
- Do not bump version/build or alter release automation.
- Do not add a restoration prompt UI. Restoration policy is deterministic in this task.

## Audit inputs

Read and use:

- `/tmp/focally-audit-durable-session.md`
- Current Wave 1 implementation and tests.

Correct these weaknesses in the audit proposal:

1. Persist the full sanitized `FocusMode` snapshot, not only `modeID`. The session must preserve name, status, emoji, integration flags, Pomodoro settings, type descriptor, and exact semantics even if the stored mode is edited or deleted during the session.
2. Do not use `replaceItemAt` as the only first-write path; it fails when the destination does not yet exist. Use a correct atomic create/replace path and test first save explicitly.
3. Restoration must be an explicit lifecycle call, not an initializer side effect that can activate real integrations before application startup is ready.
4. Tests must not schedule real timers or write the production session file.
5. Reconciliation must be finite and deterministic across multiple elapsed phases, while suppressing replay of historical sounds and notifications.

## Authorized files

### Create

- `Sources/Focally/Models/PersistedFocusSession.swift`
- `Sources/Focally/Services/SessionPersistenceService.swift`
- `Sources/Focally/Services/FocusTimerTicker.swift`
- `Tests/FocallyTests/SessionPersistenceServiceTests.swift`

### Modify

- `Sources/Focally/Services/FocusTimerService.swift`
- `Sources/Focally/OnItFocusApp.swift`
- `Tests/FocallyTests/FocusTimerServiceTests.swift`
- `tasks/TASK-048-SPEC.md` only to add a truthful `## Result` section after implementation.

### Generated during validation only

- `Focally.xcodeproj/project.pbxproj`

Run `xcodegen generate` for tests, but restore generated project churn before the branch commit. The integrated main branch will regenerate the project once.

## Prohibited files

Do not modify:

- `Tests/FocallyTests/Info.plist`
- `Tests/FocallyTests/FocallyTesting.swift.disabled`
- `.hermes/`
- `Sources/Focally/Models/FocusSessionRecord.swift`
- `Sources/Focally/Services/FocusMetricsService.swift`
- `Sources/Focally/Services/CalendarSlackIntegrationService.swift`
- `Sources/Focally/Services/FocusIntegrationService.swift`
- `Sources/Focally/Services/SlackService.swift`
- `Sources/Focally/Services/DNDService.swift`
- `Sources/Focally/Services/NotificationService.swift`
- `Sources/Focally/Services/SoundPlayerService.swift`
- `Sources/Focally/Models/FocusMode.swift`
- `Sources/Focally/Models/PomodoroState.swift`
- `project.yml`
- release scripts, workflows, version/build files, tags, Homebrew tap, or GitHub Release data.

## Required architecture

### 1. Persisted model

Create `PersistedFocusSession`, `Codable` and `Equatable`, with schema version `1` and at least:

- `schemaVersion`
- `sessionID`
- full sanitized `modeSnapshot: FocusMode`
- `sessionStartedAt`
- `phase: PomodoroState` restricted to `.work`, `.shortBreak`, `.longBreak`
- `phaseStartedAt`
- `phaseTargetEndDate: Date?` for active countdowns
- `phaseDurationSeconds`
- `isPaused`
- `pausedAt: Date?`
- `pausedRemainingSeconds: Int?`
- `currentRound`
- `pomodoroRounds`
- `accumulatedActiveSeconds`
- `accumulatedBreakSeconds`
- `accumulatedPausedSeconds`
- `savedAt`

The three accumulators are persisted now to prevent another active-session schema rewrite in TASK-049. TASK-048 maintains them accurately but does not change `FocusSessionRecord` yet.

Validate snapshots before restoration:

- known schema only;
- valid active phase only;
- positive bounded phase duration;
- valid rounds and current round;
- active snapshot has a target and no paused remainder;
- paused snapshot has paused timestamp/remainder and no active target;
- finite, non-negative accumulator values;
- no nonsensical dates far in the future;
- snapshot/session age no more than 7 days.

Invalid, unknown-version, corrupt, or stale snapshots are cleared and the app starts idle without throwing.

### 2. Persistence service

Define a `@MainActor` protocol, e.g. `FocusSessionPersisting`, with:

- `load() -> PersistedFocusSession?`
- `save(_:)`
- `clear()`

Production implementation:

- default file: `~/.focally/active_session.json`;
- initializer accepts a file URL so tests can use a unique temporary directory;
- JSON uses ISO-8601 dates or another stable explicit strategy, consistently for encode/decode;
- parent directory created if absent;
- first save and replacement are atomic and both work;
- decode/schema/corruption failures clear the bad file best-effort and return nil;
- no crash on read/write errors.

Do not put an in-memory fake in production. Tests may define their own recording/in-memory fake.

### 3. Clock and ticker seams

All session time reads must use an injectable clock/date provider, defaulting to the real current date.

Extract timer scheduling behind a `@MainActor` `FocusTimerTicker` protocol:

- production ticker wraps the repeating one-second Foundation `Timer`;
- test ticker schedules no real timer, tracks running state, and exposes a deterministic `fire()` helper;
- `FocusTimerService` no longer owns an authoritative decrementing timer.

The one-second ticker exists only to refresh observable UI and invoke reconciliation. `remainingSeconds` is derived from persisted phase dates/remainders.

### 4. Source of truth

For an active phase:

```text
remaining = ceil(phaseTargetEndDate - now), clamped to 0...phaseDurationSeconds
```

For a paused phase:

```text
remaining = pausedRemainingSeconds
```

Never use `remainingSeconds -= 1` as truth.

Starting a phase establishes `phaseStartedAt`, `phaseDurationSeconds`, and `phaseTargetEndDate`. Persist only at state transitions and lifecycle boundaries; do not write once per second.

### 5. Pause/resume semantics

Pause:

- reconcile remaining at `now` first;
- store `pausedRemainingSeconds`;
- set `pausedAt = now`;
- clear active target;
- stop ticker;
- deactivate injected focus integration;
- persist.

Resume:

- add `now - pausedAt` to `accumulatedPausedSeconds`;
- establish new target `now + pausedRemainingSeconds`;
- clear paused fields;
- start ticker;
- activate integration only when current phase is work;
- persist.

Time spent paused, including system sleep while already paused, never consumes countdown time.

### 6. Active/break accumulators

Maintain accurate persisted accumulators without changing metrics records yet:

- completed work phase duration adds to `accumulatedActiveSeconds`;
- completed short/long break duration adds to `accumulatedBreakSeconds`;
- completed pause intervals add to `accumulatedPausedSeconds`;
- manual end can derive elapsed portion of the current phase from phase duration minus current remaining and classify it according to phase;
- never double-add a phase during restoration or repeated reconciliation.

### 7. Restoration

`FocusTimerService.init` loads cosmetic `last*` fields only. It must not restore or activate integrations automatically.

Expose an idempotent `restoreSessionIfNeeded()` called explicitly once by `AppDelegate.applicationDidFinishLaunching` before UI environments are constructed.

Restore behavior:

- no snapshot: remain idle;
- paused snapshot: restore fields, do not start ticker, do not activate integration;
- active unexpired work: restore, recompute remaining, start ticker, activate injected integration exactly once;
- active unexpired break: restore, start ticker, ensure focus integration is inactive;
- do not replay historical start/break notifications or sounds;
- preserve the full mode snapshot even if the mode store has changed.

### 8. Expiry and catch-up

A session can cross multiple phases while sleeping or the app is closed. Reconciliation must:

- use each previous target as the logical start of the next phase;
- advance through elapsed phases in a bounded loop (maximum implied by sanitized rounds; hard safety cap required);
- preserve round counting;
- update active/break accumulators exactly once per elapsed phase;
- suppress sounds, user notifications, and Slack break actions for historical intermediate transitions;
- after catch-up, apply only the final current state/integration once;
- if the complete session elapsed, record completion once using the logical terminal date, clear persistence, and become idle;
- never create an infinite loop from corrupt durations.

A live phase transition caused within normal ticker tolerance preserves existing Wave 1 behavior: one appropriate sound/notification/integration transition.

### 9. Sleep/wake and termination

In `AppDelegate`:

- observe `NSWorkspace.willSleepNotification` and call a side-effect-free persistence method;
- observe `NSWorkspace.didWakeNotification` and call idempotent time reconciliation;
- unregister lifecycle observers during termination or teardown;
- replace termination's destructive `resetToIdle()` behavior with a service method such as `prepareForTermination()` that persists the active/paused snapshot, stops the ticker, and deactivates focus integration without recording metrics, clearing state, playing sound, or notifying session-ended;
- preserve the existing explicit cleanup intent for external integration state.

Crash/kill durability comes from state-transition persistence; no per-second writes are required.

### 10. Existing behavior preservation

Keep all Wave 1 guarantees:

- breaks remain active UI sessions;
- final Pomodoro count is correct;
- Pomodoro does not require DND;
- `FocusTimerService` never calls DND directly;
- real DND, Slack, Shortcuts, notifications, sounds, and production persistence are never touched by unit tests;
- natural live transitions still produce their existing effects once;
- manual `endSession` and `resetToIdle` clear durable persistence;
- last-used cosmetic defaults remain backward-compatible.

## Required tests

Implement deterministic tests before or with production code.

### Model and persistence

1. Snapshot Codable round-trip preserves all fields.
2. First atomic disk save succeeds when destination does not exist.
3. Replacing an existing snapshot succeeds.
4. Clear removes snapshot.
5. Corrupt JSON returns nil and is cleared.
6. Unknown schema returns nil and is cleared.
7. Invalid phase/durations/rounds/paused invariants are rejected.
8. Snapshot older than 7 days is rejected.

Use a unique temporary directory and delete it in teardown. No production file access.

### Timer source of truth

9. Start saves an exact work-phase snapshot.
10. Advancing fake clock by five minutes then firing one tick yields 20 minutes remaining in a 25-minute phase; no 300 ticks are required.
11. Wake/reconcile after five minutes yields the same result.
12. No snapshot leaves service idle.

### Pause/resume

13. Work 5 minutes, pause, advance 10 minutes, resume: 20 minutes remain.
14. Paused state survives reconstruction/relaunch and schedules no ticker/integration.
15. Multiple pauses accumulate paused seconds accurately.
16. Sleep while explicitly paused does not consume remaining time.

### Restoration and effects

17. Active work restores with one integration activation, ticker running, no notification or sound replay.
18. Active break restores with ticker running and no integration activation/history replay.
19. Full mode snapshot is restored even if no corresponding mode exists elsewhere.
20. Calling restoration twice is idempotent.

### Expiry/catch-up

21. Expired non-Pomodoro work completes once at logical target and clears snapshot.
22. One elapsed Pomodoro work phase advances to the correct break with round increment.
23. Multiple elapsed work/break phases catch up to the correct current phase/remaining time and do not replay historical effects.
24. A fully elapsed multi-round Pomodoro records completion once, with final round count correct.
25. Repeated reconciliation after completion does nothing.

### Clear/termination

26. Manual end clears snapshot.
27. Reset to idle clears snapshot.
28. Prepare-for-termination preserves snapshot but does not record completion, play sound, or notify end; it stops ticker and deactivates integration once.

### Regression/isolation

29. Existing FocusTimerService tests use in-memory persistence and fake ticker; they never touch `~/.focally/active_session.json`.
30. Existing 64 integrated tests stay green.
31. Full test suite causes no real integration or OS side effects.

## Validation commands

```bash
git diff --check
xcodegen generate
xcodebuild test \
  -project Focally.xcodeproj \
  -scheme Focally \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

After tests:

```bash
git restore Focally.xcodeproj/project.pbxproj
git diff --check
git status --short
```

## Acceptance criteria

- A running 25-minute session shows about 20 minutes after a simulated five-minute sleep or relaunch gap.
- An explicitly paused session loses no countdown time across a longer sleep/relaunch.
- Quit/relaunch restores the session instead of ending and recording it.
- Crash recovery is possible from the last state-transition snapshot.
- Multi-phase Pomodoro catch-up is deterministic, bounded, and free of duplicate historical effects.
- Corrupt, invalid, unknown, and stale snapshots safely fall back to idle.
- No production file/network/OS integration is touched by unit tests.
- Full host test suite passes.
- `git diff --check` passes.
- Only authorized files are changed.
- No version/build/release/push/tag/Homebrew changes occur.

## Result

Implemented the durable target-date session state machine, sanitized full-mode snapshots, atomic JSON persistence, explicit restoration/lifecycle handling, bounded multi-phase catch-up, persisted active/break/paused accumulators, and injected clock/ticker/persistence/defaults/metrics seams. Final-review fixes add a synchronous sleep suspension boundary, historical wake reconciliation, a two-second live-ticker tolerance, and an injectable workspace lifecycle coordinator with deterministic service and observer coverage. `resetToIdle` and `endSession` now capture the injected clock once per call.

Fresh final host validation completed successfully: `xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` executed 98 tests with 0 failures (`** TEST SUCCEEDED **`). `xcodegen generate`, sandbox `build-for-testing`, and `git diff --check` passed; generated `Focally.xcodeproj/project.pbxproj` churn was restored. The CoreSimulator version warning is unrelated to the macOS destination and did not block tests.
