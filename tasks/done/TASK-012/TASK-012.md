# TASK-012: Extract SettingsStore — Single Source of Truth for Settings

## Status: TODO

## Date: 2026-05-01

## Objective
Create a centralized `SettingsStore` that owns ALL app settings. Currently, settings are scattered across `FocusTimerService.loadSettings()/saveSettings()`, `SettingsView`'s `@AppStorage` properties, and draft `@State` variables. This creates a dual source of truth where `@AppStorage` and `@State` can get out of sync.

## Files to Create
- `Focally/Services/SettingsStore.swift`

## Files to Modify
- `Focally/Services/FocusTimerService.swift` — read from SettingsStore instead of direct UserDefaults
- `Focally/Views/SettingsView.swift` — use SettingsStore instead of @AppStorage + @State drafts
- `Focally/Services/SoundPlayerService.swift` — read from SettingsStore
- `Focally/OnItFocusApp.swift` — create SettingsStore, inject into services

## Detailed Specification

### New File: `SettingsStore.swift`

```swift
import Foundation
import Combine

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    // Timer durations
    @Published var workDurationMinutes: Int = 25
    @Published var shortBreakDurationMinutes: Int = 5
    @Published var longBreakDurationMinutes: Int = 15
    
    // Custom durations (for duration picker in ActivityInputView)
    @Published var customDurations: [Int] = [25, 45, 60, 90]
    
    // Pomodoro
    @Published var roundsUntilLongBreak: Int = 3
    @Published var isAutoStartEnabled: Bool = true
    
    // Sound
    @Published var soundEnabled: Bool = true
    @Published var soundVolume: Double = 1.0
    @Published var soundRepeatCount: Int = 2
    @Published var workSoundName: String = "Bell"
    @Published var breakSoundName: String = "Ping"
    @Published var longBreakSoundName: String = "Glass"
    
    // Appearance
    @Published var useSystemTheme: Bool = true
    
    // Slack
    @Published var slackStatusEmoji: String = ":hourglass_flowing_sand:"
    
    // Predefined tasks
    @Published var predefinedTasks: [PredefinedTask] = []
    
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "SettingsStore")
    
    init() {
        loadFromDefaults()
    }
    
    func loadFromDefaults() {
        workDurationMinutes = defaults.integer(forKey: "workDurationMinutes")
        if workDurationMinutes == 0 { workDurationMinutes = 25; defaults.set(25, forKey: "workDurationMinutes") }
        
        shortBreakDurationMinutes = defaults.integer(forKey: "shortBreakDurationMinutes")
        if shortBreakDurationMinutes == 0 { shortBreakDurationMinutes = 5; defaults.set(5, forKey: "shortBreakDurationMinutes") }
        
        longBreakDurationMinutes = defaults.integer(forKey: "longBreakDurationMinutes")
        if longBreakDurationMinutes == 0 { longBreakDurationMinutes = 15; defaults.set(15, forKey: "longBreakDurationMinutes") }
        
        roundsUntilLongBreak = defaults.integer(forKey: "roundsUntilLongBreak")
        if roundsUntilLongBreak == 0 { roundsUntilLongBreak = 3; defaults.set(3, forKey: "roundsUntilLongBreak") }
        
        isAutoStartEnabled = defaults.bool(forKey: "isAutoStartEnabled")
        soundEnabled = defaults.bool(forKey: "soundEnabled")
        soundVolume = defaults.double(forKey: "soundVolume")
        soundRepeatCount = max(defaults.object(forKey: "soundRepeatCount") as? Int ?? 2, 1)
        workSoundName = defaults.string(forKey: "workSoundName") ?? "Bell"
        breakSoundName = defaults.string(forKey: "breakSoundName") ?? "Ping"
        longBreakSoundName = defaults.string(forKey: "longBreakSoundName") ?? "Glass"
        useSystemTheme = defaults.bool(forKey: "useSystemTheme")
        slackStatusEmoji = defaults.string(forKey: SlackService.statusEmojiDefaultsKey) ?? SlackService.defaultStatusEmoji
        
        // Custom durations
        if let data = defaults.data(forKey: "customDurations"),
           let durations = try? JSONDecoder().decode([Int].self, from: data) {
            customDurations = durations
        }
        
        // Predefined tasks
        if let data = defaults.data(forKey: PredefinedTask.defaultsKey),
           let tasks = try? JSONDecoder().decode([PredefinedTask].self, from: data) {
            predefinedTasks = tasks
        }
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
        defaults.set(slackStatusEmoji, forKey: SlackService.statusEmojiDefaultsKey)
        
        if let data = try? JSONEncoder().encode(customDurations) {
            defaults.set(data, forKey: "customDurations")
        }
        
        if let data = try? JSONEncoder().encode(predefinedTasks) {
            defaults.set(data, forKey: PredefinedTask.defaultsKey)
        }
        
        logger.info("Settings saved to UserDefaults")
    }
    
    // Convenience: create a draft copy for SettingsView
    func makeDraft() -> SettingsDraft {
        SettingsDraft(
            workDurationMinutes: workDurationMinutes,
            shortBreakDurationMinutes: shortBreakDurationMinutes,
            longBreakDurationMinutes: longBreakDurationMinutes,
            customDurations: customDurations,
            roundsUntilLongBreak: roundsUntilLongBreak,
            isAutoStartEnabled: isAutoStartEnabled,
            soundEnabled: soundEnabled,
            soundVolume: soundVolume,
            soundRepeatCount: soundRepeatCount,
            workSoundName: workSoundName,
            breakSoundName: breakSoundName,
            longBreakSoundName: longBreakSoundName,
            useSystemTheme: useSystemTheme,
            slackStatusEmoji: slackStatusEmoji,
            predefinedTasks: predefinedTasks
        )
    }
    
    func applyDraft(_ draft: SettingsDraft) {
        workDurationMinutes = draft.workDurationMinutes
        shortBreakDurationMinutes = draft.shortBreakDurationMinutes
        longBreakDurationMinutes = draft.longBreakDurationMinutes
        customDurations = draft.customDurations
        roundsUntilLongBreak = draft.roundsUntilLongBreak
        isAutoStartEnabled = draft.isAutoStartEnabled
        soundEnabled = draft.soundEnabled
        soundVolume = draft.soundVolume
        soundRepeatCount = draft.soundRepeatCount
        workSoundName = draft.workSoundName
        breakSoundName = draft.breakSoundName
        longBreakSoundName = draft.longBreakSoundName
        useSystemTheme = draft.useSystemTheme
        slackStatusEmoji = draft.slackStatusEmoji
        predefinedTasks = draft.predefinedTasks
        saveToDefaults()
    }
}

// Immutable value type for SettingsView drafts
struct SettingsDraft: Equatable {
    var workDurationMinutes: Int
    var shortBreakDurationMinutes: Int
    var longBreakDurationMinutes: Int
    var customDurations: [Int]
    var roundsUntilLongBreak: Int
    var isAutoStartEnabled: Bool
    var soundEnabled: Bool
    var soundVolume: Double
    var soundRepeatCount: Int
    var workSoundName: String
    var breakSoundName: String
    var longBreakSoundName: String
    var useSystemTheme: Bool
    var slackStatusEmoji: String
    var predefinedTasks: [PredefinedTask]
}
```

