# v0.8.15 — Break Emoji Search & Slack Status Updates

## What's New

Break labels now support Slack emoji search and automatically update your Slack status during breaks.

### Features
- 🔍 **Break Label Emoji Search** — Type `:coffee` to search and select emojis from your Slack workspace
- 📋 **Recent Emojis Picker** — Type `:` to see your most recently used emojis
- 📱 **Slack Break Status** — Automatically updates Slack status during short/long breaks
- ☕ **Custom Break Messages** — Shows `breakLabel` (e.g., "Coffee time ☕") or fallback to "Mode Name — Break"
- ⏱️ **Smart Duration** — Slack status expiration matches break duration (5/15/30 minutes)
- 🎯 **Long Break Support** — Shows "— Long Break" suffix and preserves DND deactivation

### Fixes
- ✅ Break label field didn't support emoji search (unlike emoji field)
- ✅ Break messages weren't sent to Slack (now updates with proper emoji and duration)
- ✅ MenuBar already showed break activity correctly (no changes needed)

### Technical Details
- **Emoji Picker:** Reuses `EmojiValidator.searchShortcodes()` with `recentEmojis` state
- **Slack Break Method:** `performSlackBreakAction()` in `FocusIntegrationService.swift`
- **Integration Point:** `startShortBreak()` and `startLongBreak()` in `FocusTimerService.swift`
- **Ordering:** Long break Slack update BEFORE `deactivateFocusIntegration()` (preserves DND timing)

### Files Modified
- `Focally/Views/Timer/FocusModeEditSheet.swift` (+75 lines)
- `Focally/Services/FocusIntegrationService.swift` (+26 lines)
- `Focally/Services/FocusTimerService.swift` (+11 lines)

### Setup
1. Edit Focus Mode → Pomodoro section → Break label (optional)
2. Type `:` to see recent emojis or `:coffee` to search
3. Select emoji to insert shortcode (e.g., `:coffee:`)
4. During Pomodoro breaks, Slack status updates automatically:
   - Short break: "Coffee time :coffee: — Break" (5 minutes)
   - Long break: "Coffee time :coffee: — Long Break" (15 minutes)