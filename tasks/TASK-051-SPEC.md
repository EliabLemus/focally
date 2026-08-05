# TASK-051 — Presence Coordinator precedence policy

## Status

Ready for implementation in branch `feat/presence-coordinator` and worktree `/tmp/focally-presence-coordinator`.

## Baseline

- Base commit: `63f87d8`
- TASK-048 durable sessions, TASK-049 honest manual metrics, and TASK-050 honest calendar metrics are locally integrated and validated on `main`.
- Published release remains `v0.9.6` build `79`.
- This task is local only. Do not push, tag, release, upload assets, update Homebrew, or change version/build.

## Objective

Centralize Slack status, macOS DND, and Slack DND precedence behind a single testable coordinator.

Required policy:

```text
manual focus > calendar meeting > idle
```

The current app splits presence writes between `FocusIntegrationService` and `CalendarSlackIntegrationService`, with precedence enforced by scattered guards and a notification bounce. That is fragile and already leaves a real DND restoration bug when a calendar meeting owns DND, the user starts a manual focus mode that does not request DND, and then focus ends while the meeting is still active.

This task must replace that ad hoc behavior with one source of truth that:

1. never lets Calendar overwrite a manual focus presence;
2. restores Calendar presence immediately when manual focus ends and a meeting is still active;
3. correctly restores or clears DND based on the active source after every promotion/demotion;
4. removes the need for `focallyFocusChannelDidChange` notification-based recovery.

## Product semantics

1. Manual focus start promotes presence to manual focus immediately.
2. Manual focus end demotes to active Calendar meeting if one is still active; otherwise to idle.
3. Calendar meeting start promotes to Calendar presence only when no manual focus is active.
4. Calendar meeting end demotes to idle only when Calendar currently owns presence.
5. While manual focus is active, Calendar meetings may update the remembered meeting candidate but must not write Slack/DND state.
6. If manual focus ends during an active Calendar meeting, Slack status and DND must switch directly to the correct Calendar state in the same transition, without depending on a later timer tick.
7. Source ownership matters:
   - only deactivate macOS DND if the coordinator previously activated it;
   - only disable Slack DND if the coordinator previously activated it.
8. Calendar visibility to Slack remains gated by existing Calendar settings.
9. Calendar DND remains gated by existing Calendar settings and `meeting.hasVideoCall`.
10. Manual focus DND remains gated by the chosen `FocusMode`.
11. Manual focus Slack status text/emoji semantics remain unchanged.
12. This task must not change metrics semantics or timer durability.

## Authorized files

Production:

- Create: `Sources/Focally/Services/PresenceCoordinator.swift`
- Modify: `Sources/Focally/Services/FocusIntegrationService.swift`
- Modify: `Sources/Focally/Services/CalendarSlackIntegrationService.swift`
- Modify: `Sources/Focally/OnItFocusApp.swift`

Tests:

- Create: `Tests/FocallyTests/PresenceCoordinatorTests.swift`
- Optional: modify `Tests/FocallyTests/CalendarSlackIntegrationServiceTests.swift` only if needed and kept fully isolated
- Optional: modify `Tests/FocallyTests/FocusIntegrationServiceTests.swift` only if needed and kept fully isolated

Spec:

- `tasks/TASK-051-SPEC.md`

## Prohibited scope

Do not modify:

- `Sources/Focally/Models/FocusSessionRecord.swift`
- `Sources/Focally/Services/FocusMetricsService.swift`
- `Sources/Focally/Services/CalendarMetricsTracker.swift`
- `Sources/Focally/Services/FocusTimerService.swift`
- metrics views, Charts, CSV export, App Intents, Quick Start, release pipeline, CI, Homebrew, version/build
- protected user files `.hermes/`, `Tests/FocallyTests/Info.plist`, or `Tests/FocallyTests/FocallyTesting.swift.disabled`

Do not keep unrelated churn in `Focally.xcodeproj/project.pbxproj`; regenerate only for verification inside the worktree and restore it before the feature commit.

## 1. New coordinator

Create `Sources/Focally/Services/PresenceCoordinator.swift` with:

