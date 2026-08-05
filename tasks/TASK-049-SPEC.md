# TASK-049 — Migration-safe honest focus metrics

## Status

Ready for implementation in branch `feat/honest-metrics` and worktree `/tmp/focally-honest-metrics`.

## Objective

Make every newly recorded manual focus session report semantically honest time:

- `activeDuration`: actual work/focus seconds;
- `pausedDuration`: time explicitly paused;
- `breakDuration`: Pomodoro short/long break seconds;
- `duration`: backward-compatible aggregate field that equals active focus time for v2 records;
- `source`: manual or calendar.

Preserve all historical v1 records and their existing aggregate values. A schema change must never silently replace the entire metrics history with an empty array.

## Baseline

- Repository: `/Users/openjaime/projects/focally`
- Required branch: `feat/honest-metrics`
- Required worktree: `/tmp/focally-honest-metrics`
- Base commit: `ba61191` (`main` after TASK-048 durable sessions integration and clean project regeneration)
- Published baseline remains `v0.9.6 (79)`
- Do not change version, build, release scripts, tags, Homebrew or CI release configuration.

## Product decisions

1. For a new v2 record, `duration == activeDuration`.
2. Breaks and pauses do not contribute to `totalFocusTime`, mode breakdowns, meeting time or averages for new v2 records.
3. Legacy v1 records keep their historical value: absent `activeDuration` decodes as `duration`, with pause/break defaulting to zero.
4. Calendar records are tagged `.calendar`, but actual calendar-attendance tracking is deferred to the later calendar-draft task.
5. No metrics UI redesign in this task. Existing totals become honest automatically because they aggregate `duration`; new pause/break fields are exposed on aggregate models for later charts/export.
6. No destructive eager rewrite is required. Migration is lazy on decode and v2 on the next save.
7. One malformed record must not make every valid record disappear.

## Current durable-session foundation

TASK-048 already provides persisted and correctly updated accumulators in `FocusTimerService`:

- `accumulatedActiveSeconds`
- `accumulatedBreakSeconds`
- `accumulatedPausedSeconds`

It also already:

- adds completed phase durations exactly once;
- adds partial current-phase duration on manual end/reset;
- preserves accumulators across save/restore;
- closes ongoing pause time before recording;
- records a logical terminal date after historical catch-up;
- injects `FocusTimerMetrics` in unit tests.

Do not introduce a second timer accounting model. Consume these existing accumulators.

## Authorized files

Production:

- `Sources/Focally/Models/FocusSessionRecord.swift`
- `Sources/Focally/Services/FocusTimerService.swift`
- `Sources/Focally/Services/FocusMetricsService.swift`
- `Sources/Focally/Services/CalendarSlackIntegrationService.swift` — source attribution only

Tests:

- `Tests/FocallyTests/FocusSessionRecordMigrationTests.swift` — new
- `Tests/FocallyTests/FocusMetricsServiceTests.swift`
- `Tests/FocallyTests/FocusTimerServiceTests.swift`
- `Tests/FocallyTests/CalendarMetricsSourceTests.swift` — optional new focused test if existing seams permit pure isolation

Spec:

- `tasks/TASK-049-SPEC.md`

## Prohibited files and behavior

Do not modify:

- metrics views;
- Calendar detection/polling or EventKit behavior;
- presence/DND/Slack precedence;
- `FocusMode` or `PomodoroState`;
- version/build files;
- release scripts, GitHub workflows, Homebrew or tags;
- protected user files under `.hermes/`, `Tests/FocallyTests/Info.plist`, or `Tests/FocallyTests/FocallyTesting.swift.disabled`.

Do not use `UserDefaults.standard`, shared metrics, real timers, Slack, DND, sound, notifications, disk or network from new unit tests. The only disk behavior allowed is an explicitly scoped temporary-directory persistence test if one becomes necessary; it should not be necessary here.

## 1. Record schema v2

### 1.1 Source enum

Add a top-level model enum:

```swift
enum FocusSessionSource: String, Codable, Equatable {
    case manual
    case calendar
}
```

### 1.2 Additive fields

Extend `FocusSessionRecord` with:

```swift
let recordVersion: Int
let activeDuration: TimeInterval
let pausedDuration: TimeInterval
let breakDuration: TimeInterval
let source: FocusSessionSource
```

Keep all existing fields and their encoded key names.

### 1.3 Semantics

For v2 manual records:

```text
duration       = activeDuration
activeDuration = work/focus time only
pausedDuration = explicit pause intervals
breakDuration  = Pomodoro break intervals
source         = manual
recordVersion  = 2
```

For v2 calendar records in this task:

```text
duration       = current calendar duration behavior
activeDuration = duration
pausedDuration = 0
breakDuration  = 0
source         = calendar
recordVersion  = 2
```

