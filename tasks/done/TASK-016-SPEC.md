# TASK-016: Migrate All ObservableObject to @Observable

## Objective
Replace ALL `ObservableObject` + `@Published` with Swift's `@Observable` macro across the entire codebase. Replace all `@EnvironmentObject` with `@Environment(Service.self)`, all `.environmentObject()` with `.environment()`, and remove all `@ObservedObject` and `objectWillChange` patterns.

## Current State (verified in code)
- **14 classes** use `ObservableObject`
- **39 `@EnvironmentObject` usages** across 13 view files
- **27 `.environmentObject()` calls** (mostly in OnItFocusApp.swift)
- **1 `@ObservedObject`** in IntegrationsSettingsView.swift
- **1 `objectWillChange.sink`** in OnItFocusApp.swift line 83

## Classes to Migrate (14 total)

### Tier 1: Services injected via environment (10 classes)

These are injected in `OnItFocusApp.swift` via `.environmentObject()` and must be changed to `.environment()`:

1. **FocusTimerService** (`Services/FocusTimerService.swift:8`)
   - Has `@Published` properties
   - `objectWillChange.sink` in OnItFocusApp.swift:83 must be REMOVED (replaced by @Observable tracking)

2. **DNDService** (`Services/DNDService.swift:4`)
   - Has `@Published` properties

3. **SlackService** (`Services/SlackService.swift:5`)
   - Has `@Published` properties
   - `didSet` on `isEnabled` for UserDefaults must be KEPT

4. **GoogleCalendarService** (`Services/GoogleCalendarService.swift:5`)
   - `final class GoogleCalendarService: NSObject, ObservableObject`
   - Inherits from NSObject (keep it for ASWebAuthenticationPresentationContextProviding)
   - Has `@Published` properties
   - `didSet` on `isEnabled` must be KEPT

5. **HistoryService** (`Services/HistoryService.swift:4`)
   - Has `@Published` properties

6. **SoundPlayerService** (`Services/SoundPlayerService.swift:4`)
   - Has `@Published` properties

7. **FocusIntegrationService** (`Services/FocusIntegrationService.swift:61`)
   - Has `@Published` properties

8. **ShortcutDropHandler** (`Services/ShortcutDropHandler.swift:8`)
   - Used via `@ObservedObject` in IntegrationsSettingsView.swift:8

9. **ManagedFocusShortcutsService** (`Services/TestShortcutGenerator.swift:41`)
   - Has `@Published` properties

10. **PredefinedTaskStore** (`Models/PredefinedTask.swift:146`)
    - Has `@Published` properties

### Tier 2: Services used locally (4 classes)

These are NOT injected via environment — they are created locally or are singletons:

11. **AnalyticsService** (`Services/AnalyticsService.swift:5`)
    - Singleton pattern (`static let shared`)

12. **ScheduleService** (`Services/ScheduleService.swift:4`)
    - Singleton pattern

13. **EmojiUsageTracker** (`Services/SlackService.swift:885`)
    - Used as `@EnvironmentObject` in views — check if it's also injected in OnItFocusApp

14. **ShortcutOnboardingViewModel** (`Views/ShortcutOnboardingViewModel.swift:50`)
    - Created locally in OnItFocusApp.swift, not injected via environment

## Files to Modify

### Service files (remove `ObservableObject`, add `@Observable`, remove `@Published`):
1. `Focally/Services/FocusTimerService.swift`
2. `Focally/Services/DNDService.swift`
3. `Focally/Services/SlackService.swift`
4. `Focally/Services/GoogleCalendarService.swift`
5. `Focally/Services/HistoryService.swift`
6. `Focally/Services/SoundPlayerService.swift`
7. `Focally/Services/AnalyticsService.swift`
8. `Focally/Services/ScheduleService.swift`
9. `Focally/Services/ShortcutDropHandler.swift`
10. `Focally/Services/FocusIntegrationService.swift`
11. `Focally/Services/TestShortcutGenerator.swift` (ManagedFocusShortcutsService)
12. `Focally/Models/PredefinedTask.swift` (PredefinedTaskStore)
13. `Focally/Views/ShortcutOnboardingViewModel.swift`