```swift
enum PresenceState: Equatable {
    case idle
    case calendarMeeting(CalendarMeeting)
    case manualFocus(FocusMode)
}

@MainActor
protocol PresenceCoordinating: AnyObject {
    var currentPresence: PresenceState { get }
    var isManualFocusActive: Bool { get }
    var currentCalendarMeeting: CalendarMeeting? { get }

    func manualFocusStarted(mode: FocusMode)
    func manualFocusEnded()
    func calendarMeetingUpdated(_ meeting: CalendarMeeting?)
}
```

Implementation requirements for `DefaultPresenceCoordinator`:

- inject `SlackService` and `DNDService`;
- store the currently remembered manual mode and currently remembered meeting;
- maintain ownership flags for system DND and Slack DND so demotion is correct;
- expose read-only state for tests;
- be fully `@MainActor`;
- apply presence immediately within each public API call.

## 2. Transition policy

Required transition table:

| Event | Current state | Required result |
|---|---|---|
| manual focus start | idle | manual focus |
| manual focus start | calendar meeting | manual focus |
| manual focus start | manual focus | replace with new manual mode |
| manual focus end | manual focus + active remembered meeting | calendar meeting |
| manual focus end | manual focus + no remembered meeting | idle |
| calendar meeting update with active meeting | idle | calendar meeting |
| calendar meeting update with active meeting | manual focus | remain manual focus; remember meeting |
| calendar meeting update with active meeting | calendar meeting | update current meeting payload |
| calendar meeting update nil | calendar meeting | idle |
| calendar meeting update nil | manual focus | remain manual focus; forget meeting |
| calendar meeting update nil | idle | idle |

Two non-negotiable behaviors:

1. Calendar must never call Slack/DND writers while manual focus owns presence.
2. Manual focus end must synchronously restore Calendar presence if a meeting is still remembered.

## 3. Side-effect application rules

### 3.1 Idle

When applying `.idle`:

- clear Slack status;
- deactivate macOS DND only if the coordinator previously activated it;
- disable Slack DND only if the coordinator previously activated it.

### 3.2 Calendar meeting

When applying `.calendarMeeting(meeting)`:

- if `showCalendarInSlack == true`, publish the same meeting status text/emoji logic currently used by `CalendarSlackIntegrationService`;
- if `showCalendarInSlack == false`, clear Slack status;
- activate macOS DND only when Calendar settings allow it and `meeting.hasVideoCall == true`;
- otherwise deactivate only the DND the coordinator itself turned on;
- activate Slack DND only when Calendar settings allow it and `meeting.hasVideoCall == true`, using remaining meeting minutes as today;
- otherwise disable only the Slack DND the coordinator itself turned on.

### 3.3 Manual focus

When applying `.manualFocus(mode)`:

- publish the same focus Slack status text/emoji/expiration semantics currently used by `FocusIntegrationService`;
- activate macOS DND only if `mode.enableMacOSDND == true`;
- otherwise, if Calendar previously owned DND for an active meeting, clear that DND because manual focus takes precedence;
- activate Slack DND only if `mode.enableSlackDND == true`;
- otherwise disable only the Slack DND previously turned on by the coordinator.

The implementation must preserve today’s focus status wording and expiration behavior.

## 4. Refactor FocusIntegrationService

Refactor `FocusIntegrationService` to delegate presence mutations to the coordinator.

Requirements:

- inject `PresenceCoordinating` and `SlackService`/`DNDService` only where still genuinely needed;
- remove direct presence-writing responsibility from focus start/end;
- remove `isFocusModeActive` as owned mutable truth; replace callers with coordinator-backed truth if still needed;
- keep shortcut backup behavior unchanged;
- keep `runSlackTest` behavior unchanged for now;
- keep App Intent entry points working.

Preferred shape:

- `activateFocus(for:)` → set local mode bookkeeping if still needed, then call `presenceCoordinator.manualFocusStarted(mode:)`;
- `deactivateFocus()` → call `presenceCoordinator.manualFocusEnded()`;
- any `isFocusModeActive` public read should be derived from `presenceCoordinator.isManualFocusActive`.

## 5. Refactor CalendarSlackIntegrationService

