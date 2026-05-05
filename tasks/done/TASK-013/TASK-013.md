# TASK-013: Add Accessibility Labels and Polish

## Status: TODO

## Date: 2026-05-01

## Objective
Add missing accessibility labels to icon-only buttons, emoji buttons, and interactive elements throughout the app. Replace remaining `print()` calls with `Logger`.

## Files to Modify
- `Focally/Views/FocusMenuView.swift`
- `Focally/Views/ActivityInputView.swift`
- `Focally/Views/SettingsView.swift`
- `Focally/Views/CalendarEventsView.swift`
- `Focally/Services/FocusTimerService.swift`
- `Focally/OnItFocusApp.swift`

## Detailed Specification

### FocusMenuView.swift

Add accessibility labels to:
1. **Quick Start button**: `.accessibilityLabel("Quick Start: \(timerService.workDurationMinutes) minute focus session")`
2. **Custom Session button**: `.accessibilityLabel("Start custom focus session")`
3. **Start with Saved Task button**: `.accessibilityLabel("Start with saved task")`
4. **Pause button**: `.accessibilityLabel("Pause session")`
5. **Resume button**: `.accessibilityLabel("Resume session")`
6. **Skip button**: `.accessibilityLabel("Skip to next phase")`
7. **Stop button**: `.accessibilityLabel("Stop session")`
8. **Progress bar**: `.accessibilityLabel("Progress: \(Int(timerService.progress * 100)) percent")`
9. **State icon (emoji)**: `.accessibilityLabel(timerService.phaseName)`
10. **Calendar section**: Already has text labels, verify VoiceOver reads correctly

### ActivityInputView.swift

Add accessibility labels to:
1. **Emoji picker buttons**: `.accessibilityLabel("Emoji: \(emoji)")`
2. **Duration buttons**: `.accessibilityLabel("\(duration) minutes")`
3. **Start button**: `.accessibilityLabel("Start focus session")`
4. **Cancel button**: `.accessibilityLabel("Cancel")`
5. **Predefined task buttons**: `.accessibilityLabel("Saved task: \(task.name)")`
6. **Selected checkmark**: Already visual, but parent button label covers it

### SettingsView.swift

Add accessibility labels to:
1. **Remove duration (xmark) buttons**: `.accessibilityLabel("Remove \(duration) minutes")`
2. **Remove task (trash) buttons**: `.accessibilityLabel("Delete task: \(task.name)")`
3. **Sound option rows**: Already have text, verify VoiceOver
4. **Emoji suggestion chips**: Already have text + symbol, should be fine

### CalendarEventsView.swift

Add accessibility labels to:
1. **Refresh button**: `.accessibilityLabel("Refresh calendar events")` (already has title "Refresh")
2. **Conflict badges**: `.accessibilityLabel("Calendar conflict with \(event.title)")`

### Logger Migration

Replace all `print("[Focally] ...")` with `os.Logger`:

1. **OnItFocusApp.swift**: `print("[Focally] Notification auth error: ...")` → Logger in NotificationService (TASK-010 handles this)
2. **FocusTimerService.swift**: Any remaining print statements → use existing or new logger

## Acceptance Criteria
- [ ] All icon-only buttons have `.accessibilityLabel()`
- [ ] All emoji-only buttons have `.accessibilityLabel()`
- [ ] No `print()` statements remain (all use Logger)
- [ ] VoiceOver can navigate the entire popover UI
- [ ] Build succeeds