### Changes to SettingsView.swift

**Remove**:
- All `@AppStorage` properties (20+ of them)
- All corresponding `@State` draft variables (20+ of them)
- `loadSettings()` method (replaced by `settingsStore.makeDraft()`)
- `saveSettings()` method (replaced by `settingsStore.applyDraft()`)
- `hasUnsavedChanges` computed property (now `draft != settingsStore.makeDraft()`)
- `decodedDurations()`, `encode()` helpers
- `loadTasks()`, `saveTasks()` helpers

**Add**:
- `@EnvironmentObject var settingsStore: SettingsStore`
- `@State private var draft = SettingsDraft(...)` initialized from `settingsStore.makeDraft()` on appear
- `hasUnsavedChanges` becomes `draft != settingsStore.makeDraft()`
- `saveSettings()` becomes `settingsStore.applyDraft(draft)`

**Keep**:
- `@EnvironmentObject var slackService: SlackService`
- `@EnvironmentObject var calendarService: GoogleCalendarService`
- `@State` for secrets drafts (Slack token, Google credentials — these go to Keychain, not UserDefaults)
- `newDuration`, `newTaskName`, `newTaskEmoji` input states
- `onSave` callback
- UI code (tabs, views) — just wire up to `draft` instead of individual @State

### Changes to FocusTimerService

- Remove `loadSettings()` and `saveSettings()` methods
- Read initial values from `SettingsStore.shared` in init
- When settings change (observed via `settingsStore.objectWillChange`), update local timer properties
- `workDurationMinutes` etc. become mirrors of `settingsStore.workDurationMinutes`

### Changes to OnItFocusApp.swift

- Create `let settingsStore = SettingsStore()` in AppDelegate
- Pass as `.environmentObject(settingsStore)` to both popover and settings window

## Acceptance Criteria
- [ ] `SettingsStore.swift` created with all settings centralized
- [ ] `SettingsView` uses `SettingsDraft` pattern — no more dual @AppStorage/@State
- [ ] `FocusTimerService` reads from SettingsStore, not direct UserDefaults
- [ ] Changing settings and clicking Save persists correctly
- [ ] Reopening Settings shows current values (no stale drafts)
- [ ] Build succeeds