Calendar actual-attendance semantics are a separate serial task.

### 1.4 Initializer compatibility

Keep existing call sites source-compatible through defaults. The initializer must allow current tests/callers that pass only existing fields, while new timer code passes explicit honest fields.

Suggested shape:

```swift
init(
    id: UUID = UUID(),
    modeType: FocusModeType,
    modeID: UUID,
    startTime: Date,
    endTime: Date,
    duration: TimeInterval,
    pomodorosCompleted: Int? = nil,
    recordVersion: Int = 2,
    activeDuration: TimeInterval? = nil,
    pausedDuration: TimeInterval = 0,
    breakDuration: TimeInterval = 0,
    source: FocusSessionSource = .manual
)
```

For newly initialized v2 records, `activeDuration ?? duration` becomes active truth and `duration` must equal that active truth. Callers must not be able to create a v2 record where aggregate `duration` includes pause or break time.

Reject or normalize non-finite/negative durations consistently. Do not permit NaN or infinity to reach persisted records or aggregate output.

### 1.5 Custom Codable

Replace synthesized decoding with explicit `CodingKeys`, `init(from:)`, and `encode(to:)`.

Migration rules when v2 keys are absent:

```text
recordVersion   = 1
activeDuration  = duration
pausedDuration  = 0
breakDuration   = 0
source           = calendar when modeType == calendarVideoCall, otherwise manual
duration         = exact legacy duration
```

For v2 records:

- decode all v2 fields;
- require finite nonnegative durations;
- require `endTime >= startTime`;
- use `activeDuration` as aggregate truth;
- ensure `duration == activeDuration` after decode;
- preserve `pomodorosCompleted == nil` for non-Pomodoro records.

`encode(to:)` writes all v2 fields for new records.

## 2. Lossy history loading

### 2.1 Inject storage

Refactor `FocusMetricsService` to hold an injected `UserDefaults` instance:

```swift
static let shared = FocusMetricsService(defaults: .standard)

init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    loadRecords()
}
```

Resolve actor-isolated defaults inside the `@MainActor` initializer if necessary. The initializer must be internal for tests; production continues using `shared`.

Replace every direct `UserDefaults.standard` call with the injected instance, including clear/reset helpers.

### 2.2 Preserve valid records around malformed entries

Current all-or-nothing array decoding turns any record decode failure into `records = []`. Replace it with a lossy array decode that:

- decodes each element independently;
- keeps valid records in original order;
- skips malformed records;
- never overwrites the stored raw data merely because loading skipped an entry;
- saves the valid list only after a later explicit record/upsert/clear mutation.

Do not hide a top-level malformed payload by manufacturing records. If the outer payload is not a JSON array, load an empty in-memory list but leave the raw stored value untouched until an explicit mutation.

### 2.3 Remove diagnostic prints

Remove the current `print` calls from `FocusMetricsService.recordSession`; use existing logging only if needed. No new console noise.

## 3. Honest timer recording

Update only `FocusTimerService.recordMetricsOnCompletion(endTime:)` and narrowly related test-visible seams.

At every completion path, TASK-048 has already finalized the current partial phase. Record:

```swift
let active = max(0, accumulatedActiveSeconds)
let paused = max(0, accumulatedPausedSeconds)
let breaks = max(0, accumulatedBreakSeconds)
```

Create:

```swift
FocusSessionRecord(
    modeType: mode.type,
    modeID: mode.id,
    startTime: start,
    endTime: endTime,
    duration: active,
    pomodorosCompleted: mode.enablePomodoro ? currentRound : nil,
    activeDuration: active,
    pausedDuration: paused,
    breakDuration: breaks,
    source: .manual
)
```

Minimum-record threshold is based on active focus time, not wall-clock time. A session with four seconds active and ten minutes paused is not a valid five-second focus session.

Do not recalculate these values from `endTime - startTime`. Do not subtract pauses/breaks a second time.

## 4. Aggregate semantics

### 4.1 Existing totals

Keep existing aggregation code based on `record.duration`. Because v2 `duration == activeDuration`, these existing values become honest for new records while preserving legacy values exactly:

- `totalFocusTime`
- `meetingTime`
- type breakdown durations
- weekly/monthly totals
- averages

### 4.2 Add pause and break aggregates

Add to `DailyMetrics`, `WeeklyMetrics`, and `MonthlyMetrics`:

```swift
let totalPausedTime: TimeInterval
let totalBreakTime: TimeInterval
```

Populate each by summing `pausedDuration` and `breakDuration` over the same filtered record collection used by that aggregate.

Do not change existing view files. No chart or export work in TASK-049.

### 4.3 Legacy behavior

A v1 record contributes:

```text
totalFocusTime += legacy duration
paused += 0
break += 0
```

This preserves history rather than pretending old data has precision that was never captured.

