# TASK-050 — Honest, crash-safe Calendar metrics

## Status

Ready for implementation in branch `feat/honest-calendar-metrics` and worktree `/tmp/focally-honest-calendar-metrics`.

## Baseline

- Base commit: `e0973a1`
- TASK-048 durable timer sessions and TASK-049 migration-safe honest manual metrics are locally integrated and validated.
- Published release remains `v0.9.6` build `79`.
- This task is local only. Do not push, tag, release, upload assets, update Homebrew, or change version/build.

## Objective

Replace scheduled-duration Calendar metrics with a persistent observation draft that records only time during which Focally actually observed an active video-call event.

Fix both existing defects:

1. detecting a video event currently records its entire scheduled duration immediately;
2. `recordedVideoCallIDs` is in-memory and allows duplicate records after relaunch.

The implementation must be explicit about epistemic limits: EventKit shows an active video-call event, not whether the user actually joined the call. Therefore the metric is **Focally-observed active video-call event time**, not guaranteed call attendance.

## Product semantics

1. Start a metrics draft when Calendar monitoring first observes an active, non-all-day event with `hasVideoCall == true`.
2. Do not create a completed `FocusSessionRecord` at draft start.
3. Accumulate only bounded intervals between consecutive observations while Focally is running.
4. Do not count long gaps caused by sleep, suspension, crash, termination or disabled monitoring.
5. Finalize when the event stops being current, a different event becomes current, Calendar is disabled, or access is lost.
6. Persist every draft update so crash/relaunch does not duplicate or erase observed time.
7. Relaunch during the same event resumes the draft without counting the app-down gap.
8. Completed records use deterministic IDs and upsert semantics.
9. A transient exit/re-entry for the same logical event must accumulate another observed segment without creating a duplicate.
10. Calendar metrics must not depend on `showCalendarInSlack`; Slack visibility and metrics are separate concerns.
11. Non-video and all-day events never create Calendar metrics drafts.
12. Discard completed observations below five seconds.

## Why scheduled duration is prohibited

The following current behavior must be removed:

```swift
startTime: meeting.startTime
endTime: meeting.endTime
duration: meeting.endTime.timeIntervalSince(meeting.startTime)
```

It claims precision Focally does not have. A one-hour event detected for thirty seconds must not become one hour of reported meeting time.

## Authorized files

Production:

- Create: `Sources/Focally/Models/PersistedCalendarMetricsDraft.swift`
- Create: `Sources/Focally/Services/CalendarMetricsTracker.swift`
- Modify: `Sources/Focally/Services/CalendarSlackIntegrationService.swift`
- Modify: `Sources/Focally/Services/FocusMetricsService.swift`
- Modify: `Sources/Focally/OnItFocusApp.swift`

Tests:

- Create: `Tests/FocallyTests/CalendarMetricsTrackerTests.swift`
- Modify: `Tests/FocallyTests/FocusMetricsServiceTests.swift`
- Optional, only if it remains fully isolated: `Tests/FocallyTests/CalendarSlackIntegrationServiceTests.swift`

Spec:

- `tasks/TASK-050-SPEC.md`

## Prohibited scope

Do not modify:

- `FocusSessionRecord` schema or TASK-049 migration behavior;
- `FocusTimerService` or durable manual session behavior;
- Slack status/DND precedence in this task;
- `FocusIntegrationService`;
- EventKit authorization UX;
- Calendar polling interval;
- metrics views;
- version/build/release/CI/Homebrew files;
- protected user files `.hermes/`, `Tests/FocallyTests/Info.plist`, or `Tests/FocallyTests/FocallyTesting.swift.disabled`.

Presence precedence is the next serial task because it edits the same Calendar transition path.

## 1. Persistent draft model

Create `PersistedCalendarMetricsDraft` as a `Codable`, `Equatable` value with at least:

```swift
struct PersistedCalendarMetricsDraft: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var recordID: UUID
    var meetingID: String
    var occurrenceStart: Date
    var scheduledEnd: Date
    var firstObservedAt: Date
    var lastObservedAt: Date
    var accumulatedObservedSeconds: TimeInterval
    var isObservationActive: Bool
    var savedAt: Date
}
```

### Identity

A logical occurrence is identified by:

```text
meetingID + occurrenceStart
```

Do not use `meetingID` alone because recurring events may reuse an identifier.

### Validation

Reject and clear a draft when:

- schema version is unsupported;
- identifiers are empty;
- dates are non-finite or incoherent;
- scheduled end precedes occurrence start;
- first/last observed dates are outside a small tolerance around the occurrence;
- accumulated seconds are negative or non-finite;
- saved time is implausibly in the future;
- draft is older than seven days.

A corrupt or stale draft must never crash launch and must not create a completed metric.

## 2. Persistence seam

Define an `@MainActor` protocol:

