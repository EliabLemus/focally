# TASK-057 STATUS

## Scope shipped

Media-device call detection (CoreAudio mic + CoreMediaIO camera property listeners, event-driven, no polling):

- **`MediaDeviceCallDetector`** — listeners + attribution + debounce (1.5 s) / start-grace (3 s) / end-grace (2 s) state machine, in-callback state re-query, multi-capture set semantics, burst dedupe. All system interaction behind injectable protocols (`MediaDeviceListening`, `CallProcessAttributing`) with injectable clock/scheduler.
- **Attribution** — macOS 14.2+ process objects (`kAudioHardwarePropertyProcessObjects` FourCC `'pobj'`, `kAudioProcessPropertyIsRunningInput`), bundle-id prefix match (Chrome→`:google-meet:`, Slack, Zoom, Teams, Firefox/Edge/Discord; unknown→`:phone:`), own-bundle + `com.apple.*` excluded.
- **Presence** — `.activeCall(CallClient)` state with precedence: call wins over manual focus (auto-pause + auto-resume only if detector paused it via `pausedByCallDetection`), calendar presence kept when call starts under it, single presence across simultaneous clients, quit-mid-call cleanup.
- **Auto-pause** — Pomodoro/focus session pauses on first capture; a user-paused session is NOT paused again nor resumed.
- **Slack status** — default `In a Call - Powered by Focally`, per-client emoji, busy + DND via the same presence path as the calendar flow; restore on end.
- **DND reliability layers** — legacy CFPreferences write → verify (Control Center `NSStatusItem Visible FocusModes`) → escalate at most once via signed generic `focally-focus-by-name-signed` shortcut (`shortcuts run --input`, 5 s timeout, no retry loop, `escalationFailed` observability event).
- **Calendar default off** — `calendarSlackSyncEnabled` master gate (default off) across monitoring start (`startIfEnabled`), fetch access (`fetchTodayEvents`), wake reconcile, and the presence transition gate; one-time migration `calendarSlackSyncMigrated` preserving prior behavior; master toggle in Integrations settings.
- **Settings UI** — new "Calls" section (status toggle, message field with 256-cap + empty→default, DND toggle, pause toggle), en/es/pt localized; settings read fresh at every call transition.

## Test results

`xcodebuild test -scheme Focally -destination 'platform=macOS'`:
**78/78 tests passed, TEST SUCCEEDED** (canonically run from this worktree, 2026-11-06). Includes the 18 spec tests across `MediaDeviceCallDetectorTests`, `CallPresenceCoordinatorTests`, `CalendarSyncDefaultTests`, `DNDReliabilityTests`, with no regressions in the pre-existing suites.

## Deviations

1. **Test 11 assert adjusted** — `freshInstallDefaultsSyncOffAndEventDoesNotReachPresenceCoordinator` expects `currentMeeting == nil` (not non-nil): with the sync off, monitoring does not run at all, which is the stricter reading of the spec ("calendar events never set presence").
2. **`NotificationCenterPresenter` untouched** — it presents the Notification Center panel, not `UNUserNotificationCenter` deliveries; the `.passive` interruption-level hook lives in `NotificationService.makeContent(for:callActive:)` instead.
3. **`IntegrationsSettingsView` toggle** binds the new master `calendarSlackSyncEnabled`; the legacy `isEnabled` property remains for internal persistence but no longer gates monitoring.
4. **Shortcuts integration note** — `focally-focus-by-name-signed` is referenced by name; the actual pre-signed shortcut artifact must be present on the user's machine (existing signed-shortcuts install flow covers this; verify in the release smoke test).

## Known limitations

- Emoji-per-client table is code-defined (per spec, no editing UI this task).
- Call detection covers locally attached mic/camera only (no other-device calls).
- Attribution requires macOS 14.2+; older systems report unknown client → `:phone:` and still pause/DND correctly.