## 5. Calendar boundary

In `CalendarSlackIntegrationService.recordVideoCallIfNeeded()`, add explicit source attribution:

```swift
source: .calendar
```

Do not change:

- meeting start/end timestamps;
- scheduled-duration behavior;
- duplicate-ID behavior;
- lifecycle drafts;
- presence or DND logic.

Those are fixed serially after this task.

## 6. Required tests

### 6.1 Pure migration tests

Use raw inline JSON fixtures encoded with ISO-8601 dates.

1. v1 manual record decodes with version 1, active=duration, pause=0, break=0, manual source.
2. v1 calendar record infers calendar source.
3. v1 missing `pomodorosCompleted` remains nil.
4. v1 duration and all original fields round-trip without semantic change.
5. v2 manual record decodes all fields.
6. v2 calendar record decodes calendar source.
7. v2 encode/decode round-trip preserves all fields.
8. v2 inconsistent duration/active input cannot inflate aggregates.
9. negative duration is rejected/skipped.
10. NaN/infinity cannot be persisted or loaded as valid records.
11. end-before-start is rejected/skipped.
12. unknown future version follows an explicit safe policy documented in the test.

### 6.2 Lossy service loading

With a unique `UserDefaults` suite per test:

1. all valid v1 records load;
2. mixed v1 and v2 records retain order;
3. one malformed element among valid records is skipped without dropping valid siblings;
4. malformed outer payload yields empty in-memory records but leaves raw storage unchanged;
5. `recordSession` after load saves v2 records and respects the 5000-record cap;
6. `clearAllRecords` affects only the injected suite;
7. no test reads or writes production `UserDefaults.standard`.

### 6.3 Timer accounting

Using TASK-048 fake clock, fake ticker, fake persistence, fake integration/effects, unique defaults and recording metrics fake:

1. non-Pomodoro five active minutes records active=300, pause=0, break=0, duration=300;
2. ten-minute pause does not increase duration/active, but paused=600;
3. multiple pauses sum exactly once;
4. ending during a break records completed work as active and partial break separately;
5. full multi-round Pomodoro records all work in active and all breaks in break;
6. restore/relaunch then end preserves active/pause/break accumulators;
7. historical multi-phase catch-up records correct components;
8. session below five active seconds is discarded even if wall-clock elapsed is long;
9. timer sessions always record manual source;
10. `duration == activeDuration` for every timer-created v2 record.

### 6.4 Aggregate compatibility

1. v1-only daily/weekly/monthly fixtures produce the exact pre-change totals.
2. v2 work=1500, pause=600, break=300 produces totalFocusTime=1500, totalPausedTime=600, totalBreakTime=300.
3. mode breakdown uses 1500, not 2400.
4. mixed v1/v2 aggregates preserve the v1 value and use honest v2 active time.
5. weekday/day-of-month filters apply pause/break sums to the same filtered records.
6. Pomodoro count behavior remains unchanged.
7. calendar source attribution does not affect existing calendar duration breakdown.

## 7. Acceptance criteria

- Existing v1 history decodes with exact prior aggregate values.
- No schema migration can turn all valid history into `[]` because one sibling record is malformed.
- Every new timer record has version 2, manual source and `duration == activeDuration`.
- Pauses never count as focus time.
- Pomodoro breaks never count as focus time.
- Pause and break totals remain separately available in daily, weekly and monthly aggregates.
- Calendar records are tagged calendar without changing Calendar runtime behavior.
- Tests use injected storage and fakes only.
- Full macOS test suite passes.
- Clean Release configuration build passes after integration.
- `git diff --check` passes.
- No version, release, CI, tag, Homebrew or protected-user-file changes.

## 8. Validation commands

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

Restore generated `Focally.xcodeproj/project.pbxproj` churn before branch review. The integrated branch may regenerate and commit the project once after sequential merge.

## 9. Validation result

Fresh host validation after implementation and test-gap closure:

```text
git diff --check: passed
xcodegen generate: passed
xcodebuild test: 126 tests, 126 passed, 0 failures
result: ** TEST SUCCEEDED **
log: /tmp/focally-honest-metrics-tests-host-r3.log
```

Generated `Focally.xcodeproj/project.pbxproj` churn was restored after the host run.

## 10. Review gates

Before commit:

1. Codex strict technical review of the complete diff.
2. Independent GLM read-only compliance review.
3. Fix every BLOCKER/HIGH finding.
4. Repeat host tests after the final fix.
5. Commit only authorized files and the spec.

Before integration:

1. `git fetch origin`;
2. verify `origin/main` did not move unexpectedly;
3. sync local `main` without dropping protected user changes;
4. merge the feature branch locally with an explicit merge commit;
5. regenerate Xcode project if needed;
6. run integrated tests and clean Release build;
7. do not push or publish.
