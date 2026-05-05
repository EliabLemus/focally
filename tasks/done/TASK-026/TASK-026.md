# TASK-026 — Critical Fixes Post v0.6.3 Testing

## Project Path
`/Users/openjaime/.openclaw/workspace/projects/focally`

## Issues Found (from Eliab testing v0.6.3)

### Issue 1: Timer tab looks wrong + theme mixing (light sidebar + dark content or vice versa)
**Root cause:** TWO parallel color systems conflicting:
1. `FocallyColors.swift` — static `Color(hex:)` extensions, LIGHT THEME ONLY
2. `Assets.xcassets/*.colorset` — proper Asset Catalog with light + dark variants

The code uses `Color.focallyXxx` (from FocallyColors.swift) which has NO dark variants. The Asset Catalog colors exist but are NEVER referenced by name (SwiftUI resolves `Color("focallyBackground")` from Assets, not `Color.focallyBackground`).

Sidebar and TopBar have hardcoded `if colorScheme == .dark` checks with hex colors, but the rest of the app uses static light-only colors.

**Fix:** Delete ALL static color definitions from `FocallyColors.swift`. Replace with computed properties that read from the Asset Catalog. This way, `Color.focallyBackground` automatically resolves to light/dark variants.

```swift
// BEFORE (broken — light only):
static let focallyBackground = Color(hex: "F9F9F9")

// AFTER (uses Asset Catalog with light + dark):
static let focallyBackground = Color("focallyBackground")
```

This applies to ALL colors that have Asset Catalog entries. Keep the `Color(hex:)` helper and any colors NOT in the Asset Catalog as static.

### Issue 2: Appearance settings can't switch themes
**Root cause:** `AppearanceSettingsView` saves `ThemeChoice` to `@AppStorage("appTheme")` but nothing reads it. No `.preferredColorScheme()` modifier is applied anywhere.

**Fix:** Apply `preferredColorScheme` at the window level in `OnItFocusApp.swift`:

In `MainWindow`, read `@AppStorage("appTheme")` and apply:
```swift
@AppStorage("appTheme") private var selectedTheme: ThemeChoice = .system

var body: some View {
    HStack(spacing: 0) {
        // ... existing content
    }
    .preferredColorScheme(selectedTheme == .system ? nil : (selectedTheme == .dark ? .dark : .light))
}
```

Also move `ThemeChoice` enum out of `AppearanceSettingsView.swift` into a shared location (e.g., `FocallyTheme.swift` or `FocallyColors.swift`).

### Issue 3: Task configuration can't change color + theme mixing
**Root cause:** Same as Issue 1 — static colors with no dark variants. Also, `PredefinedTask` has `iconBgColor`/`iconFgColor` as hex strings, and `TaskRowView` uses `Color(hex:)` which doesn't adapt to dark mode.

**Fix:** For task icon colors, they should remain static (intentional brand colors that work on any background). But the card backgrounds and text must use Asset Catalog colors (Issue 1 fix covers this).

### Issue 4: Settings appearance theme switching doesn't work
Same as Issue 2.

### Issue 5: Integrations has no credential inputs
**Root cause:** `IntegrationsSettingsView` has toggle switches but no text fields for API tokens/credentials.

**Fix:** Add collapsible credential sections:
- **Slack**: Bot OAuth Token (`@AppStorage("slackBotToken")`), Channel Name
- **Google Calendar**: Client ID, Client Secret, Calendar ID (read-only)
- Show "Connect" button when credentials are filled, "Configure" when empty
- Use secure `SecureField` for tokens/secrets

```swift
struct IntegrationsSettingsView: View {
    @AppStorage("slackBotToken") private var slackBotToken: String = ""
    @AppStorage("slackChannelName") private var slackChannelName: String = ""
    @AppStorage("googleClientId") private var googleClientId: String = ""
    @AppStorage("googleClientSecret") private var googleClientSecret: String = ""
    @AppStorage("googleCalendarId") private var googleCalendarId: String = ""
    @State private var slackEnabled: Bool = false
    @State private var calendarEnabled: Bool = false
    @State private var showSlackCredentials: Bool = false
    @State private var showCalendarCredentials: Bool = false

    // ... with collapsible credential sections using DisclosureGroup or custom toggle
}
```

### Issue 6: About shows © 2025, should be 2026
**Fix:** Change `"© 2025 Eliab Lemus"` to `"© 2025-2026 Eliab Lemus"` in `AboutSettingsView.swift`.

### Issue 7: Custom sessions always 45 minutes (or default), no free input
**Root cause:** `TimerSettingsCard` uses `@State` vars that are NOT connected to `FocusTimerService`. Changing the value in the card does nothing. Also, `IdleDashboardView.TimerDisplayCard` shows `timerService.remainingTimeString` which is "0:0" when idle — no way to preview the configured duration.

