# TASK-016: Migrate to @Observable

## Status: TODO

## Date: 2026-05-01

## Objective
Replace all `ObservableObject` + `@Published` with Swift's `@Observable` macro (available since macOS 14, which is already the deployment target). This eliminates `@ObservedObject`, `@EnvironmentObject`, and `objectWillChange` boilerplate, improves performance (only properties actually read by a view trigger updates), and is the modern Swift 5.9+ standard.

## Why
- Every `@Published` change notifies ALL observers — `@Observable` is fine-grained
- `@EnvironmentObject` is deprecated in favor of `@Environment(Service.self)`
- `@ObservedObject` is deprecated in favor of `@Bindable` or direct properties
- All skills (`swift-lang`, `swiftui-core`) explicitly flag `ObservableObject` as ❌ for macOS 14+

## Files to Modify
- `Focally/Services/FocusTimerService.swift`
- `Focally/Services/DNDService.swift`
- `Focally/Services/SlackService.swift`
- `Focally/Services/GoogleCalendarService.swift`
- `Focally/Services/HistoryService.swift`
- `Focally/Services/SoundPlayerService.swift`
- `Focally/Views/FocusMenuView.swift`
- `Focally/Views/SettingsView.swift`
- `Focally/OnItFocusApp.swift`

## Detailed Changes

### Step 1: Add `import Observation` to all service files

Each service file needs `import Observation` at the top.

### Step 2: Migrate FocusTimerService

**Before:**
```swift
class FocusTimerService: ObservableObject {
    @Published var isActive = false
    @Published var isPaused = false
    // ... more @Published
}
```

**After:**
```swift
import Observation

@Observable
class FocusTimerService {
    var isActive = false
    var isPaused = false
    var currentActivity = ""
    var currentEmoji = "📝"
    var remainingSeconds: Int = 0
    var durationMinutes: Int = 25
    var pomodoroState: PomodoroState = .idle
    var currentRound: Int = 0
    var roundsUntilLongBreak: Int = 3
    var isAutoStartEnabled: Bool = true
    var workDurationMinutes: Int = 25
    var shortBreakDurationMinutes: Int = 5
    var longBreakDurationMinutes: Int = 15
    
    // ... rest stays the same, remove @Published from all
}
```

**Note:** `@Published` is removed. No property wrapper needed — `@Observable` automatically tracks access and mutations.

### Step 3: Migrate DNDService

```swift
@Observable
class DNDService {
    var isDNDActive = false
    // ... rest stays the same, remove @Published
}
```

### Step 4: Migrate SlackService

```swift
@Observable
class SlackService {
    var isEnabled = false { /* keep didSet for UserDefaults save */ }
    var isConnected = false
    var connectionError: String?
    var lastStatusText: String?
    // ... rest stays the same, remove @Published
}
```

**Important:** `didSet` still works with `@Observable`. The `isEnabled` didSet that saves to UserDefaults should be kept.

### Step 5: Migrate GoogleCalendarService

```swift
@Observable
class GoogleCalendarService: NSObject, ASWebAuthenticationPresentationContextProviding {
    var isEnabled = false { /* keep didSet */ }
    var isSignedIn = false
    var events: [CalendarEvent] = []
    var connectionError: String?
    // ... rest stays the same, remove @Published
}
```

### Step 6: Migrate HistoryService

```swift
@Observable
class HistoryService {
    // No @Published properties — it's already a data service
    // But adding @Observable lets views track changes if we add published-like properties
}
```

### Step 7: Migrate SoundPlayerService

```swift
@Observable
class SoundPlayerService {
    // Same — no @Published properties to migrate
}
```

### Step 8: Migrate OnItFocusApp.swift

**Before:**
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    let timerService = FocusTimerService()
    let dndService = DNDService()
    let slackService = SlackService()
    let calendarService = GoogleCalendarService()
    let historyService = HistoryService.shared
    
    // FocusMenuHost uses @ObservedObject
}

struct FocusMenuHost: View {
    @ObservedObject var timerService: FocusTimerService
    @ObservedObject var dndService: DNDService
    @ObservedObject var calendarService: GoogleCalendarService
    @ObservedObject var historyService: HistoryService
    
    var body: some View {
        FocusMenuView()
            .environmentObject(timerService)
            .environmentObject(dndService)
            // ...
    }
}
```

**After:**
```swift
struct FocusMenuHost: View {
    var timerService: FocusTimerService
    var dndService: DNDService
    var calendarService: GoogleCalendarService
    var historyService: HistoryService
    
    var body: some View {
        FocusMenuView()
            .environment(timerService)
            .environment(dndService)
            .environment(calendarService)
            .environment(historyService)
    }
}
```

### Step 9: Migrate FocusMenuView

**Before:**
```swift
struct FocusMenuView: View {
    @EnvironmentObject var timerService: FocusTimerService
    @EnvironmentObject var dndService: DNDService
    @EnvironmentObject var calendarService: GoogleCalendarService
    @EnvironmentObject var historyService: HistoryService
}
```

**After:**
```swift
struct FocusMenuView: View {
    @Environment(FocusTimerService.self) var timerService
    @Environment(DNDService.self) var dndService
    @Environment(GoogleCalendarService.self) var calendarService
    @Environment(HistoryService.self) var historyService
}
```

### Step 10: Migrate SettingsView

Same pattern — replace `@EnvironmentObject` with `@Environment(Service.self)`.

### Step 11: Remove `import Combine` from FocusTimerService and OnItFocusApp

No longer needed after removing `ObservableObject`.

### Step 12: Remove `AnyCancellable` references in AppDelegate

The `objectWillChange.sink` pattern (if any) can be removed — `@Observable` handles this automatically.

## Acceptance Criteria
- [ ] All 6 services use `@Observable` instead of `ObservableObject`
- [ ] No `@Published` property wrappers remain in the codebase
- [ ] No `@ObservedObject` or `@EnvironmentObject` remain — replaced with `@Environment(Service.self)`
- [ ] No `import Combine` where only used for `ObservableObject`
- [ ] `FocusMenuView`, `SettingsView` use `@Environment(Service.self)`
- [ ] `FocusMenuHost` passes services via `.environment(service)`
- [ ] Settings window still receives services (may need `.environment()` propagation)
- [ ] Build succeeds with zero warnings related to deprecated APIs
- [ ] All existing functionality works: timer, DND, sounds, Slack, Calendar, history

## Risk
- **Breaking change**: Every file that touches services needs updating
- **SettingsView**: Complex view with many `@EnvironmentObject` — needs careful migration
- **Testing**: Must verify all service interactions work after migration

## Priority
**v0.6.0** — This is a foundational change that makes all future work easier.
