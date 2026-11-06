# TASK-057 — Media-device call detection: auto-pause + Slack "In a Call" presence

## Status

Ready for implementation in branch `feat/call-detection`.

## Baseline

- Base commit: current `main` at spec time (record it in the implementation PR).
- This task must NOT publish, push, tag, or bump version/build. Release stays gated on owner order.
- Builds on existing presence pipeline: `PresenceCoordinator`, `SlackService` (via `PresenceSlackServicing`), `DNDService` (via `PresenceDNDServicing`), `FocusTimerService.pauseSession()/resumeSession()`, `CalendarSlackIntegrationService`.

## Goal

Detect when the user joins any audio/video call on the Mac (Google Meet in Chrome, Slack huddle/call, Zoom, Teams, other clients) by watching microphone and camera device activation — event-driven, no polling — and then:

1. Pause any active focus/Pomodoro session automatically.
2. Set Slack status to the call emoji + `In a Call - Powered by Focally` (default, user-customizable), presence busy, and system DND.
3. On call end, restore the saved Slack status, disable DND if Focally owns it, and resume the session only if Focally was the one that paused it.

The user does nothing: enabling camera or putting on headphones (mic activation) is the trigger.

## Non-goals

- No polling loops, no timers firing while idle.
- No identifying the remote meeting title or participants.
- No new external service or network listener.
- No rewiring of the calendar-meeting flow logic — but its default state changes (see "Calendar default off" below).
- No mobile/other-device detection (macOS local devices only).
- No emoji-per-client editing UI beyond the single custom-message field (the bundle-id → emoji table stays code-defined this task).

## Detection mechanism (researched, verified against shipped apps)

### Rising edge (call start)
- CoreAudio: `AudioObjectAddPropertyListenerBlock` on `kAudioDevicePropertyDeviceIsRunningSomewhere` for every input device (enumerate via `kAudioHardwarePropertyDevices`).
- CoreMediaIO: `CMIOObjectAddPropertyListenerBlock` on the same property for video devices.
- Both are passive system callbacks. Idle cost must be 0% CPU; no run-loop timers.

### Attribution (which client is calling)
- macOS 14.2+: enumerate `kAudioHardwarePropertyProcessObjects` and read `kAudioProcessPropertyIsRunningInput` inside the callback. This names the capturing process without any permission prompt.
- Match by **bundle-id prefix**, not exact PID, because conferencing apps capture from helpers:
  - `com.google.chrome` (any suffix) → Google Meet (or configured Chrome emoji)
  - `com.tinyspeck.slackmacgap` → Slack call
  - `com.zoom` / `us.zoom` → Zoom
  - `com.microsoft.teams` → Teams
  - Additional Firefox/Edge/Discord entries allowed via the same prefix map.
- Known bundle-id → emoji mapping stored in a single source-of-truth table, user-extendable later (settings UI is a follow-up; this task ships the default map + defaults key).

### Falling edge (call end)
- The same listeners fire on release. Re-query real state inside the callback (never trust the event payload): device property first, then process objects for "any non-Apple process still holds input".
- Bluetooth caveat: the property VALUE can be stale on BT devices (AirPods), but the EVENT always arrives — this is why state is re-queried in-callback.
- Debounce: dedupe every callback against last-known state; require a stable state for 1.5 s (configurable constant) before any transition fires. Known real-world behavior: CoreAudio fires listener bursts (9+ callbacks/s during a Meet join with AirPods); without dedupe the Slack API gets hammered.

### False-positive filters
- Exclude Focally's own PID and process objects owned by it.
- Exclude `com.apple.*` process prefixes (dictation/CoreSpeech open the mic).
- If attribution finds NO known client AND no unknown non-Apple process, treat the edge as noise and ignore it.

## Resource budget (hard requirements)

- Idle: zero scheduled work. Listeners only; measured CPU target < 0.1% when no call.
- During a call: one debounced evaluation per real transition, not per callback. No SwiftUI/@Published republish on non-transitions (documented livelock failure mode).
- RAM: one service class, device-id table, last-known-state struct. Budget < 5 MB.

## Calendar default off

The existing calendar → Slack status sync (`CalendarSlackIntegrationService`) changes its default: **OFF unless the user enables it in the settings panel**. Rationale: call detection is the accurate signal; calendar presence would double-report meetings the user never "joined".

- New defaults key `calendarSlackSyncEnabled` (Bool, default `false`). Existing installs that already rely on the sync keep their current effective state only if a migration key `calendarSlackSyncMigrated` is absent — on first launch after this change, if the migration key is missing, set `calendarSlackSyncEnabled` to the behavior users had (preserved via a one-time snapshot) and set the migration key. Fresh installs default to `false`.
- The settings panel gains an explicit toggle "Show calendar meetings in Slack" with helper text explaining that device-based call detection now covers real call activity independently.
- Detection precedence stays as specified below (calendar presence still wins while enabled AND active), but with the sync off, calendar events never set presence.

