import Foundation
import Observation

@Observable
final class SettingsStore {
    var soundEnabled = true
    var soundVolume: Double = 1.0
    var soundRepeatCount = 2
    var workSoundName = "Bell"
    var breakSoundName = "Ping"
    var longBreakSoundName = "Glass"
    var completionSoundName = "confirmation_003"

    var appTheme: ThemeChoice = .system

    private let defaults = UserDefaults.standard

    init() {
        loadFromDefaults()
    }

    func loadFromDefaults() {
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
        completionSoundName = validateCompletionSoundName(defaults.string(forKey: "completionSoundName"))

        if let rawValue = defaults.string(forKey: "appTheme"),
           let choice = ThemeChoice(rawValue: rawValue) {
            appTheme = choice
        }
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

    private func validateCompletionSoundName(_ storedName: String?) -> String {
        guard let storedName,
              SoundPlayerService.CompletionSoundVariant(rawValue: storedName) != nil else {
            return SoundPlayerService.CompletionSoundVariant.primary.rawValue
        }
        return storedName
    }
}
