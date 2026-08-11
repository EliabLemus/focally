# TASK-055 — Event-driven Calendar and Slack rate-limit safety

## Status

`completed`

## Harness

```yaml
task_id: TASK-055
driver: openai-codex/gpt-5.6-sol
challenger: zai/glm-5.2
judge: deterministic
base_sha: 38606640603add7f02a6cebf610a2e8a5488a53d
branch: fix/event-driven-calendar-rate-limit
```

## Problem

Calendar currently refetches EventKit every 30 seconds. Slack status and DND writes are transition-driven, but the workspace emoji catalog is refreshed from several UI lifecycle paths, including every menu/dashboard appearance, without cache freshness, in-flight suppression, or `Retry-After` handling.

## Source-grounded facts

- Apple documents `EKEventStoreChangedNotification` as the main-actor notification for Calendar database additions, removals, and modifications; accessed EventKit objects must be refetched after it.
- Slack documents Web API rate limits per method/workspace/app, recommends designing around at most one request per second per API method, and requires honoring HTTP `429 Retry-After`.
- Calendar/EventKit reads are local and do not directly consume Slack API quota.

## Invariants

1. Presence precedence remains `manual focus > Calendar meeting > idle`.
2. Slack status/DND writes occur only for meaningful presence transitions/settings changes/reconnection, never from a Calendar heartbeat.
3. Calendar changes, meeting starts, and meeting ends reconcile without a repeating polling timer.
4. Launch, wake, permission changes, and settings changes remain explicit reconciliation points.
5. Calendar metrics remain honest across long awake meetings and exclude sleep/offline time.
6. Slack `emoji.list` never has duplicate in-flight requests, uses a freshness cache, and honors `Retry-After` without automatic retry storms.
7. Manual Reload may bypass freshness but may not bypass in-flight or server backoff.
8. Tests use no real Slack, network, EventKit database/permission prompts, Keychain, `UserDefaults.standard`, DND, notifications, or installed app.
9. No push, PR, tag, release, publication, or installed-app replacement.

## Acceptance criteria

### AC-01 — Calendar database changes are event-driven
Monitoring registers one idempotent observer for the injected EventKit change notification. A notification causes one immediate reconciliation/refetch. Stopping removes the observer.

### AC-02 — Time transitions use one-shot boundaries
There is no repeating Calendar polling timer. The service schedules only the next relevant non-all-day meeting start/end or day rollover and reschedules after reconciliation.

### AC-03 — Repeated UI appearance is idempotent
Repeated `startIfEnabled()` while already monitoring does not duplicate observers, timers, EventKit fetches, metrics writes, or Slack presence writes.

### AC-04 — Lifecycle and permission behavior remains correct
Launch/enable performs immediate reconciliation; wake performs immediate permission-aware reconciliation; revoked access stops monitoring and clears stale Calendar presence; disable/termination removes timers/observers.

### AC-05 — Calendar metrics remain honest
An event-driven meeting can accumulate more than the old 90-second polling gap while the app remains awake. Sleep/termination suspends observation so elapsed offline/asleep time is not counted on wake/end.

### AC-06 — Slack is not polled
No repeating timer or Calendar reconciliation invokes `auth.test`, `emoji.list`, status, or DND. Slack writes remain transition-driven. App launch may perform one `auth.test` and one deduplicated emoji refresh.

### AC-07 — Emoji catalog refresh is bounded
Normal refresh calls are suppressed while one request is in flight and while the last successful catalog is fresh. A user-forced refresh bypasses freshness only.

### AC-08 — HTTP 429 is honored
`emoji.list` reads the real HTTP status and `Retry-After`; subsequent normal or forced refreshes are suppressed until the injected clock reaches the deadline. No automatic retry is scheduled.

### AC-09 — Errors remain honest
A 429 reports a rate-limit error without clearing a previously valid emoji catalog or marking the token invalid. Other non-success responses use the actual HTTP status.

### AC-10 — Deterministic Judge
Focused tests, full suite, clean Release build, `git diff --check`, scope check, forbidden-side-effect scan, and final Challenger review pass with no blocker/high finding.

## Intended scope

```text
Sources/Focally/Services/CalendarSlackIntegrationService.swift
Sources/Focally/Services/CalendarMetricsTracker.swift
Sources/Focally/Services/SlackService.swift
Sources/Focally/Views/Settings/IntegrationsSettingsView.swift
Tests/FocallyTests/CalendarMetricsTrackerTests.swift
Tests/FocallyTests/SlackOperationStateTests.swift
tasks/TASK-055-SPEC.md
```

UI appearance call sites may remain because service-level freshness/in-flight/backoff guards make them inert. Manual Settings Reload will explicitly request `force: true`.

## Judge

```bash
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' \
  -only-testing:FocallyTests/CalendarMetricsTrackerTests \
  -only-testing:FocallyTests/SlackOperationStateTests

xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS'
xcodebuild clean build -project Focally.xcodeproj -scheme Focally -configuration Release
git diff --check
git status --short
git diff --name-only 3860664...HEAD
```

## Result

```yaml
focused_tests:
  result: pass
  passed: 41
  failed: 0
  skipped: 0
full_suite:
  result: pass
  passed: 202
  failed: 0
  skipped: 0
release_build:
  result: pass
  artifact: /tmp/focally-task055-release/Build/Products/Release/Focally.app
diff_check: pass
scope_check: pass
network_used_by_tests: false
real_eventkit_or_permission_prompt_used_by_tests: false
real_keychain_used_by_changed_tests: false
real_user_defaults_used_by_changed_tests: false
external_actions: none
challenger_final_review:
  result: pass
  findings: []
  ac_coverage: AC-01...AC-10 pass
  first_attempt: timeout_without_verdict
  closeout_attempt: pass
```

Global safety scan note: pre-existing `SlackServiceSingletonTests.swift`, outside the TASK-055 diff, reads/restores `UserDefaults.standard`; neither changed TASK-055 test file does so.
