# TASK-020: Full Accessibility Compliance

## Status: TODO

## Date: 2026-05-01

## Objective
TASK-013 added basic `accessibilityLabel` to buttons. But accessibility in macOS requires more: hints for actions, value announcements for dynamic content, element grouping, and animation respect for `accessibilityReduceMotion`. Based on the `accessibility` skill guidelines.

## Files to Modify
- `Focally/Views/FocusMenuView.swift`
- `Focally/Views/ActivityInputView.swift`
- `Focally/Views/SettingsView.swift` (or its tab views after TASK-017)

## Detailed Specification

### 1. Accessibility Hints

Every interactive element needs a hint describing the action:

**FocusMenuView:**
```swift
// Quick Start button
.accessibilityHint("Double tap to start a \(timerService.workDurationMinutes) minute focus session")

// Custom Session button
.accessibilityHint("Double tap to configure and start a custom focus session")

// Pause button
.accessibilityHint("Double tap to pause the current session")

// Resume button
.accessibilityHint("Double tap to resume the paused session")

// Skip button
.accessibilityHint("Double tap to skip to the next phase")

// Stop button
.accessibilityHint("Double tap to stop and reset the session")
```

**ActivityInputView:**
```swift
// Activity text field
.accessibilityHint("Enter the name of your focus activity")

// Duration picker
.accessibilityHint("Select the duration for your focus session")

// Start button
.accessibilityHint("Double tap to begin the focus session")

// Cancel button
.accessibilityHint("Double tap to cancel and go back")
```

### 2. Accessibility Value for Timer

The timer display needs an accessibility value that VoiceOver can announce:

```swift
Text(timerService.remainingTimeString)
    .font(.system(size: 72, weight: .light, design: .monospaced))
    .accessibilityLabel("Time remaining")
    .accessibilityValue(timerService.remainingTimeString)
    // Remove .contentTransition(.numericText()) when reduce motion is on
```

### 3. Accessibility Element Grouping

Group related elements so VoiceOver reads them as one unit:

```swift
// History session row
HStack(spacing: 8) {
    Text(session.emoji)
    Text(session.activity)
    Spacer()
    Text("\(session.durationMinutes)m")
}
.accessibilityElement(children: .combine)
.accessibilityLabel("\(session.emoji) \(session.activity), \(session.durationMinutes) minutes")

// Calendar event row
HStack(alignment: .top, spacing: 10) {
    VStack(alignment: .leading, spacing: 2) {
        Text(event.timeRange)
        Text(event.title)
    }
    Spacer()
    if hasConflict { Text("Conflict") }
}
.accessibilityElement(children: .combine)
.accessibilityLabel("\(event.title), \(event.timeRange)\(hasConflict ? ", schedule conflict" : "")")
```

### 4. Reduce Motion Support

Wrap animations with `accessibilityReduceMotion` check:

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// In body, replace:
//   .animation(.spring(response: 0.35, dampingFraction: 0.85), value: timerService.pomodoroState)
// With:
.animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: timerService.pomodoroState)
.animation(reduceMotion ? nil : .spring(response: 0.3), value: showActivityInput)

// Progress bar animation:
.animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: timerService.progress)

// Timer content transition:
if !reduceMotion {
    text.contentTransition(.numericText())
}
```

### 5. Progress Bar Accessibility

```swift
// Progress bar
HStack {
    Text(timerService.phaseName)
        .accessibilityHidden(true) // redundant with parent
    Spacer()
    Text("\(Int(timerService.progress * 100))%")
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(timerService.progress * 100)) percent")
}
```

### 6. Settings Accessibility

Each tab should have a meaningful accessibility identifier:

```swift
TabView {
    TimerSettingsTab(...)
        .tabItem { Label("Timer", systemImage: "timer") }
        .accessibilityIdentifier("settings-timer-tab")
    // ...
}
```

Sound picker rows should announce selection state:

```swift
SoundPickerRow(...)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityHint("Double tap to select \(soundOption) sound")
```

## Acceptance Criteria
- [ ] Every interactive element has `.accessibilityHint()`
- [ ] Timer display has `.accessibilityLabel()` + `.accessibilityValue()`
- [ ] History rows use `.accessibilityElement(children: .combine)`
- [ ] Calendar event rows use `.accessibilityElement(children: .combine)`
- [ ] All spring/easeInOut animations respect `accessibilityReduceMotion`
- [ ] `.contentTransition(.numericText())` disabled when reduce motion is on
- [ ] Progress percentage has accessibility value
- [ ] Build succeeds
- [ ] VoiceOver can navigate the entire app and understand all controls

## Priority
**v0.5.1** — Accessibility is not optional, and the reduce-motion issue is a regression from TASK-015
