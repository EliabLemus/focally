# TASK-021: Centralize Settings — SettingsStore (TASK-012 Revisit)

## Status: TODO

## Date: 2026-05-01

## Objective
Original TASK-012 spec was created but never implemented. This is a refined version incorporating the code review findings. The core problem remains: `SettingsView` uses 18 `@AppStorage` properties + corresponding `@State` drafts, while `FocusTimerService` and `SoundPlayerService` read directly from `UserDefaults`. Three independent sources of truth for the same data.

## Relation to Other Tasks
- **Depends on**: TASK-017 (Split SettingsView) — easier to migrate tabs than monolith
- **Depends on**: TASK-016 (@Observable) — `SettingsStore` should be `@Observable` from the start
- **Enables**: TASK-022 (timer optimization) — services can observe `SettingsStore` for changes

## Files to Create
- `Focally/Services/SettingsStore.swift`

## Files to Modify
- `Focally/Services/FocusTimerService.swift` — remove `loadSettings()`/`saveSettings()`, read from `SettingsStore`
- `Focally/Services/SoundPlayerService.swift` — read sound config from `SettingsStore`
- `Focally/OnItFocusApp.swift` — create and inject `SettingsStore`
- All Settings tab views (from TASK-017) — use `SettingsStore` instead of `@AppStorage`
- `Focally/Views/ActivityInputView.swift` — read custom durations from `SettingsStore`

## Detailed Specification

### SettingsStore.swift

```swift
import Foundation
import Observation

@Observable
class SettingsStore {
    // Timer durations
    var workDurationMinutes: Int = 25
    var shortBreakDurationMinutes: Int = 5
    var longBreakDurationMinutes: Int = 15
    
    // Custom durations (duration picker)
    var customDurations: [Int] = [25, 45, 60, 90]
    
    // Pomodoro
    var roundsUntilLongBreak: Int = 3
    var isAutoStartEnabled: Bool = true
    
    // Sound
    var soundEnabled: Bool = true
    var soundVolume: Double = 1.0
    var soundRepeatCount: Int = 2
    var workSoundName: String = "Bell"
    var breakSoundName: String = "Ping"
    var longBreakSoundName: String = "Glass"
    
    // Appearance
    var useSystemTheme: Bool = true
    
    // Slack
    var slackStatusEmoji: String = ":hourglass_flowing_sand:"
    
    // Predefined tasks
    var predefinedTasks: [PredefinedTask] = []
    
    private let defaults = UserDefaults.standard
    
    init() {
        loadFromDefaults()
    }
    
    func loadFromDefaults() {
        workDurationMinutes = defaults.int("workDurationMinutes", default: 25)
        shortBreakDurationMinutes = defaults.int("shortBreakDurationMinutes", default: 5)
        longBreakDurationMinutes = defaults.int("longBreakDurationMinutes", default: 15)
        roundsUntilLongBreak = defaults.int("roundsUntilLongBreak", default: 3)
        isAutoStartEnabled = defaults.bool("isAutoStartEnabled")
        soundEnabled = defaults.bool(forKey: "soundEnabled")
        soundVolume = defaults.double("soundVolume", default: 1.0)
        soundRepeatCount = max(defaults.object(forKey: "soundRepeatCount") as? Int ?? 2, 1)
        workSoundName = defaults.string(forKey: "workSoundName") ?? "Bell"
        breakSoundName = defaults.string(forKey: "breakSoundName") ?? "Ping"
        longBreakSoundName = defaults.string(forKey: "longBreakSoundName") ?? "Glass"
        useSystemTheme = defaults.bool(forKey: "useSystemTheme")
        slackStatusEmoji = defaults.string(forKey: "slackStatusEmoji") ?? ":hourglass_flowing_sand:"
        customDurations = defaults.decodeJSON("customDurations", default: [25, 45, 60, 90])
        predefinedTasks = defaults.decodeJSON(PredefinedTask.defaultsKey, default: [])
    }
    
    func saveToDefaults() {
        defaults.set(workDurationMinutes, forKey: "workDurationMinutes")
        defaults.set(shortBreakDurationMinutes, forKey: "shortBreakDurationMinutes")
        defaults.set(longBreakDurationMinutes, forKey: "longBreakDurationMinutes")
        defaults.set(roundsUntilLongBreak, forKey: "roundsUntilLongBreak")
        defaults.set(isAutoStartEnabled, forKey: "isAutoStartEnabled")
        defaults.set(soundEnabled, forKey: "soundEnabled")
        defaults.set(soundVolume, forKey: "soundVolume")
        defaults.set(soundRepeatCount, forKey: "soundRepeatCount")
        defaults.set(workSoundName, forKey: "workSoundName")
        defaults.set(breakSoundName, forKey: "breakSoundName")
        defaults.set(longBreakSoundName, forKey: "longBreakSoundName")
        defaults.set(useSystemTheme, forKey: "useSystemTheme")
        defaults.set(slackStatusEmoji, forKey: "slackStatusEmoji")
        defaults.encodeJSON(customDurations, forKey: "customDurations")
        defaults.encodeJSON(predefinedTasks, forKey: PredefinedTask.defaultsKey)
    }
}

// UserDefaults convenience extensions
private extension UserDefaults {
    func int(_ key: String, default value: Int) -> Int {
        let v = integer(forKey: key)
        return v == 0 ? value : v
    }
    func double(_ key: String, default value: Double) -> Double {
        let v = double(forKey: key)
        return v == 0.0 ? value : v
    }
    func decodeJSON<T: Decodable>(_ key: String, default: T) -> T {
        guard let data = data(forKey: key),
              let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            return `default`
        }
        return decoded
    }
    func encodeJSON<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        set(data, forKey: key)
    }
}
```

