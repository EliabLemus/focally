import AppKit
import os.log

final class SoundPlayerService: ObservableObject {
    static let shared = SoundPlayerService()

    private enum DefaultsKey {
        static let isEnabled = "soundEnabled"
        static let workSoundName = "workSoundName"
        static let breakSoundName = "breakSoundName"
        static let longBreakSoundName = "longBreakSoundName"
        static let completionSoundName = "completionSoundName"
        static let soundVolume = "soundVolume"
        static let soundRepeatCount = "soundRepeatCount"
    }

    enum CompletionSoundVariant: String, CaseIterable, Identifiable {
        case primary = "confirmation_003"
        case soft = "glass_005"
        case alt = "pluck_002"

        var id: String { rawValue }
    }

    @Published var isEnabled: Bool = true
    @Published var workSoundName: String = "Bell"
    @Published var breakSoundName: String = "Ping"
    @Published var longBreakSoundName: String = "Glass"
    @Published var completionSoundName: String = CompletionSoundVariant.primary.rawValue
    @Published var soundVolume: Double = 1.0
    @Published var soundRepeatCount: Int = 2

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "SoundPlayer")
    private var activeSounds: [NSSound] = []

    let sounds = ["Bell", "Ping", "Tink", "Pop", "Purr", "Hero", "Morse", "Submarine", "Glass", "Basso", "Blow", "Bottle", "Frog", "Funk", "Sosumi", CompletionSoundVariant.primary.rawValue, CompletionSoundVariant.soft.rawValue, CompletionSoundVariant.alt.rawValue]

    enum SoundType {
        case workEnd
        case breakEnd
        case longBreakEnd
        case sessionComplete
    }

    init() {
        loadSettings()
    }

    func play(_ soundType: SoundType) {
        guard isEnabled else { return }
        let soundName = resolveSoundName(for: soundType)
        let repeatCount = soundType == .sessionComplete ? 1 : max(soundRepeatCount, 1)
        playSound(named: soundName, repeatCount: repeatCount, interSoundDelay: 1.2)
    }

    func playCompletionSound() {
        play(.sessionComplete)
    }

    func previewSound(named soundName: String) {
        activeSounds.forEach { $0.stop() }
        activeSounds.removeAll()
        playSound(named: soundName, repeatCount: 1, interSoundDelay: 0)
    }

    func stopAll() {
        activeSounds.forEach { $0.stop() }
        activeSounds.removeAll()
    }

    func soundURL(for soundName: String) -> URL? {
        if soundName == "Bell",
           let bundledURL = Bundle.main.url(forResource: "bell", withExtension: "aiff") {
            return bundledURL
        }
        if let bundledURL = Bundle.main.url(forResource: soundName, withExtension: "aiff") {
            return bundledURL
        }
        if let bundledURL = Bundle.main.url(forResource: soundName.lowercased(), withExtension: "wav") {
            return bundledURL
        }

        let systemSoundURL = URL(fileURLWithPath: "/System/Library/Sounds")
            .appendingPathComponent(soundName)
            .appendingPathExtension("aiff")
        if FileManager.default.fileExists(atPath: systemSoundURL.path) {
            return systemSoundURL
        }
        return nil
    }

    func loadSettings() {
        let defaults = UserDefaults.standard
        isEnabled = storedBool(forKey: DefaultsKey.isEnabled, defaultValue: true)
        workSoundName = defaults.string(forKey: DefaultsKey.workSoundName) ?? "Bell"
        breakSoundName = defaults.string(forKey: DefaultsKey.breakSoundName) ?? "Ping"
        longBreakSoundName = defaults.string(forKey: DefaultsKey.longBreakSoundName) ?? "Glass"
        completionSoundName = validateCompletionSoundName(defaults.string(forKey: DefaultsKey.completionSoundName))
        soundVolume = storedDouble(forKey: DefaultsKey.soundVolume, defaultValue: 1.0)
        soundRepeatCount = max(defaults.object(forKey: DefaultsKey.soundRepeatCount) as? Int ?? 2, 1)
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: DefaultsKey.isEnabled)
        defaults.set(workSoundName, forKey: DefaultsKey.workSoundName)
        defaults.set(breakSoundName, forKey: DefaultsKey.breakSoundName)
        defaults.set(longBreakSoundName, forKey: DefaultsKey.longBreakSoundName)
        defaults.set(completionSoundName, forKey: DefaultsKey.completionSoundName)
        defaults.set(soundVolume, forKey: DefaultsKey.soundVolume)
        defaults.set(soundRepeatCount, forKey: DefaultsKey.soundRepeatCount)
    }

    private func resolveSoundName(for soundType: SoundType) -> String {
        switch soundType {
        case .workEnd: return breakSoundName
        case .breakEnd: return workSoundName
        case .longBreakEnd: return workSoundName
        case .sessionComplete: return completionSoundName
        }
    }

    private func validateCompletionSoundName(_ storedName: String?) -> String {
        guard let storedName, CompletionSoundVariant(rawValue: storedName) != nil else {
            return CompletionSoundVariant.primary.rawValue
        }
        return storedName
    }

    private func storedBool(forKey key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func storedDouble(forKey key: String, defaultValue: Double) -> Double {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }
        return UserDefaults.standard.double(forKey: key)
    }

    private func playSound(named soundName: String, repeatCount: Int, interSoundDelay: TimeInterval) {
        guard isEnabled else { return }

        for i in 0..<repeatCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interSoundDelay) { [weak self] in
                guard let self else { return }
                guard let sound = self.makeSound(named: soundName) else { return }
                sound.volume = Float(self.soundVolume)
                self.activeSounds.append(sound)
                sound.play()
            }
        }
    }

    private func makeSound(named soundName: String) -> NSSound? {
        guard let url = soundURL(for: soundName) else {
            logger.warning("Sound not found: \(soundName, privacy: .public)")
            return nil
        }
        return NSSound(contentsOf: url, byReference: true)
    }
}
