# TASK-006: Fix Pomodoro Break Display and Emoji Search

## Context
User reports 3 issues with Focally v0.8.14:

1. **Break label text field (FocusModeEditSheet.swift)** does NOT support Slack emoji search (`:texto:` format) like the emoji field does (lines 46-136 have search logic for emoji field, but breakLabel field at lines 167-177 is plain TextField).

2. **Break message NOT shown in Menu Bar** (MenuBarDropdownView.swift line 126 shows `currentActivity`, but FocusTimerService.swift lines 138, 150 set `currentActivity` in breaks using `breakLabel` - the value may not be propagating correctly or being overwritten).

3. **Break message NOT sent to Slack** (FocusIntegrationService.swift `performSlackFocusAction` only handles `.start` and `.end` actions, never calls Slack for break phases - no method like `updateSlackStatusForBreak` exists).

## Requirements

### 1. Break Label Emoji Search (FocusModeEditSheet.swift)
Add emoji picker to the break label TextField (lines 167-177) that matches the emoji field behavior:
- Detect `:` at start → show recent emojis (reuse `recentEmojis` state)
- Detect `:query` format → search `EmojiValidator.searchShortcodes` (reuse `searchResults` state)
- Show emoji picker overlay when typing matches pattern
- Allow selecting emoji to replace `:query:` with shortcode
- Keep existing placeholder text "e.g. Coffee time ☕"

Reference: Lines 46-136 in same file have full implementation for emoji field with `searchQuery`, `showEmojiPicker`, `recentEmojis`, `searchResults` states.

### 2. Menu Bar Break Message Display (MenuBarDropdownView.swift)
Ensure MenuBar shows correct break activity:
- When Pomodoro in `.shortBreak` or `.longBreak` phase, line 126 should display `timerService.currentActivity` (which is set in FocusTimerService.swift lines 138, 150)
- Verify FocusTimerService.swift line 138 (`startShortBreak`) and line 150 (`startLongBreak`) set `currentActivity` correctly:
  - Short break: `currentActivity = currentMode?.breakLabel ?? "\(currentActivity) — Break"`
  - Long break: `currentActivity = label.map { "\($0) — Long Break" } ?? "\(currentActivity) — Long Break"`
- If MenuBar shows old activity name during break, debug why `currentActivity` is not updating

### 3. Slack Break Status Update (FocusIntegrationService.swift)
Add Slack status update for break phases:
- Add method `performSlackBreakAction(breakLabel: String?, isLongBreak: Bool)` to FocusIntegrationService.swift
- Call this method from FocusTimerService.swift `startShortBreak()` and `startLongBreak()` after `currentActivity` is set
- In `performSlackBreakAction`:
  - Get break text from `breakLabel` or use fallback: `"Mode Name — Break"` / `"Mode Name — Long Break"`
  - Use `slackService.setStatus(text: breakText, expirationTimestamp: expiration, taskEmoji: currentMode?.emoji ?? ":coffee:")`
  - Use expiration based on break duration (short break: `shortBreakDurationMinutes`, long break: `longBreakDurationMinutes`)
  - If Slack disabled, skip without error
- Do NOT call `deactivateFocusIntegration()` in long break BEFORE Slack update - move Slack call before line 148 in FocusTimerService.swift

## Implementation Notes

### Files to modify:
1. `FocusModeEditSheet.swift` - Add emoji picker to break label TextField
2. `MenuBarDropdownView.swift` - Verify `currentActivity` display (may need no change if already correct)
3. `FocusTimerService.swift` - Add Slack break status calls in `startShortBreak()` and `startLongBreak()`
4. `FocusIntegrationService.swift` - Add `performSlackBreakAction()` method

### Dependencies:
- `SlackService.swift` - `setStatus()` method already exists (line 177), supports `taskEmoji` and `fallbackEmoji`
- `EmojiValidator` - `searchShortcodes()` method exists (already imported in FocusModeEditSheet.swift)
- `FocusTimerService` has access to `focusIntegrationService` via DI (line 34)

### Testing scenarios:
1. Edit Focus Mode, type `:coffee` in Break label field → should show emoji picker with coffee emoji
2. Start Pomodoro session, wait for break → MenuBar should show break activity (e.g., "Coffee time ☕ — Break")
3. During break → Check Slack status → should show break text (e.g., "Coffee time ☕ — Break" with coffee emoji)
4. Long break (after 4 rounds) → Slack status should show "Coffee time ☕ — Long Break"

## Constraints
- Do NOT modify `FocusMode.swift` model - `breakLabel` property already exists and is persisted
- Do NOT modify existing Pomodoro logic (phases, timer, state machine)
- Only add Slack break status, do NOT modify existing start/end Slack calls
- Emoji picker for break label should be identical UX to emoji field picker