import AppKit
import os.log

class SoundPlayerService: ObservableObject {
    static let shared = SoundPlayerService()

    @Published var isEnabled: Bool = true
    @Published var workSoundName: String = "Bell"
    @Published var breakSoundName: String = "Ping"
    @Published var longBreakSoundName: String = "Glass"
    @Published var soundVolume: Double = 1.0
    @Published var soundRepeatCount: Int = 2

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "SoundPlayer")
    private var activeSounds: [NSSound] = []

    let sounds = ["Bell", "Ping", "Tink", "Pop", "Purr", "Hero", "Morse", "Submarine", "Glass", "Basso", "Blow", "Bottle", "Frog", "Funk", "Sosumi"]

    enum SoundType {
        case workEnd
        case breakEnd
        case longBreakEnd
    }

    init() {
        loadSettings()
    }

    func play(_ soundType: SoundType) {
        guard isEnabled else { return }
        let soundName = resolveSoundName(for: soundType)
        let repeatCount = max(soundRepeatCount, 1)

        for i in 0..<repeatCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 1.2) { [weak self] in
                guard let self else { return }
                guard let sound = self.makeSound(named: soundName) else { return }
                sound.volume = Float(self.soundVolume)
                self.activeSounds.append(sound)
                sound.play()
            }
        }
    }

    func previewSound(named soundName: String) {
        activeSounds.forEach { $0.stop() }
        activeSounds.removeAll()
        guard let sound = makeSound(named: soundName) else { return }
        sound.volume = Float(soundVolume)
        activeSounds.append(sound)
        sound.play()
    }

    func stopAll() {
        activeSounds.forEach { $0.stop() }
        activeSounds.removeAll()
    }

    func soundURL(for soundName: String) -> URL? {
        // Check bundled sounds first
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
        // Fall back to system sounds
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
        isEnabled = defaults.bool(forKey: "soundEnabled")
        workSoundName = defaults.string(forKey: "workSoundName") ?? "Bell"
        breakSoundName = defaults.string(forKey: "breakSoundName") ?? "Ping"
        longBreakSoundName = defaults.string(forKey: "longBreakSoundName") ?? "Glass"
        soundVolume = defaults.double(forKey: "soundVolume")
        soundRepeatCount = max(defaults.object(forKey: "soundRepeatCount") as? Int ?? 2, 1)
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: "soundEnabled")
        defaults.set(workSoundName, forKey: "workSoundName")
        defaults.set(breakSoundName, forKey: "breakSoundName")
        defaults.set(longBreakSoundName, forKey: "longBreakSoundName")
        defaults.set(soundVolume, forKey: "soundVolume")
        defaults.set(soundRepeatCount, forKey: "soundRepeatCount")
    }

    private func resolveSoundName(for soundType: SoundType) -> String {
        switch soundType {
        case .workEnd: return breakSoundName
        case .breakEnd: return workSoundName
        case .longBreakEnd: return workSoundName
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