### FocusTimerService Changes

Remove `loadSettings()` and `saveSettings()` entirely. Add a reference to `SettingsStore`:

```swift
@Observable
class FocusTimerService {
    let settingsStore: SettingsStore
    let soundPlayer: SoundPlayerService
    let notificationService: NotificationService
    let historyService: HistoryService
    
    init(settingsStore: SettingsStore,
         soundPlayer: SoundPlayerService = .shared,
         notificationService: NotificationService = NotificationService(),
         historyService: HistoryService = .shared) {
        self.settingsStore = settingsStore
        self.soundPlayer = soundPlayer
        self.notificationService = notificationService
        self.historyService = historyService
        loadLastSession()
    }
}
```

Replace all direct property access with `settingsStore.*`:
- `workDurationMinutes` → `settingsStore.workDurationMinutes`
- `shortBreakDurationMinutes` → `settingsStore.shortBreakDurationMinutes`
- `longBreakDurationMinutes` → `settingsStore.longBreakDurationMinutes`
- `roundsUntilLongBreak` → `settingsStore.roundsUntilLongBreak`
- `isAutoStartEnabled` → `settingsStore.isAutoStartEnabled`

### SoundPlayerService Changes

Read sound config from `SettingsStore`:

```swift
func resolveSoundName(for event: SoundEvent) -> String {
    let store = SettingsStore.shared  // or injected
    switch event {
    case .workEnd: return store.workSoundName
    case .breakEnd: return store.breakSoundName
    case .longBreakEnd: return store.longBreakSoundName
    }
}
```

### ActivityInputView Changes

Replace `@AppStorage("customDurations")` with `@Environment(SettingsStore.self)`:

```swift
var customDurations: [Int] {
    settingsStore.customDurations
}
```

### AppDelegate Changes

```swift
let settingsStore = SettingsStore()
let timerService = FocusTimerService(settingsStore: settingsStore)

// Pass to views
FocusMenuHost(
    timerService: timerService,
    dndService: dndService,
    calendarService: calendarService,
    historyService: historyService,
    settingsStore: settingsStore
)
.environment(settingsStore)
```

## Acceptance Criteria
- [ ] `SettingsStore.swift` created with all settings centralized
- [ ] No `@AppStorage` remains in any view — all use `SettingsStore`
- [ ] `FocusTimerService` has no `loadSettings()`/`saveSettings()` — reads from `SettingsStore`
- [ ] `SoundPlayerService` reads sound config from `SettingsStore`
- [ ] Changing settings + Save → all services see updated values
- [ ] Reopening Settings shows current values
- [ ] Build succeeds

## Priority
**v0.6.0** — Requires TASK-016 + TASK-017 first
