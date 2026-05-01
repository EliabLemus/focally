# TASK-019: Eliminate Dead Code

## Status: TODO

## Date: 2026-05-01

## Objective
Two source files are completely unused: `FocusSession.swift` (47 lines) and `CalendarEventsView.swift` (94 lines). They add confusion, increase build time, and could mislead future contributors into thinking they're part of the app.

## Files to Delete
- `Focally/Models/FocusSession.swift` — 47 lines, not referenced anywhere
- `Focally/Views/CalendarEventsView.swift` — 94 lines, not referenced anywhere

## Verification

Before deleting, verify no references exist:

```bash
cd projects/focally
# FocusSession
rg "FocusSession" --include="*.swift" --glob "!Focally/Models/FocusSession.swift"
# PomodoroState (the enum IS used, it's in FocusSession.swift)
rg "PomodoroState" --include="*.swift" --glob "!Focally/Models/FocusSession.swift"

# CalendarEventsView
rg "CalendarEventsView" --include="*.swift" --glob "!Focally/Views/CalendarEventsView.swift"
```

### Critical: `PomodoroState` enum lives in `FocusSession.swift`

The `PomodoroState` enum IS used extensively throughout the app. **It must be moved** before deleting `FocusSession.swift`.

**Move `PomodoroState` to its own file:**

Create `Focally/Models/PomodoroState.swift`:
```swift
import Foundation

enum PomodoroState: String, Codable {
    case idle
    case work
    case shortBreak
    case longBreak
    case completed
}
```

Then delete `FocusSession.swift` (the struct `FocusSession` is truly unused).

### CalendarEventsView.swift

Fully unused — the calendar UI in `FocusMenuView.calendarSection` is inline. Safe to delete.

## Acceptance Criteria
- [ ] `PomodoroState.swift` created with the enum
- [ ] `FocusSession.swift` deleted (after moving PomodoroState)
- [ ] `CalendarEventsView.swift` deleted
- [ ] All references to `PomodoroState` still work
- [ ] Build succeeds
- [ ] `git status` shows 1 new file, 2 deletions

## Priority
**v0.5.1** — Quick cleanup, zero risk