**Fix:**
1. `TimerSettingsCard` must use `@EnvironmentObject var timerService: FocusTimerService` and bind directly:
```swift
@EnvironmentObject var timerService: FocusTimerService

// Read from service
init() {
    // Will read in onAppear
}

var body: some View {
    // Use timerService.workDurationMinutes as source of truth
}
```

2. Allow ANY duration (1 min to 600 min = 10 hours). Use a `Stepper` or free-text field with validation:
```swift
@State private var focusMinutes: Int = 25

Stepper(value: $focusMinutes, in: 1...600) {
    Text("\(focusMinutes) min")
}
// OR
TextField("", value: $focusMinutes, format: .number)
    .frame(width: 60)
```

3. When user changes value in TimerSettingsCard, update `timerService.workDurationMinutes` and persist.

4. `IdleDashboardView.TimerDisplayCard` should show the configured duration when idle (not "0:0"):
```swift
// When idle, show configured duration
if timerService.pomodoroState == .idle {
    Text(String(format: "%d:00", timerService.workDurationMinutes))
} else {
    Text(timerService.remainingTimeString)
}
```

### Issue 8: Sidebar has double TopBar with MainWindow's TopBar
**Root cause:** `IdleDashboardView` has its own `topBar` HStack (history + settings buttons). `MainWindow` also renders `TopBarView` above TimerPage. This creates a double top bar on the Timer tab.

**Fix:** Remove the `topBar` from `IdleDashboardView`. The `TopBarView` from `MainWindow` is sufficient.

### Issue 9: Sidebar dark/light hardcoded backgrounds
**Root cause:** Sidebar uses `if colorScheme == .dark { Color(hex: "121317") } else { Color(hex: "F3F3F4") }`. With the Asset Catalog fix (Issue 1), this should use `Color.focallySurfaceContainerLow` or similar token.

**Fix:** Replace hardcoded sidebar backgrounds with Asset Catalog colors. Same for TopBar.

---

## File Change Summary

| File | Action | Issue |
|------|--------|-------|
| `Focally/DesignSystem/FocallyColors.swift` | REWRITE — static→Asset Catalog colors | 1, 3, 9 |
| `Focally/Views/Timer/IdleDashboardView.swift` | EDIT — remove topBar, show configured duration when idle | 7, 8 |
| `Focally/Views/Tasks/TimerSettingsCard.swift` | REWRITE — bind to timerService, allow 1-600 min | 7 |
| `Focally/Views/Settings/AppearanceSettingsView.swift` | EDIT — move ThemeChoice out, verify theme works | 2, 4 |
| `Focally/DesignSystem/FocallyTheme.swift` | EDIT — add ThemeChoice enum here | 2, 4 |
| `Focally/Views/MainWindow.swift` | EDIT — add preferredColorScheme from AppStorage | 2, 4 |
| `Focally/Views/Settings/IntegrationsSettingsView.swift` | REWRITE — add credential fields | 5 |
| `Focally/Views/Settings/AboutSettingsView.swift` | EDIT — © 2025 → © 2025-2026 | 6 |
| `Focally/Views/Navigation/SidebarView.swift` | EDIT — remove hardcoded bg colors | 9 |
| `Focally/Views/Navigation/TopBarView.swift` | EDIT — remove hardcoded bg colors | 9 |

## CRITICAL RULES (unchanged from TASK-025)
1. **ALWAYS use `Color.focallyXxx`** — NEVER `.focallyXxx` shorthand
2. **NO iOS APIs**: No `.keyboardType()`, `.tracking(.widest)`, `.navigationTitle()`
3. **NO `.toggleStyle(FocallyToggleButtonStyle())`** — use `.toggleStyle(.switch)`
4. **TopBarView uses `@ViewBuilder`** — `TopBarView { Text("title") }`
5. **All cards use `.focallyCard()` modifier**
6. **Use `FocallySpacing/FocallyRadius` tokens**
7. **Use `.focallyBodyBold`, `.focallyCaption`, etc.** — NOT raw `Font.system()` unless necessary

## Build Verification
```bash
cd /Users/openjaime/.openclaw/workspace/projects/focally
xcodegen generate
xcodebuild -scheme Focally -destination 'platform=macOS' build 2>&1 | tail -5
```

## Asset Catalog Colors Available (with dark variants)
All of these have both light and dark variants in Assets.xcassets:
focallyBackground, focallySurface, focallySurfaceBright, focallySurfaceDim, focallySurfaceContainerLowest, focallySurfaceContainerLow, focallySurfaceContainer, focallySurfaceContainerHigh, focallySurfaceContainerHighest, focallySurfaceVariant, focallySurfaceTint, focallyOnSurface, focallyOnSurfaceVariant, focallyOutline, focallyOutlineVariant, focallyPrimary, focallyOnPrimary, focallyPrimaryContainer, focallySecondary, focallyOnSecondary, focallySecondaryContainer, focallyTertiary, focallyTertiaryContainer, focallyInverseSurface, focallyInverseOnSurface, focallyInversePrimary, focallyError, focallyErrorContainer, focallyOnError, focallyOnErrorContainer
