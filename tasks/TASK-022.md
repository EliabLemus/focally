# TASK-022: Optimize Status Bar Timer

## Status: TODO

## Date: 2026-05-01

## Objective
`AppDelegate` runs a 1-second timer (`timerUpdate`) continuously to update the status bar title — even when the app is idle and no session is active. This wastes CPU cycles and battery for no visible change.

## Files to Modify
- `Focally/OnItFocusApp.swift`

## Problem

In `AppDelegate`, a timer fires every second:
```swift
timerUpdate = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
    self?.updateStatusBar()
}
```

This runs forever, even when `pomodoroState == .idle` and the status bar shows a static "🍅 Focally" string.

## Detailed Specification

### Solution: Conditional Timer Lifecycle

Only start the timer when a session is active. Stop it when the session ends.

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    // ... existing properties ...
    private var timerUpdate: Timer?
    
    func startStatusBarUpdates() {
        guard timerUpdate == nil else { return }
        timerUpdate = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatusBar()
        }
    }
    
    func stopStatusBarUpdates() {
        timerUpdate?.invalidate()
        timerUpdate = nil
    }
}
```

### When to Start

Subscribe to `focusSessionStarted` notification:

```swift
NotificationCenter.default.addObserver(
    forName: .focusSessionStarted,
    object: nil, queue: .main
) { [weak self] _ in
    self?.startStatusBarUpdates()
}
```

### When to Stop

Subscribe to `focusSessionEnded` notification:

```swift
NotificationCenter.default.addObserver(
    forName: .focusSessionEnded,
    object: nil, queue: .main
) { [weak self] _ in
    // Only stop if session is truly idle (not transitioning between phases)
    if self?.timerService.pomodoroState == .idle {
        self?.stopStatusBarUpdates()
        self?.updateStatusBar() // Final update to show idle state
    }
}
```

**Important:** Don't stop the timer between work→break or break→work transitions. Only stop when `resetToIdle()` or `endSession()` is called.

### Alternative: Observe pomodoroState changes

If using `@Observable` (TASK-016), we can use `withObservationTracking`:

```swift
func observeTimerState() {
    withObservationTracking {
        _ = timerService.pomodoroState
        _ = timerService.remainingSeconds
    } onChange: { [weak self] in
        DispatchQueue.main.async {
            self?.updateStatusBar()
            self?.observeTimerState() // Re-subscribe
        }
    }
}
```

This would eliminate the timer entirely — SwiftUI's observation system handles updates. But this requires TASK-016 to be done first.

### Simplest Implementation (without @Observable)

Use Combine to observe `FocusTimerService.objectWillChange`:

```swift
private var cancellables = Set<AnyCancellable>()

// In applicationDidFinishLaunching:
timerService.$pomodoroState
    .removeDuplicates()
    .sink { [weak self] state in
        if state == .idle {
            self?.stopStatusBarUpdates()
            self?.updateStatusBar()
        } else {
            self?.startStatusBarUpdates()
        }
    }
    .store(in: &cancellables)

// Initial state
updateStatusBar()
```

### updateStatusBar — Static when idle

```swift
func updateStatusBar() {
    if timerService.pomodoroState == .idle {
        statusItem.button?.title = "🍅"
        return
    }
    
    let icon: String
    switch timerService.pomodoroState {
    case .work: icon = "🟢"
    case .shortBreak: icon = "🟡"
    case .longBreak: icon = "🔵"
    default: icon = "🍅"
    }
    
    statusItem.button?.title = "\(icon) \(timerService.remainingMinutesString)"
}
```

## Acceptance Criteria
- [ ] Status bar timer only runs when session is active
- [ ] Timer stops when session ends (idle)
- [ ] Timer continues running through phase transitions (work→break→work)
- [ ] Static "🍅" shown when idle (no per-second updates)
- [ ] Status bar updates correctly during active sessions
- [ ] No visible regression in status bar behavior

## Priority
**v0.5.1** — Performance fix, small scope, no architectural changes needed
