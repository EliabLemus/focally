# TASK-054 — Calendar, Slack startup, and multi-monitor regression repair

## Status

`done`

## Harness

```yaml
experiment_id: HARNESS-002
task_id: TASK-054
driver: openai-codex/gpt-5.6-sol
challenger: zai/glm-5.2
judge: deterministic
scope_class: non-trivial
```

## User-reported regressions

1. Slack state/status behavior only works after opening the app and pressing **Test Connection**.
2. Clicking Focally's menu-bar icon across displays can lose or strand the popover.
3. Calendar event logic must be reviewed before publication.

## Root-cause evidence before implementation

### Slack startup

`SlackService.attemptAutoReconnectionIfNeeded()` persists `slack.connectionAttempted` in `UserDefaults.standard` and permanently skips future launch validation after the first attempt. `AppDelegate.applicationDidFinishLaunching` calls this one-shot method. Manual **Test Connection** calls `auth.test` again, explaining why the connection state becomes usable only after entering Settings.

### Calendar transitions

`CalendarSlackIntegrationService.checkForActiveMeeting()` calls `transition(to:)` every 30 seconds. `transition(to:)` always calls `presenceCoordinator.calendarMeetingUpdated`, even when both previous and next meetings are `nil` or are the same unchanged event. In idle state, that reaches `DefaultPresenceCoordinator.applyIdle()` and calls `SlackService.clearStatus()`. The existing helper `isPresenceTransition` is unused and compares only IDs, so it cannot distinguish an unchanged meeting from a same-ID event whose title/end time changed.

### Multi-monitor popover

`AppDelegate.togglePopover()` closes whenever `popover.isShown == true`, without checking whether the new click came from another display. When opening, it anchors the popover to the status item and then manually moves the popover window, which can detach its visual/behavioral relationship from the clicked menu-bar item.

## Goal

Restore automatic Slack connection validation on every app launch with a configured token, make Calendar side effects transition-driven, and make menu-bar popover behavior deterministic across displays.

## Non-goals

- No release, push, PR, tag, version/build bump, or Homebrew update.
- No Calendar scheduler redesign or Google Calendar integration.
- No change to presence precedence: manual focus > Calendar meeting > idle.
- No real Slack, Keychain, Calendar, UserDefaults.standard, DND, Shortcuts, notification, or network side effects in tests.
- No unrelated Quick Start, App Intents, metrics, branding, or visual redesign.

## Acceptance criteria

### AC-01 — Slack launch validation

With Slack enabled and a non-empty configured token, each application launch initiates one real `auth.test` validation automatically; a stale historical “attempted” flag cannot suppress it.

### AC-02 — Honest Slack state

Launch validation uses the existing callback/result path: `.working` immediately, then `.success`/`.failed` from the real response. It must not claim connected merely because a token exists. Duplicate launch requests while validation is already `.working` remain suppressed.

### AC-03 — No idle Calendar clearing loop

Repeated Calendar polls with no meeting (`nil -> nil`) do not notify Presence and do not clear Slack status.

### AC-04 — Calendar transition semantics

- `nil -> meeting`, `meeting -> nil`, and `meeting A -> meeting B` notify Presence once.
- An unchanged repeated meeting does not reapply Slack/DND.
- A same-ID meeting whose observable data changes (title, start/end, all-day, video-call classification) is a real transition and is reapplied.

### AC-05 — Active-event selection

Active events use a half-open interval `start <= now < end`, exclude all-day events, and select deterministically from overlapping active events using source order (the service already sorts by start time).

### AC-06 — Wake reconciliation

When the Mac wakes, Calendar monitoring performs an immediate reconciliation when enabled, rather than waiting for the next 30-second timer tick. It preserves manual-focus precedence.

### AC-07 — Same-display menu click

Clicking the menu-bar icon on the same display while its popover is visible closes it.

### AC-08 — Cross-display menu click

Clicking the menu-bar icon on a different display while the popover is visible closes and reopens/reanchors it on the newly clicked display instead of merely disappearing.

### AC-09 — Native anchoring

Popover placement remains anchored to the clicked status-item button. No post-show arbitrary window-frame move is used to drag an already anchored popover between displays.

### AC-10 — Safety and regression gates

Focused tests, full Focally test suite, clean Release build, `git diff --check`, generated-project scope check, and final Challenger review pass with no blocker/high finding.

## TDD slices

1. Slack launch bootstrap: focused RED -> minimal GREEN.
2. Calendar transition classifier and active-event selection: focused RED -> minimal GREEN.
3. Multi-monitor popover decision helper: focused RED -> minimal GREEN.
4. Wake wiring/lifecycle test where deterministic; otherwise compile + bounded source contract check.

## Judge

```bash
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' \
  -only-testing:FocallyTests/SlackOperationStateTests \
  -only-testing:FocallyTests/CalendarPresenceTransitionTests \
  -only-testing:FocallyTests/MenuBarPopoverRoutingTests

xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS'
xcodebuild clean build -project Focally.xcodeproj -scheme Focally -configuration Release
git diff --check
git status --short
git diff --name-only a9c8281...HEAD
```

## Result

- Driver implementation complete and accepted in isolated branch.
- Root causes repaired:
  - removed permanent one-shot Slack launch suppression and false token-implies-connected state;
  - launch `auth.test` is callback-driven and reapplies only active Presence after success;
  - Calendar polling keeps metrics observation but notifies Presence only on observable meeting transitions;
  - same-ID changed events reapply; unchanged events and `nil -> nil` do not;
  - active-event selection excludes all-day events and uses `start <= now < end`;
  - Calendar authorization is reevaluated during polling and wake;
  - wake performs immediate event reconciliation without first reapplying a stale remembered meeting;
  - cross-display clicks reanchor the popover; same-display clicks close it; post-show frame forcing was removed.
- TDD evidence:
  - Slack launch API RED exit 65 -> GREEN;
  - Calendar transition/selection RED exit 65 -> GREEN;
  - popover routing RED exit 65 -> GREEN;
  - reconnect callback RED exit 65 -> GREEN;
  - active Presence reapply RED exit 65 -> GREEN;
  - Calendar permission reevaluation RED exit 65 -> GREEN.
- Challenger pre-mortem `deleg_167bfa77`: timeout after 600.22 seconds / 15 calls, no structured verdict or evidence-backed finding; not counted as approval.
- Challenger final review `deleg_b9f54694`: `PASS`, no blocker/high findings; AC-01 through AC-10 verified against the frozen diff.
- Judge evidence:
  - focused suites: 63 passed, 0 failed, 0 skipped;
  - full suite: 195 passed, 0 failed, 0 skipped;
  - clean Release build: PASS.
- Physical display note: the host currently reports one online 1920x1080 display, so cross-display behavior is covered deterministically by routing tests and AppKit anchoring review, not a live two-monitor exercise.
- Publication: no push, PR, tag, release, version/build bump, Homebrew update, or installed-app replacement.
