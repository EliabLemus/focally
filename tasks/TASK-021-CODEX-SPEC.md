# TASK-021: Centralize Settings — SettingsStore

## Objective
Create a single `@Observable SettingsStore` that becomes the single source of truth for all app settings. Currently settings are scattered across:
- `FocusTimerService` — has its own `loadSettings()`/`saveSettings()` reading/writing UserDefaults for timer durations, rounds, auto-start
- `SoundPlayerService` — has its own `loadSettings()`/`saveSettings()` for sound config
- `@AppStorage("appTheme")` in `AppearanceSettingsView.swift` and `MainWindow.swift`
- Direct `UserDefaults` reads for theme in `OnItFocusApp.swift` (`applySavedTheme()` reads `"appTheme"`)
- `GeneralSettingsView` uses local `@State` vars (`soundEnabled`, `selectedSound`, `launchAtLogin`, `showInMenuBar`) that don't connect to anything

## Files to Create

### 1. `Focally/Services/SettingsStore.swift`

Create an `@Observable` class that centralizes ALL settings:

```swift
import Foundation
import Observation

@Observable
final class SettingsStore {
    // MARK: - Timer Durations
    var workDurationMinutes: Int = 25
    var shortBreakDurationMinutes: Int = 5
    var longBreakDurationMinutes: Int = 15
    var roundsUntilLongBreak: Int = 4
    var isAutoStartEnabled: Bool = true

    // MARK: - Sound
    var soundEnabled: Bool = true
    var soundVolume: Double = 1.0
    var soundRepeatCount: Int = 2
    var workSoundName: String = "Bell"
    var breakSoundName: String = "Ping"
    var longBreakSoundName: String = "Glass"
    var completionSoundName: String = "confirmation_003"

    // MARK: - Appearance
    var appTheme: ThemeChoice = .system

    private let defaults = UserDefaults.standard

    init() {
        loadFromDefaults()
    }

    func loadFromDefaults() {
        // Timer
        workDurationMinutes = storedInt(forKey: "workDurationMinutes", default: 25)
        shortBreakDurationMinutes = storedInt(forKey: "shortBreakDurationMinutes", default: 5)
        longBreakDurationMinutes = storedInt(forKey: "longBreakDurationMinutes", default: 15)
        roundsUntilLongBreak = storedInt(forKey: "roundsUntilLongBreak", default: 4)
        isAutoStartEnabled = defaults.object(forKey: "isAutoStartEnabled") != nil
            ? defaults.bool(forKey: "isAutoStartEnabled")
            : true

        // Sound
        soundEnabled = defaults.object(forKey: "soundEnabled") != nil
            ? defaults.bool(forKey: "soundEnabled")
            : true
        soundVolume = defaults.object(forKey: "soundVolume") != nil
            ? defaults.double(forKey: "soundVolume")
            : 1.0
        soundRepeatCount = max(defaults.object(forKey: "soundRepeatCount") as? Int ?? 2, 1)
        workSoundName = defaults.string(forKey: "workSoundName") ?? "Bell"
        breakSoundName = defaults.string(forKey: "breakSoundName") ?? "Ping"
        longBreakSoundName = defaults.string(forKey: "longBreakSoundName") ?? "Glass"
        completionSoundName = validateCompletionSoundName(
            defaults.string(forKey: "completionSoundName")
        )

        // Appearance
        if let raw = defaults.string(forKey: "appTheme"),
           let choice = ThemeChoice(rawValue: raw) {
            appTheme = choice
        }
    }

    // MARK: - Persistence
    func saveTimerSettings() {
        defaults.set(workDurationMinutes, forKey: "workDurationMinutes")
        defaults.set(shortBreakDurationMinutes, forKey: "shortBreakDurationMinutes")
        defaults.set(longBreakDurationMinutes, forKey: "longBreakDurationMinutes")
        defaults.set(roundsUntilLongBreak, forKey: "roundsUntilLongBreak")
        defaults.set(isAutoStartEnabled, forKey: "isAutoStartEnabled")
    }

    func saveSoundSettings() {
        defaults.set(soundEnabled, forKey: "soundEnabled")
        defaults.set(soundVolume, forKey: "soundVolume")
        defaults.set(soundRepeatCount, forKey: "soundRepeatCount")
        defaults.set(workSoundName, forKey: "workSoundName")
        defaults.set(breakSoundName, forKey: "breakSoundName")
        defaults.set(longBreakSoundName, forKey: "longBreakSoundName")
        defaults.set(completionSoundName, forKey: "completionSoundName")
    }

    func saveTheme() {
        defaults.set(appTheme.rawValue, forKey: "appTheme")
    }

    // MARK: - Helpers
    private func storedInt(forKey key: String, default value: Int) -> Int {
        let v = defaults.integer(forKey: key)
        return v == 0 ? value : v
    }

    private func validateCompletionSoundName(_ storedName: String?) -> String {
        guard let storedName,
              SoundPlayerService.CompletionSoundVariant(rawValue: storedName) != nil else {
            return "confirmation_003"
        }
        return storedName
    }
}
```

