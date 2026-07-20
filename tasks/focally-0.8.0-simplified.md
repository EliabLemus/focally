# Focally 0.8.0 — Simplified Focus Timer

## Goal
Reduce Focally to 3 customizable focus modes. Remove all bloat. Keep Slack DND + macOS DND working perfectly.

## Version
0.8.0 — major simplification, breaking UI change.

## Core Concept
3 modes, each with customizable: emoji, status message, duration.

| Mode | Default Emoji | Default Message | Default Duration | Slack DND | macOS DND | Pomodoro |
|------|-------------|-----------------|-----------------|-----------|-----------|----------|
| 🧠 Focus Time | :brain: | "In focus mode" | 25min | ✅ On | ✅ On | ✅ 25/5 |
| 📅 Meeting | :calendar: | "In a meeting" | 30min | ❌ Off | ❌ Off | ❌ |
| 📧 Inbox | :email: | "Clearing inbox" | 15min | ❌ Off | ❌ Off | ❌ |

## Architecture

### New Model: `FocusMode`
Replace `PredefinedTask` with a simpler `FocusMode` model:

```swift
struct FocusMode: Identifiable, Codable {
    let id: UUID
    var name: String
    var emoji: String          // Slack shortcode, e.g. ":brain:"
    var statusText: String     // Slack status message
    var durationMinutes: Int   // Default duration
    var enableDND: Bool        // Slack + macOS DND
    var enablePomodoro: Bool   // Pomodoro intervals (25/5)
    var pomodoroWorkMinutes: Int
    var pomodoroBreakMinutes: Int
    var pomodoroRounds: Int
}
```

### Built-in defaults (stored in UserDefaults, user can customize)
- Focus Time: `{ emoji: ":brain:", statusText: "In focus mode", duration: 25, dnd: true, pomodoro: true }`
- Meeting: `{ emoji: ":calendar:", statusText: "In a meeting", duration: 30, dnd: false, pomodoro: false }`
- Inbox: `{ emoji: ":email:", statusText: "Clearing inbox", duration: 15, dnd: false, pomodoro: false }`

## Files to REMOVE entirely

### Dead code (already disconnected from UI):
- `Focally/Views/AnalyticsPage.swift`
- `Focally/Views/AnalyticsFocusScoreCard.swift` (hardcoded "94")
- `Focally/Views/SchedulePage.swift`
- `Focally/Views/WeekCalendarView.swift`
- `Focally/Views/FocusBlockView.swift`
- `Focally/Views/CreateFocusBlockSheet.swift`
- `Focally/Views/SmartTemplatesCard.swift` (stub)
- `Focally/Views/FocallyFocusScoreCard.swift`
- `Focally/Views/CalendarStatusCard.swift`
- `Focally/Views/MeetingDurationPicker.swift`

### Services to remove:
- `Focally/Services/GoogleCalendarService.swift`
- `Focally/Services/HistoryService.swift`
- `Focally/Services/AnalyticsService.swift`
- `Focally/Services/ScheduleService.swift`
- `Focally/Services/ManagedFocusShortcutsService.swift`
- `Focally/Services/TestShortcutGenerator.swift`
- `Focally/Models/GoogleCalendarModels.swift`
- `Focally/Models/FocusBlock.swift`
- `Focally/Models/CalendarEvent.swift`

### Views to remove:
- `Focally/Views/ShortcutOnboardingView.swift` (replace with 1 simple setup screen)
- `Focally/Views/MeetingDurationPicker.swift`

### Models to remove:
- `Focally/Models/PredefinedTask.swift` (replaced by FocusMode)
- `Focally/Models/PredefinedTasksList.swift` (replaced by built-in defaults)
- `Focally/Models/PredefinedTaskStore.swift` (replaced by FocusModeStore)

### Tabs to remove from sidebar:
- Remove `.tasks` from `FocallyTab.visibleTabs` — only `.timer` and `.settings`
- Remove `.analytics` and `.schedule` from enum entirely

## Files to MODIFY

### `Focally/Models/FocusMode.swift` — NEW
Simple model with the 3 built-in modes. Store in UserDefaults. Single `FocusModeStore` with load/save.

### `Focally/Views/MainWindow.swift`
- Sidebar: only Timer + Settings tabs
- Remove Schedule/Analytics routes entirely from FocallyTab enum

