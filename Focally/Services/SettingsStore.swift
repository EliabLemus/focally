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
        workDurationMinutes = storedInt(forKey: "workDurationMinutes", default: 25)
        shortBreakDurationMinutes = storedInt(forKey: "shortBreakDurationMinutes", default: 5)
        longBreakDurationMinutes = storedInt(forKey: "longBreakDurationMinutes", default: 15)
        roundsUntilLongBreak = storedInt(forKey: "roundsUntilLongBreak", default: 4)
        isAutoStartEnabled = defaults.object(forKey: "isAutoStartEnabled") != nil
            ? defaults.bool(forKey: "isAutoStartEnabled")
            : true

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

        if let rawValue = defaults.string(forKey: "appTheme"),
           let choice = ThemeChoice(rawValue: rawValue) {
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
        let storedValue = defaults.integer(forKey: key)
        return storedValue == 0 ? value : storedValue
    }

    private func validateCompletionSoundName(_ storedName: String?) -> String {
        guard let storedName,
              SoundPlayerService.CompletionSoundVariant(rawValue: storedName) != nil else {
            return SoundPlayerService.CompletionSoundVariant.primary.rawValue
        }
        return storedName
    }
}
