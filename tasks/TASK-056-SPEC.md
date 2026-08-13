# TASK-056 — Reliable DND pauses and Notification Center ownership

## Status

`completed`

## Harness

```yaml
task_id: TASK-056
experiment_id: HARNESS-056
driver: openai-codex/gpt-5.6-sol
challenger: zai/glm-5.2
judge: deterministic
base_sha: 6cf821a91242210810599fa1665b3e58dd501511
branch: feat/dnd-pause-notification-center
worktree: /private/tmp/focally-dnd-pause
```

## Objective

When Focally-owned macOS DND transitions from active to finally inactive, open Notification Center. On resume, close it only if Focally opened it for the current pause. Preserve `manual focus > calendar meeting > idle`, external DND ownership, current standard DND + signed Shortcut strategy, durable timer semantics, and honest App Intent feedback.

## Non-goals

- Do not read, scrape, OCR, persist, or summarize notification contents.
- Do not invoke Apple Intelligence summaries or claim they can be invoked.
- Do not create/select a custom Focus or modify `Share Across Devices`.
- Do not add Notification Center behavior to bundled `.shortcut` files.
- Do not push, tag, release, publish, replace `/Applications/Focally.app`, prompt against real user state during tests, or use real Keychain/network/UserDefaults/DND/Accessibility in tests.

## Invariants

1. Presence precedence remains `manual focus > calendar meeting > idle`.
2. Focally never deactivates externally owned DND.
3. A manual-to-calendar handoff never runs a later global Focus Off Shortcut and never opens Notification Center.
4. The signed Shortcut is a fallback only after the direct path misses its target.
5. Pause/resume remains non-blocking; `shortcuts run`, AX lookup, and verification do not block `MainActor`.
6. Restoring/catching up a durable session never replays historical panel effects.
7. Notification Center contents remain private and untouched.
8. Accessibility copy states only that Focally opens/closes Notification Center.

## Acceptance criteria

### AC-01 — Final DND transition is explicit

The coordinator/integration path returns an observable final outcome distinguishing unchanged, activated, deactivated, handoff, and failed states. Outcomes are emitted after bounded verification, not from cached intent alone.

### AC-02 — Shortcut is a true fallback

Direct control is attempted once. The signed Shortcut runs only when verified state misses the target. A calendar handoff requiring DND does not execute Focus Off afterward.

### AC-03 — Open only on final owned deactivation

Exactly one Notification Center open is requested when Focally-owned active DND becomes finally inactive. No open occurs for unchanged state, failed deactivation, external ownership, duplicate events, or handoff to Calendar.

### AC-04 — Close only owned panel on resume

Resume/work transition closes Notification Center before activating DND, but only while the presenter holds a valid ownership lease and the panel remains the one Focally opened. User changes invalidate ownership.

### AC-05 — Accessibility degradation is safe

Missing/revoked Accessibility or an unavailable AX element does not block pause/resume or claim success. The service provides an honest unavailable/failure state and never reads notification text.

### AC-06 — Setup requests and explains Accessibility

The setup flow exposes an Accessibility action with localized EN/ES/PT copy explaining open-on-break and close-on-resume behavior, and states that Focally does not read notifications.

### AC-07 — App Intents are honest

Pause succeeds only for an active unpaused session; Resume succeeds only for an active paused session. Start/End no longer report success when no real operation occurred.

### AC-08 — Lifecycle safety

Restore, wake catch-up, termination, and duplicated pause/resume signals do not replay panel actions or break DND cleanup ownership.

### AC-09 — Deterministic Judge

Focused tests, full suite, clean Release build, project-generation consistency, `git diff --check`, scope/safety checks, and final Challenger review pass with no blocker/high finding.

## Intended scope

```text
Sources/Focally/Services/DNDService.swift
Sources/Focally/Services/PresenceCoordinator.swift
Sources/Focally/Services/FocusIntegrationService.swift
Sources/Focally/Services/ManagedFocusShortcutsService.swift
Sources/Focally/Services/NotificationCenterPresenter.swift (new)
Sources/Focally/Services/PermissionService.swift
Sources/Focally/Views/FocusSetupView.swift
Sources/Focally/Resources/{en,es,pt}.lproj/Localizable.strings
Tests/FocallyTests/PresenceCoordinatorTests.swift
Tests/FocallyTests/FocusTimerServiceTests.swift
Tests/FocallyTests/NotificationCenterPresenterTests.swift (new)
Tests/FocallyTests/FocusIntegrationServiceTests.swift (new if needed)
tasks/TASK-056-SPEC.md
Focally.xcodeproj/project.pbxproj (generated only)
```

Scope may shrink after pre-mortem. Expansion requires a documented reason.

## TDD slices

1. RED/GREEN: handoff never executes global off fallback or opens panel.
2. RED/GREEN: owned deactivation verifies inactive and opens exactly once.
3. RED/GREEN: failed/direct-missed transition executes one fallback and reports verified outcome.
4. RED/GREEN: presenter lease opens/closes only while owned; unavailable AX degrades safely.
5. RED/GREEN: resume closes owned panel before DND activation.
6. RED/GREEN: App Intents reject impossible state.
7. RED/GREEN: setup exposes localized Accessibility explanation/action.

## Judge

```bash
xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' \
  -only-testing:FocallyTests/PresenceCoordinatorTests \
  -only-testing:FocallyTests/FocusTimerServiceTests \
  -only-testing:FocallyTests/NotificationCenterPresenterTests \
  -only-testing:FocallyTests/FocusIntegrationServiceTests

xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS'
xcodebuild clean build -project Focally.xcodeproj -scheme Focally -configuration Release -derivedDataPath /tmp/focally-task056-release
xcodegen generate
git diff --exit-code -- Focally.xcodeproj/project.pbxproj
git diff --check
git status --short
git diff --name-only 6cf821a91242210810599fa1665b3e58dd501511...HEAD
```

## Result

Pending.