### `Focally/Views/IdleDashboardView.swift` — MAJOR REWORK
- Show 3 mode cards (Focus Time, Meeting, Inbox)
- Each card shows: mode name, emoji, duration, DND indicator
- Tap card → start session immediately with current settings
- Long-press or gear icon → open `FocusModeEditSheet` to customize
- Remove pomodoro card and quick session card (replaced by the 3 mode cards)

### `Focally/Views/FocusModeCard.swift` — NEW or RENAME from existing
Card for each focus mode. Shows:
- Emoji + name
- Duration (e.g. "25 min")
- DND badge if enabled
- Pomodoro badge if enabled
- Small edit icon (⚙) in corner

### `Focally/Views/FocusModeEditSheet.swift` — NEW
Customization sheet for a mode:
- **Emoji field**: Text input where user types Slack shortcode (e.g. `:brain:`, `:email:`). Show a helper text: "Enter Slack emoji shortcode, e.g. :brain:"
- **Status message field**: Text input for Slack status text
- **Duration**: Stepper or picker (5-120 min)
- **Enable DND**: Toggle (Slack + macOS)
- **Enable Pomodoro**: Toggle (only shown if DND is on, since pomodoro = focus)
- **Pomodoro settings** (collapsible, only if pomodoro enabled): work minutes, break minutes, rounds

### `Focally/Views/ActiveFocusView.swift` — KEEP, minor updates
- Works as-is for timer display
- Ensure it reads from FocusMode instead of PredefinedTask

### `Focally/Views/MenuBarDropdownView.swift` — SIMPLIFY
- Show 3 quick-start buttons (Focus Time, Meeting, Inbox) instead of task list
- Active session card stays the same

### `Focally/Services/FocusIntegrationService.swift` — MODIFY
- `performCombinedFocusAction` reads from `FocusMode` instead of `PredefinedTask`
- PRESERVE: Slack status setting (`setStatus`), Slack DND (`setSlackDNDSnooze`), macOS DND (`DNDService`)
- Only enable DND (both Slack + macOS) if `mode.enableDND == true`
- Only enable pomodoro intervals if `mode.enablePomodoro == true`
- Keep App Intents for Siri shortcuts (low cost, useful)

### `Focally/Services/SlackService.swift` — KEEP AS-IS
- emojiMap expansion (95 entries) stays
- All status/DND methods stay untouched

### `Focally/Services/DNDService.swift` — KEEP AS-IS
- macOS DND logic stays untouched

### `Focally/Views/IntegrationsSettingsView.swift` — SIMPLIFY
- Keep only Slack card (token, test, emoji catalog)
- Remove Google Calendar card entirely

### `Focally/Views/SettingsPage.swift`
- Remove "Tasks" settings section
- Keep General, Integrations (Slack only), Appearance

### `Focally/Views/TimerSettingsView.swift`
- Remove task-specific settings
- Keep global sound/notification settings only
- Pomodoro defaults now live per-mode in FocusModeEditSheet

### `Focally/ViewModels/`
- Remove `PredefinedTaskViewModel` or any task-related VMs
- Add `FocusModeViewModel` if needed (simple CRUD for 3 modes)

## CRITICAL: Do NOT break

1. **Slack DND** (`setSlackDNDSnooze`) — must work exactly as v0.7.37. Only triggered when `enableDND == true`.
2. **macOS DND** (`DNDService`) — must work exactly as v0.7.37. Only triggered when `enableDND == true`.
3. **Slack status emoji** — must use shortcode format (`:brain:`), NOT raw unicode. The expanded emojiMap stays.
4. **Menu bar app** — must remain a menu bar app with dropdown.
5. **Existing unit tests** — update `EmojiValidatorTests` and any task-related tests to use FocusMode. All 32 tests must pass.

## UI Design Principles
- **Minimal clicks**: Tap a mode → starts immediately. Customize via edit sheet, not required.
- **No empty states**: 3 modes always visible, always pre-configured with sensible defaults.
- **Intuitive**: Emoji field shows example, duration is a simple stepper.
- **Clean**: No clutter, no dead tabs, no stubs.

## Testing
- All existing unit tests must pass (update as needed)
- Build must succeed in both Debug and Release configurations
- Run locally: `xcodebuild test -project Focally.xcodeproj -scheme Focally -destination 'platform=macOS' -only-testing:FocallyTests`
- Run locally: `xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release build`