### View files (replace `@EnvironmentObject` → `@Environment(Service.self)`):
14. `Focally/OnItFocusApp.swift` — **CRITICAL**: Replace `.environmentObject()` with `.environment()`, remove `objectWillChange.sink`
15. `Focally/Views/Shared/FocusSessionComponents.swift` (3 @EnvironmentObject)
16. `Focally/Views/Timer/TimerControlsView.swift` (1)
17. `Focally/Views/Timer/TimerPage.swift` (3)
18. `Focally/Views/Timer/IdleDashboardView.swift` (8 — LARGEST)
19. `Focally/Views/Timer/ActiveFocusView.swift` (2)
20. `Focally/Views/Timer/EstimatedTimeCard.swift` (1)
21. `Focally/Views/MenuBar/MenuBarDropdownView.swift` (6)
22. `Focally/Views/Calendar/QuickSessionsSection.swift` (3)
23. `Focally/Views/Calendar/CalendarStatusCard.swift` (1)
24. `Focally/Views/Tasks/PredefinedTasksList.swift` (3)
25. `Focally/Views/Tasks/TimerSettingsCard.swift` (2)
26. `Focally/Views/Settings/SettingsPage.swift` (2)
27. `Focally/Views/Settings/IntegrationsSettingsView.swift` (4 + 1 @ObservedObject)

## Migration Rules

### For each service class:
```swift
// BEFORE
import Foundation  // (or whatever)
class FooService: ObservableObject {
    @Published var isEnabled = false
    @Published var items: [String] = []
}

// AFTER
import Observation
@Observable
class FooService {
    var isEnabled = false
    var items: [String] = []
}
```

### Special cases:
- **GoogleCalendarService**: Keep `NSObject` inheritance. Change to `@Observable final class GoogleCalendarService: NSObject`.
- **EmojiUsageTracker**: It's a nested class inside SlackService.swift (line 885). Migrate it too.
- **PredefinedTaskStore**: Inside PredefinedTask.swift. Migrate it too.
- **didSet properties**: KEEP all `didSet` observers (e.g., `isEnabled { didSet { UserDefaults.standard.set(...) } }`). `didSet` works with `@Observable`.

### For OnItFocusApp.swift:
```swift
// BEFORE (lines 68-77)
.environmentObject(timerService)
.environmentObject(dndService)
// ... etc

// AFTER
.environment(timerService)
.environment(dndService)
// ... etc
```

Also remove the `objectWillChange.sink` at line 83 — this pattern is no longer needed with `@Observable`.

### For all views:
```swift
// BEFORE
@EnvironmentObject var timerService: FocusTimerService

// AFTER
@Environment(FocusTimerService.self) var timerService
```

### For the single @ObservedObject:
```swift
// BEFORE (IntegrationsSettingsView.swift:8)
@ObservedObject var shortcutDropHandler: ShortcutDropHandler

// AFTER
var shortcutDropHandler: ShortcutDropHandler  // Pass directly, no wrapper needed
// OR keep @Environment if it's injected via environment
@Environment(ShortcutDropHandler.self) var shortcutDropHandler
```
Check how `shortcutDropHandler` is passed to this view. If it comes from `.environmentObject()` in the parent, use `@Environment`. If passed as a direct parameter, use a plain property.

### For Combine imports:
- Remove `import Combine` ONLY from files where Combine was used solely for `ObservableObject` / `objectWillChange`.
- KEEP `import Combine` if the file uses Combine for other purposes (e.g., `AnyCancellable` for network calls, `Timer.publish`).

## Important Warnings

1. **DO NOT change `private` to `internal`** to fix compilation errors. Keep existing visibility.
2. **DO NOT move methods between classes.** If a method is in class A, it stays in class A.
3. **DO NOT add `import Observation` to files that don't have ObservableObject.**
4. **Build frequently.** If you get type-check timeout errors, stop and verify your changes are correct.
5. **For singleton services** (AnalyticsService, ScheduleService): These use `static let shared`. Add `@Observable` but they are NOT injected via environment — views access them via `.shared`. No view changes needed for these unless they use `@EnvironmentObject` to receive them.
6. **ShortcutOnboardingViewModel**: Created locally in OnItFocusApp.swift as `@StateObject`. Replace with `@State` since it's `@Observable` now.

## Acceptance Criteria
- [ ] Zero `ObservableObject` in the codebase (except in comments/tests)
- [ ] Zero `@Published` in the codebase
- [ ] Zero `@EnvironmentObject` in the codebase
- [ ] Zero `@ObservedObject` in the codebase
- [ ] Zero `objectWillChange` references
- [ ] All `.environmentObject()` replaced with `.environment()`
- [ ] All views use `@Environment(Service.self)` for injected services
- [ ] `import Combine` removed where only used for ObservableObject
- [ ] `import Observation` added to all migrated service files
- [ ] Build succeeds: `xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Release build`
- [ ] All existing functionality preserved