```swift
protocol CalendarMetricsDraftPersisting: AnyObject {
    func load() -> PersistedCalendarMetricsDraft?
    func save(_ draft: PersistedCalendarMetricsDraft)
    func clear()
}
```

Implement a UserDefaults-backed production service using:

```text
focally.metrics.calendarDraft
```

Requirements:

- inject `UserDefaults` rather than hardcoding `.standard` in tests;
- encode dates consistently with TASK-049 (`.iso8601`);
- invalid payloads are cleared best-effort;
- tests use a unique suite or an in-memory fake only.

## 3. Metrics recording seam

Define an `@MainActor` protocol used by the tracker:

```swift
protocol CalendarMetricsRecording: AnyObject {
    func upsertSession(_ session: FocusSessionRecord)
    func session(withID id: UUID) -> FocusSessionRecord?
}
```

Make `FocusMetricsService` conform.

Add to `FocusMetricsService`:

```swift
func upsertSession(_ session: FocusSessionRecord)
func session(withID id: UUID) -> FocusSessionRecord?
```

`upsertSession` must:

- replace a record with the same UUID in place;
- otherwise append;
- retain record order when replacing;
- enforce the existing 5,000-record cap;
- save once per mutation.

Do not change `recordSession` semantics for manual focus.

## 4. Deterministic record ID

Generate a stable UUID from the logical occurrence identity (`meetingID + occurrenceStart`). Use a deterministic SHA-256-based mapping or an equivalently stable local algorithm.

Requirements:

- same occurrence always yields the same UUID across process launches;
- different start times for a recurring event yield different UUIDs;
- set valid UUID version/variant bits if constructing from hash bytes;
- never use Swift `Hasher`, whose seed is process-randomized.

## 5. CalendarMetricsTracker

Create an `@MainActor` tracker with injected:

- `CalendarMetricsDraftPersisting`;
- `CalendarMetricsRecording`;
- `now: () -> Date`;
- configurable maximum observation gap for tests, production default 90 seconds.

Suggested public API:

```swift
func observeActiveMeeting(_ meeting: CalendarMeeting)
func observeNoActiveMeeting()
func prepareForTermination()
func finishBecauseMonitoringStopped()
```

The exact names may differ, but lifecycle semantics below are mandatory.

### 5.1 First observation

For an active video-call meeting:

- compute deterministic record ID;
- if no compatible draft exists, start one at `now` with zero accumulated seconds;
- if a completed record with that deterministic ID already exists, seed the new draft with its prior active duration and original start time so later observed segments are additive rather than replacing prior time;
- persist immediately;
- do not write a completed record yet.

### 5.2 Repeated observation

For the same active occurrence:

```text
delta = now - lastObservedAt
```

Add `delta` only when:

- the draft was actively observing;
- `delta >= 0`;
- `delta <= maximumObservationGap`;
- the interval remains bounded by the scheduled occurrence.

If the gap exceeds the maximum, treat it as suspension: add zero and resume observation from `now`.

Persist the updated draft.

### 5.3 Relaunch/crash recovery

A loaded draft is always considered suspended until the current process explicitly observes the same occurrence. This prevents counting app-down time.

On the first matching observation after relaunch:

- add zero for the offline gap;
- mark active;
- set `lastObservedAt = now`;
- keep accumulated observed seconds and first-observed date;
- persist.

If the recovered draft does not match the active occurrence, finalize only its already accumulated seconds, then start the new occurrence if eligible.

### 5.4 Ending or switching meetings

When no meeting is active, a non-video meeting is active, or a different occurrence becomes active:

1. add one final bounded observation delta for the old draft if allowed;
2. finalize the old draft;
3. clear persistence;
4. start a new draft only for an eligible video-call occurrence.

### 5.5 Termination

`prepareForTermination()` must:

- add a final bounded delta;
- mark the draft suspended (`isObservationActive = false`);
- persist it;
- not create a completed record solely because the app is terminating.

This allows a same-meeting relaunch to resume while still excluding the app-down gap.

### 5.6 Monitoring disabled/access lost

`finishBecauseMonitoringStopped()` finalizes the already observed amount and clears the draft. It must not add an unbounded gap.

### 5.7 Final record

When accumulated observed time is at least five seconds, create:

```swift
FocusSessionRecord(
    id: draft.recordID,
    modeType: .calendarVideoCall,
    modeID: FocusModeType.calendarVideoCall.id,
    startTime: draft.firstObservedAt,
    endTime: finalObservedDate,
    duration: accumulatedObservedSeconds,
    activeDuration: accumulatedObservedSeconds,
    pausedDuration: 0,
    breakDuration: 0,
    source: .calendar
)
```

Invariant:

```text
duration == activeDuration
```

Do not use scheduled duration. Do not set manual Pomodoro counts.

