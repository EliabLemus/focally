# v0.8.16 — Menu Bar & Settings UX Fixes

## Fixes

### Menu Bar Status Display
- Fixed menu bar showing incorrect emoji/activity after break ends
- Work phase now correctly restores mode emoji (e.g., 🎯) and activity name
- Break phase now displays break emoji extracted from breakLabel (e.g., ☕)
- Added `extractEmoji(from:)` helper to parse `:coffee:` or `☕` from break labels

### Settings UI Hit Areas
- Expanded click targets across entire Settings rows
- GeneralSettingsView: Toggle and picker rows respond to taps anywhere
- AppearanceSettingsView: Theme selection rows have full-area hitbox
- IntegrationsSettingsView: Integration headers (Slack/Calendar) respond to full-area taps
- Fixed issue where Settings only responded to clicks on text/toggle

## Technical Details

**Menu Bar State Management:**
- `startWorkPhase()`: Restores `currentEmoji` and `currentActivity` from `currentMode`
- `startShortBreak()` / `startLongBreak()`: Extract emoji from `breakLabel` for menu display
- `extractEmoji(from:)`: Parses Slack shortcode (`:emoji:`) or unicode emoji from text

**Settings Hit Areas:**
- `.contentShape(Rectangle())` on all interactive rows
- `.onTapGesture` with toggle binding for switch controls
- `.buttonStyle(.plain)` on picker controls