# Focally v0.9.8

## What’s changed

### Faster session setup

- Added per-session Quick Start customization without changing saved focus modes.
- Pomodoro Quick Start respects the configured work duration.

### More reliable Calendar and Slack integration

- Restored automatic Slack validation and presence reconciliation when Focally launches.
- Calendar presence changes are deduplicated while preserving meeting metrics.
- Calendar monitoring is now event-driven instead of polling every 30 seconds.
- Meeting starts and ends use precise one-shot boundary scheduling.
- Calendar reconciles safely after wake, permission changes, and EventKit updates.
- Slack emoji loading now uses freshness caching and in-flight request deduplication.
- Slack HTTP 429 responses honor `Retry-After` without retry storms or clearing valid data.

### Better integration feedback

- Integration actions now expose honest working, success, and failure states.
- Duplicate requests are suppressed while an operation is in progress.
- Retry actions are explicit and localized.

### Multi-monitor reliability

- Fixed menu-bar popover anchoring when moving between displays.

## Verification

- 202 automated tests passed with 0 failures and 0 skipped.
- Clean macOS Release build passed.
- Calendar, Slack, Keychain, DND, notification, and network tests use inert test doubles.

## Installation

Download `Focally-v0.9.8.dmg`, open it, and drag Focally to Applications.