## Files to Modify

### 2. `Focally/Services/FocusTimerService.swift`

**Changes:**
- Add `let settingsStore: SettingsStore` property
- Remove `private let defaults = UserDefaults.standard`
- Remove `private func loadSettings()` — settings now come from SettingsStore
- Remove `private func saveSettings()` — call `settingsStore.saveTimerSettings()` instead
- Change `init()` to accept `settingsStore: SettingsStore` parameter
- Replace all internal references to timer settings properties to read from `settingsStore`:
  - `self.workDurationMinutes` stays as a local property on FocusTimerService (it's used for UI and computed from settings during session start)
  - BUT initialize it from `settingsStore.workDurationMinutes` in init
  - `roundsUntilLongBreak` → read from `settingsStore.roundsUntilLongBreak`
  - `isAutoStartEnabled` → read from `settingsStore.isAutoStartEnabled`
  - `shortBreakDurationMinutes` → read from `settingsStore.shortBreakDurationMinutes`
  - `longBreakDurationMinutes` → read from `settingsStore.longBreakDurationMinutes`
- In `updateWorkDuration`, `updateShortBreakDuration`, `updateLongBreakDuration`, `updateAutoStartEnabled`, `updateRoundsUntilLongBreak`, `configurePomodoroPreset`: update BOTH the local property AND the settingsStore, then call `settingsStore.saveTimerSettings()`
- `loadLastSession()` still reads `lastActivity`, `lastEmoji`, `lastDuration` from UserDefaults directly (those are session state, not settings)

**IMPORTANT:** FocusTimerService should KEEP its own copies of timer duration properties as `var` because they are @Observable and used directly by views via `@Environment(FocusTimerService.self)`. The SettingsStore holds the canonical values, and FocusTimerService reads from it on init and writes to it on changes.

### 3. `Focally/Services/SoundPlayerService.swift`

**Changes:**
- Add `let settingsStore: SettingsStore` property (or make it a method parameter alternative: keep `SoundPlayerService.shared` singleton but add a `configure(settingsStore:)` method)
- **Simplest approach**: Keep `SoundPlayerService.shared` singleton. Remove `loadSettings()`/`saveSettings()`. Add a `func syncFromSettingsStore(_ store: SettingsStore)` method that copies values from SettingsStore into SoundPlayerService's local properties.
- In `init()`, do NOT call `loadSettings()` anymore. The settings will be synced from SettingsStore after both are created.
- Remove the `private func storedBool`/`storedDouble` helpers from SoundPlayerService
- Views that change sound settings should update SettingsStore AND call `soundPlayer.syncFromSettingsStore(settingsStore)` then `settingsStore.saveSoundSettings()`

### 4. `Focally/OnItFocusApp.swift` (AppDelegate)

**Changes:**
- Add `let settingsStore = SettingsStore()` property on AppDelegate
- Create SettingsStore BEFORE timerService, and pass it:
  ```swift
  private lazy var settingsStore = SettingsStore()
  private lazy var timerService = FocusTimerService(
      settingsStore: settingsStore,
      soundPlayer: .shared,
      ...
  )
  ```
- After creating both, sync SoundPlayerService: `SoundPlayerService.shared.syncFromSettingsStore(settingsStore)`
- Inject `.environment(settingsStore)` into both the popover content view and the MainWindow
- In `applySavedTheme()`, read from `settingsStore.appTheme` instead of `UserDefaults.standard.string(forKey: "appTheme")`

### 5. `Focally/Views/MainWindow.swift`

**Changes:**
- Remove `@AppStorage("appTheme") private var selectedTheme: ThemeChoice = .system`
- Add `@Environment(SettingsStore.self) private var settingsStore`
- Replace `selectedTheme` usage with `settingsStore.appTheme`

### 6. `Focally/Views/Settings/AppearanceSettingsView.swift`

**Changes:**
- Remove `@AppStorage("appTheme") private var selectedTheme: ThemeChoice = .system`
- Add `@Environment(SettingsStore.self) private var settingsStore`
- Create a Binding to settingsStore.appTheme that also calls `settingsStore.saveTheme()` on set:
  ```swift
  private var themeBinding: Binding<ThemeChoice> {
      Binding(
          get: { settingsStore.appTheme },
          set: { settingsStore.appTheme = $0; settingsStore.saveTheme() }
      )
  }
  ```
- Replace `selectedTheme` with `themeBinding`

### 7. `Focally/Views/Settings/GeneralSettingsView.swift`

**Changes:**
- This view currently uses local `@State` that doesn't persist. Connect it to the services:
  - Add `@Environment(FocusTimerService.self) private var timerService`
  - Add `@Environment(SoundPlayerService.self) private var soundPlayer`
  - Replace `@State private var soundEnabled` with a Binding to `soundPlayer.isEnabled`
  - Replace `@State private var selectedSound` with a Binding to `soundPlayer.workSoundName`
  - `launchAtLogin` and `showInMenuBar` can stay as `@State` (they are not yet implemented as real features, just UI placeholders)
  - Wire up the sound toggle and sound picker to actually modify the soundPlayer and save

### 8. `Focally/Views/Settings/IntegrationsSettingsView.swift`

**Changes:**
- In `completionSoundBinding(for:)`, instead of calling `soundPlayer.saveSettings()`, call `settingsStore.saveSoundSettings()`:
  - Add `@Environment(SettingsStore.self) private var settingsStore`
  - In the binding setter: set `soundPlayer.completionSoundName = newValue; settingsStore.saveSoundSettings()`

### 9. `Focally/Views/Tasks/TimerSettingsCard.swift`

**Changes:**
- This already reads from `timerService` via `@Environment(FocusTimerService.self)`. No structural change needed since timerService now delegates to settingsStore internally.
- The `autoStartBreaksBinding` already calls `timerService.updateAutoStartEnabled()` which now saves to settingsStore.

### 10. `Focally/Models/PredefinedTask.swift`

**Changes:**
- `PredefinedTaskStore` manages predefined tasks in UserDefaults with key `"predefinedTasks"`. This is task data, not app settings. Leave it as-is — do NOT merge it into SettingsStore.

## Acceptance Criteria
- [ ] `SettingsStore.swift` created as `@Observable` with all settings centralized
- [ ] `FocusTimerService` receives `SettingsStore` in init, no longer has `loadSettings()`/`saveSettings()` methods
- [ ] `SoundPlayerService` has `syncFromSettingsStore()` method, no longer has `loadSettings()`/`saveSettings()` methods
- [ ] No `@AppStorage` remains in any view — all replaced with `SettingsStore` via `@Environment`
- [ ] `AppDelegate` creates `SettingsStore` first, passes to `FocusTimerService`, injects into all views
- [ ] `applySavedTheme()` reads from `settingsStore.appTheme` not UserDefaults directly
- [ ] Changing settings in any view → services see updated values
- [ ] **Build succeeds**: `xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build 2>&1 | tail -5`

## Constraints
- Do NOT change any view's visual appearance or layout
- Do NOT change the `PredefinedTaskStore` or `PredefinedTask` model
- Keep `SoundPlayerService.shared` as a singleton — do not make it fully injected
- Keep `FocusTimerService` as `@Observable @MainActor` — it's injected via `@Environment`
- UserDefaults keys MUST stay the same for backward compatibility
- The `@Observable` macro requires Swift 5.9+ and macOS 14+
- Project uses `import Observation` explicitly (not just SwiftUI)

## Build & Test Command
```bash
cd ~/Projects/focally
xcodebuild -project Focally.xcodeproj -scheme Focally -configuration Debug build 2>&1 | tail -20
```
