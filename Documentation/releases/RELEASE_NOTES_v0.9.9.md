# Focally v0.9.9

## What’s changed

### Reliable DND transitions during pauses

- Pausing a focus session or entering a Pomodoro break now releases Focally-owned Do Not Disturb only after the final system state is verified.
- Calendar handoffs keep Do Not Disturb active without running a late global “Focus Off” action.
- Resuming closes Notification Center only when Focally opened it and still owns that presentation.
- Stale pause transitions can no longer disable Do Not Disturb after a session has already resumed.

### Safer system integration

- Signed Apple Shortcuts are now a bounded fallback instead of a second always-on authority.
- Shortcut execution runs outside the main actor and has a timeout.
- Accessibility setup now explains that Focally opens and closes Notification Center but never reads or stores notification content.
- Notification Center automation degrades safely when Accessibility is unavailable or revoked.

### Honest App Intents

- Pause, Resume, and End Focus actions now reject impossible states instead of reporting false success.
- The duplicate “Start Focus” shortcut action was removed; starting a new session still requires choosing its mode and duration in Focally.

## Verification

- 253 automated tests passed with zero failures.
- Clean macOS Release build passed.
- DND ownership, Calendar handoff, stale-transition cancellation, Notification Center ownership, Accessibility denial, and App Intent state guards have deterministic test coverage.
- The implementation does not inspect, persist, OCR, or summarize notifications from other applications.

## Installation

Download `Focally-v0.9.9.dmg`, open it, and drag Focally to Applications.

On first setup, grant Accessibility permission if you want Focally to open Notification Center when a break begins and close the panel when focus resumes.