## 6. Calendar service wiring

Modify `CalendarSlackIntegrationService` to receive/internally resolve a `CalendarMetricsTracker` dependency.

Remove:

```swift
private var recordedVideoCallIDs: Set<String>
recordVideoCallIfNeeded()
```

Wire the tracker into every transition:

- same current meeting ID: still call repeated observation before returning;
- new eligible meeting: tracker observes it;
- nil/non-video/different meeting: tracker closes or switches correctly;
- `stopMonitoring()`: finalize because monitoring stopped;
- failed/denied access path: finalize because monitoring stopped.

Metrics tracking must be independent of:

```swift
calendarSettings.showCalendarInSlack
```

Do not alter the existing Slack or DND actions beyond inserting tracker calls.

Add an explicit internal `CalendarMeeting` initializer for pure tests if required:

```swift
init(id:title:startTime:endTime:isAllDay:hasVideoCall:)
```

Keep the existing `EKEvent` initializer.

## 7. App lifecycle wiring

In `AppDelegate.applicationWillTerminate`, call Calendar metrics termination preparation before other teardown:

```swift
calendarService.prepareForTermination()
```

Do not finalize scheduled duration. The draft remains recoverable and suspended.

Launch recovery should happen through tracker initialization plus the first Calendar active-meeting check; do not fabricate an active event before EventKit returns one.

## 8. Required tests

All tests must use fake clocks, fake persistence and fake metrics. No EventKit authorization, real Calendar, Slack, DND, timers, network, shared metrics or production UserDefaults.

### Draft/persistence

1. valid draft round-trip;
2. corrupt payload clears safely;
3. future schema rejected;
4. negative/non-finite accumulation rejected;
5. stale draft rejected;
6. recovered active flag is treated as suspended by a new tracker process.

### Identity/upsert

7. deterministic ID stable across tracker instances;
8. recurring occurrence with different start gets a different ID;
9. upsert appends absent record;
10. upsert replaces same UUID without reordering;
11. upsert respects 5,000 cap;
12. `session(withID:)` returns exact record.

### Observation semantics

13. first video observation creates/persists draft and no completed record;
14. repeated 30-second observations accumulate 30 seconds each;
15. gap above 90 seconds adds zero;
16. termination adds final bounded delta, suspends and persists without final record;
17. relaunch same occurrence resumes without counting offline gap;
18. relaunch after occurrence ended finalizes only accumulated observation;
19. no-active transition finalizes exact observed amount;
20. different meeting finalizes old and starts new;
21. non-video meeting creates no draft;
22. all-day event creates no draft;
23. below-five-second observation is discarded;
24. final record uses Calendar source, no Pomodoros, zero pause/break and duration=active;
25. final timestamps use observed dates, not scheduled start/end;
26. transient exit and re-entry of same occurrence accumulates segments into one deterministic record;
27. a completed same-ID record seeds later observation rather than being replaced by only the latest segment;
28. metrics behavior is independent of Slack visibility setting.

### Regression

29. existing TASK-049 v1/v2 migration tests pass;
30. manual focus metrics remain unchanged;
31. Calendar status and DND behavior remain unchanged in this task.

## 9. Acceptance criteria

- No scheduled Calendar duration is recorded.
- No duplicate record is created after relaunch.
- Offline/sleep/crash gaps do not count as observed meeting time.
- Multiple observed segments for one occurrence accumulate into one deterministic record.
- Draft persistence is crash-safe and invalid data is harmless.
- Calendar metrics are independent of Slack visibility.
- All new tests are isolated from external effects and user data.
- Full macOS test suite passes.
- Clean Release build passes after integration.
- `git diff --check` passes.
- No version, release, tag, CI, Homebrew or protected-file changes.

## 10. Validation

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

Restore generated `Focally.xcodeproj/project.pbxproj` churn before branch review.

## 11. Validation result

Fresh host validation after lifecycle-gap, recovered-timestamp, chronology and presence-scope fixes:

```text
git diff --check: passed
xcodegen generate: passed
xcodebuild test: 148 tests, 148 passed, 0 failures
result: ** TEST SUCCEEDED **
log: /tmp/focally-calendar-metrics-tests-host-r4.log
```

Generated `Focally.xcodeproj/project.pbxproj` churn was restored after the host run.

## 12. Review gates

Before commit:

1. strict Codex review of the full tracked/untracked diff;
2. independent GLM read-only review;
3. fix every blocker/high finding;
4. repeat host tests after final changes;
5. commit only authorized files.

Before integration:

1. fetch and verify `origin/main`;
2. merge locally with an explicit merge commit;
3. regenerate the Xcode project from a clean checkout without protected local files;
4. run integrated tests and clean Release build;
5. restore protected local files;
6. create a verified safety branch and bundle;
7. do not push or publish.
