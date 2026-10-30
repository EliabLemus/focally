# Focally v0.10.0

## What’s changed

### Tasks tab — a simple to-do list built for focus

- New **Tasks** tab (second position, next to Timer) with local tasks, optional due dates, and inline creation and editing.
- Pending tasks sort by due date first, then by creation date; overdue tasks get their own collapsible section; completed tasks are kept at the bottom for history.
- Tasks persist to `~/.focally/tasks.json` with atomic writes, and the store tolerates corrupted files by starting empty instead of crashing (same philosophy as sessions).

### Focus sessions linked to tasks

- Press play on a task to start a pomodoro for it: the confirmation sheet uses the task title as the session activity.
- Time and completed pomodoros are attributed to each task and shown right on the row (aggregated from your existing focus metrics — a single source of truth, nothing is double-counted).
- One session belongs to at most one task, and it keeps its task even if you start something else; the binding survives app relaunch via the persisted session snapshot.
- The optional `taskID` was added without a schema version bump, so existing persisted sessions and metrics decode unchanged — no migration risk.

### Due-date reminders

- Tasks with a due date schedule a local notification (`task-reminder-<id>`) that fires when the task is due.
- Completing or deleting a task cancels its pending reminder; re-scheduling is idempotent.
- Notification permission is requested lazily, only the first time you actually schedule a reminder.

### Localization

- Every new string ships in English, Spanish, and Portuguese (283 keys per language, no hardcoded UI strings).

## Verification

- 187 automated tests passed with zero failures.
- Clean macOS Debug and Release builds passed; Release DMG built and verified (`CFBundleShortVersionString` 0.10.0, `CFBundleVersion` 83).

## Known limitations

- No cloud sync, projects, subtasks, labels, recurring tasks, or per-task pomodoro estimates — deliberately out of scope for this version.
- Only one focus session can run at a time; while a session is active, the play button is disabled for other tasks and the running task is marked “Running”.
- The DMG is **not code-signed or notarized**: the build pipeline intentionally builds without signing, so macOS Gatekeeper will require a right-click → Open (or System Settings override) on first launch. This is a pre-existing distribution characteristic, unchanged in this release.

## Installation

Download `Focally-v0.10.0.dmg`, open it, and drag Focally to Applications.

On first setup, grant Accessibility permission if you want Focally to open Notification Center when a break begins and close the panel when focus resumes. To receive task reminders, allow notifications when prompted the first time you set a due date.