## DND reliability layers (folded from DND research)

The call feature silencing the Mac is load-bearing, so DND gets a verification/escalation design instead of write-and-trust:

1. **Layer 1 — legacy CFPreferences write** (current path, kept): `doNotDisturb`/`dndStart`/`dndEnd` + `com.apple.notificationcenterui.dndprefs_changed`. Instant, no external process.
2. **Layer 2 — verification**: ~1 s after the write, read `defaults read com.apple.controlcenter "NSStatusItem Visible FocusModes"` (boolean, no special permissions; 1 = some Focus active). This is the cheapest truth source. `Assertions.json` (exact mode, but TCC/FDA-gated — verified blocked on the owner's macOS 26.2 machine) is explicitly NOT a dependency.
3. **Layer 3 — escalation**: if Layer 2 reports no Focus after the legacy write, invoke the signed shortcut programmatically (`shortcuts run`, via `ManagedFocusShortcutsService`). Tahoe (macOS 26) Shortcuts supports a **generic by-name Focus shortcut** — the app ships ONE pre-signed "Set Focus by Name" shortcut receiving the mode name as input, replacing per-mode shortcuts. Timeout the run at 5 s; on failure, surface an observability event, never retry-loop.
4. **Layer 4 — self-notification suppression**: Focally's own `UNUserNotificationCenter` deliveries use interruption level `.passive` while a call is active, so the app never breaks its own silence.

- Escalation state must be idempotent: verification runs once per transition, not continuously.
- On call end, deactivation follows the same write → verify → escalate path (only if Focally owns the DND).
- The existing cleanup-on-terminate path (TASK-056) is untouched and runs above all layers.

## Presence & session semantics

### New presence source
- Extend `PresenceState` with `.activeCall(CallClient)` where `CallClient` carries `bundlePrefix`, `displayName`, `emoji`.
- Precedence (highest first):
  1. `manualFocus` actively running **and** call starts → session is auto-paused and presence switches to `.activeCall`. On call end, session resumes with remaining time preserved (pause/resume already stores `pausedRemainingSeconds`).
  2. `calendarMeeting` active and call starts → keep calendar presence if it is already showing (calendar title is richer); the call detector must NOT overwrite or restore over it. Track "call detected under calendar presence" to still fire session pause (a Pomodoro under a meeting should pause identically).
  3. Multiple simultaneous captures (e.g., Slack huddle + Chrome Meet): single `.activeCall` presence with the FIRST client; ending one of two must not restore presence until the last capture releases.
- A session paused BY the call detector is marked internally (`pausedByCallDetection`). On call end, resume ONLY sessions with that flag — never resume a session the user paused manually.
- Session end during a call (timer ran to completion of the call window edge cases): if the session ended while the call is active, do nothing on call end beyond presence restore.

### Slack status
- Default message: `In a Call - Powered by Focally`.
- Defaults keys in `CallDetectionSettings`: `callStatusEnabled` (Bool, default `true`), `callStatusMessage` (String, default above).
- **Settings panel UI ships in this task** (not a follow-up): a "Calls" section with
  1. Toggle "Update Slack status during calls"
  2. Text field for the custom status message (live-validates length to Slack's 256-char status limit; empty restores the default placeholder)
  3. Toggle "Enable DND during calls"
  4. Toggle "Pause focus session during calls"
  All four persist via the settings accessor and take effect on the NEXT call without app restart.
- Emoji: client map default (`:google-meet:` for Chrome, `:slack-call:` for Slack, `:zoom:` for Zoom, unknown client → `:phone:`). Table is code-defined this task.
- Presence busy: reuse `SlackService` status set path used by calendar flow (same `setStatus(text:expirationTimestamp:taskEmoji:fallbackEmoji:)`).
- DND: enable via `DNDService.activateDND()`; on end, deactivate ONLY if Focally owns it (`ownsSystemDND`), respecting the existing cleanup-on-terminate rules (DND must never leak if Focally quits mid-call — this is an explicit test).
- Restore: saved previous status emoji+text (same mechanism the calendar flow uses) is restored on call end.

### Grace periods
- Start grace: ignore captures shorter than 3 s (accidental mic blips, dictation edge) — no Slack write is issued until the debounce + grace pass.
- End grace: 2 s stable-idle requirement before "call ended" fires, to absorb client-side mic handoffs (e.g., switching input device mid-call does NOT end the call — the listener fires but process objects keep showing the client).

## Authorized files

### Create
- `Sources/Focally/Services/MediaDeviceCallDetector.swift` — listeners, attribution, debounce state machine
- `Sources/Focally/Models/CallClient.swift` — client model + default bundle-prefix map
- `Sources/Focally/Models/CallDetectionSettings.swift` — enabled flag, custom message, DND/pause toggles
- `Sources/Focally/Views/CallDetectionSettingsView.swift` — "Calls" settings section
- `Sources/Focally/Services/DNDReliabilityService.swift` — verify (Control Center boolean) + escalate (shortcuts run) state machine wrapping `DNDService`
- `Tests/FocallyTests/MediaDeviceCallDetectorTests.swift`
- `Tests/FocallyTests/CallPresenceCoordinatorTests.swift`
- `Tests/FocallyTests/CalendarSyncDefaultTests.swift`
- `Tests/FocallyTests/DNDReliabilityTests.swift`

### Modify
- `Sources/Focally/Services/PresenceCoordinator.swift` — `.activeCall` state, precedence, ownership of pause/resume
- `Sources/Focally/Services/CalendarSlackIntegrationService.swift` — `calendarSlackSyncEnabled` gate + one-time migration
- `Sources/Focally/Services/DNDService.swift` — route activation/deactivation through `DNDReliabilityService`
- `Sources/Focally/Services/ManagedFocusShortcutsService.swift` — add the signed generic "Set Focus by Name" shortcut + programmatic invocation
- `Sources/Focally/Services/NotificationCenterPresenter.swift` / `NotificationService.swift` — interruption level `.passive` while a call is active
- `Sources/Focally/Services/FocusIntegrationService.swift` — only if pause/resume bridging requires it
- `Sources/Focally/OnItFocusApp.swift` — detector lifecycle wiring (start/stop with app)
- Settings panel view — register the new "Calls" section

## Tests (must pass; no real hardware required)

1. **Listener wiring**: injected protocol fakes for CoreAudio/CMIO object handles; detector registers listeners for all enumerated input + video devices; removing a device unregisters cleanly.
2. **Burst dedupe**: fire 12 callbacks in 200 ms with mixed payloads → exactly one transition after debounce, one Slack write.
3. **Attribution**: helper-prefix matching (`com.google.chrome.helper` → Chrome), own-PID excluded, `com.apple corespeech` excluded, unknown non-Apple client → `:phone:`.
4. **Auto-pause**: Pomodoro mid-work-phase, call starts → session paused, `pausedByCallDetection` set, Slack status = custom/default message, busy set, DND on. Call ends → session resumes with correct remaining seconds, status restored, DND off (ownership respected).
5. **No-resume on user pause**: user paused manually before the call → call end does NOT resume.
6. **Short blip**: 1 s capture → no state change at all (no Slack API call — assert on fake service).
7. **Calendar overlap**: calendar meeting presence active + call → session pauses, presence stays calendar's; calendar meeting ends while call continues → presence switches to `.activeCall`, not idle.
8. **Two clients**: second capture while one active → single presence; first ends → presence persists; both end → restore.
9. **Quit mid-call**: Focally terminates while DND owned and status set → cleanup path restores (reuse TASK-056 cleanup tests as the pattern).
10. **BT stale value**: listener fires with stale `isRunning=0` payload but process objects show active client → no false "call ended".
11. **Calendar sync off by default**: fresh install → `calendarSlackSyncEnabled == false`; an event in the calendar window does NOT set Slack presence. Toggle ON → same event sets presence as before (regression vs. the TASK-004 calendar→Slack behavior).
12. **Migration**: existing install with prior sync behavior → first launch after update preserves effective state once (`calendarSlackSyncMigrated` set), second launch does not re-migrate.
13. **Settings take effect live**: change custom message / toggles between two simulated calls → second call uses new values without app restart.
14. **Custom message validation**: 256-char cap enforced; empty field falls back to default text on save.
15. **DND verification**: legacy write applied, verification (fake read) reports Focus ON → no escalation. Verification reports OFF → shortcut invoked exactly once, no retry loop.
16. **DND escalation failure**: shortcut path fails/times out → observability event surfaced, app state consistent, call flow continues (Slack status still set).
17. **DND owns-state**: DND active by USER before the call → Focally does not deactivate on call end.
18. **Self-notification suppression**: while `.activeCall`, Focally's own notification requests carry interruption level `.passive`; restored to previous level on call end.

## Verification

- Full suite: `xcodebuild test` (or the repo's script) green locally.
- Manual smoke on the owner's Mac: start a Slack huddle and a Chrome Meet; confirm pause + status + DND; end call; confirm restore + resume. Record results in the task PR description.
- Idle-resource check: Activity Monitor sample of Focally before/after this change; no new timers in the run loop while idle (assert via the detector's own instrumentation in debug builds).
