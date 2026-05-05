# TASK-015: Add State Transition Animations

## Status: TODO

## Date: 2026-05-01

## Objective
Add smooth animations to state transitions in FocusMenuView — idle ↔ active, pause ↔ resume, phase changes. Currently all transitions are instant, which feels jarring.

## Files to Modify
- `Focally/Views/FocusMenuView.swift`

## Detailed Specification

### Idle → Active Transition

Wrap the conditional view switching with `animation`:

```swift
if showActivityInput {
    ActivityInputView(...)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
} else if timerService.pomodoroState == .idle {
    idleView
        .transition(.opacity)
} else {
    activeView
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
}
```

The parent `if/else` should be wrapped with:
```swift
.animation(.spring(response: 0.35, dampingFraction: 0.85), value: timerService.pomodoroState)
.animation(.spring(response: 0.3), value: showActivityInput)
```

### Progress Bar Animation

The progress bar already updates every second. Make it smooth:

```swift
RoundedRectangle(cornerRadius: 5)
    .fill(progressColor)
    .frame(width: max(geometry.size.width * timerService.progress, timerService.progress > 0 ? 10 : 0))
    .animation(.easeInOut(duration: 0.5), value: timerService.progress)
```

### Timer Text Animation

The countdown number changes every second. Add a subtle pulse when seconds change:

```swift
Text(timerService.remainingTimeString)
    .font(.system(size: 72, weight: .light, design: .monospaced))
    .contentTransition(.numericText())
```

`contentTransition(.numericText())` provides a smooth digit-roll animation on macOS 14+.

### State Icon Animation

Add a subtle scale bounce when state changes:

```swift
Text(timerService.stateIcon)
    .font(.system(size: 48))
    .scaleEffect(iconScale)
    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: timerService.pomodoroState)
```

Where `iconScale` returns 1.0 normally but the `contentTransition` on the Text handles the visual change.

### Pause/Resume Button

The control buttons should transition smoothly when switching between pause/resume:

```swift
// Already using .tint and .controlSize, just add:
.animation(.easeInOut(duration: 0.2), value: timerService.isPaused)
```

### Color Transitions

The progress bar color and state card background should transition smoothly:

```swift
var progressColor: Color {
    // ... existing logic
}
// Already changes based on state. Just ensure the parent has:
.animation(.easeInOut(duration: 0.3), value: timerService.pomodoroState)
```

## Acceptance Criteria
- [ ] Idle → Active transition is animated (fade/scale)
- [ ] Active → Idle transition is animated
- [ ] Progress bar animates smoothly (not jumping)
- [ ] Timer text uses numeric text transition (digit roll)
- [ ] State icon changes are animated
- [ ] No animation jank or unnecessary re-renders
- [ ] Build succeeds