Refactor `CalendarSlackIntegrationService` so it no longer owns precedence logic.

Requirements:

- inject `PresenceCoordinating`;
- remove `focusChannelObserver`;
- remove `didActivateDNDForMeeting` and `didActivateSlackDNDForMeeting` from this service;
- remove notification-based republishing;
- replace direct Slack/DND writes in meeting transitions with coordinator calls;
- keep honest metrics tracking (`metricsTracker.observeActiveMeeting` / `observeNoActiveMeeting`) untouched.

Required transition path:

```swift
private func transition(to meeting: CalendarMeeting?) {
    if let meeting {
        metricsTracker.observeActiveMeeting(meeting)
    } else {
        metricsTracker.observeNoActiveMeeting()
    }

    currentMeeting = meeting
    presenceCoordinator.calendarMeetingUpdated(meeting)
}
```

Equivalent structure is fine, but metrics and presence must remain separate concerns.

## 6. Wiring in AppDelegate

Update `OnItFocusApp.swift` so `AppDelegate` constructs one coordinator and injects it into both services.

Requirements:

- `SlackService.shared` and `DNDService.shared` remain the concrete runtime dependencies;
- exactly one `DefaultPresenceCoordinator` instance per app runtime;
- `FocusIntegrationService` and `CalendarSlackIntegrationService` receive that same instance;
- do not reintroduce notification relays for precedence.

## 7. Tests

Create `Tests/FocallyTests/PresenceCoordinatorTests.swift` with isolated recording doubles.

Do not call live Slack, DND, NotificationCenter relays, Shortcuts, EventKit, timers, or network.

Minimum test matrix:

1. `testCalendarMeetingPromotesFromIdle`
2. `testManualFocusPromotesOverCalendar`
3. `testCalendarUpdateDuringManualFocusDoesNotOverwritePresence`
4. `testManualFocusEndRestoresRememberedCalendarPresenceImmediately`
5. `testManualFocusEndFallsBackToIdleWhenNoMeetingRemains`
6. `testCalendarEndWhileManualFocusActiveOnlyClearsRememberedMeeting`
7. `testCalendarDNDIsRestoredAfterManualFocusWithoutDNDEnds`
8. `testCoordinatorOnlyDisablesSystemDNDItActivated`
9. `testCoordinatorOnlyDisablesSlackDNDItActivated`
10. `testCalendarHiddenFromSlackClearsStatusButCanStillOwnDND`
11. `testCalendarNonVideoMeetingDoesNotEnableDND`
12. `testManualFocusModeReplacementReappliesPresence`

If small focused service-level tests are needed, add them only to verify the services delegate correctly and remain side-effect safe.

## 8. Validation gates

Inside the worktree before commit:

```text
git diff --check
xcodegen generate
xcodebuild test -project Focally.xcodeproj \
  -scheme Focally \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

Rules:

- use a clean DerivedData path under `/tmp`;
- if `xcodegen generate` touches `Focally.xcodeproj/project.pbxproj`, restore it before the feature commit unless the branch intentionally adds/removes source references that must be integrated later on `main`;
- no commit until host tests pass;
- no merge until Codex final review and independent GLM review both pass.

## 9. Acceptance criteria

TASK-051 is done only when all are true:

1. Presence precedence is owned by one coordinator, not notification bounce logic.
2. Calendar never overwrites manual focus presence.
3. Ending manual focus during an active meeting immediately restores correct Calendar status/DND.
4. The DND restoration bug is covered by a deterministic test and fixed in production logic.
5. Honest Calendar metrics behavior from TASK-050 still works unchanged.
6. No release/version/build/CI/Homebrew files changed.
7. Host test suite passes in the isolated worktree.
8. Final read-only Codex review returns PASS.
9. Final independent GLM review returns PASS.

## 10. Notes for Codex

- This is a refactor with behavioral guarantees, not a redesign of Slack copy.
- Preserve current Slack status text/emoji behavior for both manual focus and Calendar.
- Preserve current DND remaining-minutes behavior for Calendar Slack snooze.
- Keep the diff limited to the authorized files.
- Leave the branch with a clean, reviewable diff; do not commit, push, tag, or release.
