import SwiftUI
import Combine
import UserNotifications
import AppKit

class FocusTimerService: ObservableObject {
    @Published var isActive = false
    @Published var isPaused = false
    @Published var currentActivity = ""
    @Published var currentEmoji = "📝"
    @Published var remainingSeconds: Int = 0
    @Published var durationMinutes: Int = 25

    private var session: FocusSession?
    private var timer: Timer?
    private let defaults = UserDefaults.standard

    var hasSession: Bool {
        session != nil
    }

    var remainingTimeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var remainingMinutesString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        if minutes < 1 {
            return "<1m"
        }
        if seconds > 0 {
            return "\(minutes + 1)m"
        }
        return "\(minutes)m"
    }

    var progress: Double {
        guard let session = session else { return 0 }
        return Double(session.elapsedSeconds) / Double(session.totalSeconds)
    }

    // MARK: - Start / Stop / Extend

    func startActivity(_ activity: String, emoji: String, durationMinutes: Int) {
        let session = FocusSession(activity: activity, emoji: emoji, durationMinutes: durationMinutes)
        self.session = session
        self.currentActivity = activity
        self.currentEmoji = emoji
        self.durationMinutes = durationMinutes
        self.remainingSeconds = session.remainingSeconds
        self.isActive = true
        self.isPaused = false

        saveLastUsed(activity: activity, emoji: emoji, duration: durationMinutes)
        startTimer()
        NotificationCenter.default.post(name: .focusSessionStarted, object: nil)
    }

    func endSession() {
        stopTimer()
        session = nil
        isActive = false
        isPaused = false
        remainingSeconds = 0
        NotificationCenter.default.post(name: .focusSessionEnded, object: nil)
    }

    func extendFiveMinutes() {
        remainingSeconds += 300
        if var session = session {
            session.remainingSeconds = remainingSeconds
            self.session = session
        }
    }

    func cancelSession() {
        endSession()
    }

    func pauseSession() {
        guard isActive, !isPaused else { return }
        stopTimer()
        isPaused = true
    }

    func resumeSession() {
        guard isActive, isPaused else { return }
        isPaused = false
        startTimer()
    }

    func togglePause() {
        isPaused ? resumeSession() : pauseSession()
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            endSession()
            onSessionComplete()
            return
        }
        remainingSeconds -= 1
        session?.remainingSeconds = remainingSeconds
    }

    private var activeSounds: [NSSound] = []

    private func onSessionComplete() {
        // Play sound (repeat based on settings)
        let soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        guard soundEnabled else {
            postCompletionNotification()
            return
        }

        let soundName = defaults.string(forKey: "soundName") ?? "Bell"
        let repeatCount = defaults.integer(forKey: "soundRepeatCount")
        let count = repeatCount > 0 ? repeatCount : 5  // default 5 if never saved

        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 3.5) { [weak self] in
                guard let self = self else { return }
                guard let sound = self.makeSound(named: soundName) else { return }
                self.activeSounds.append(sound)
                sound.play()
            }
        }

        postCompletionNotification()
    }

    private func makeSound(named soundName: String) -> NSSound? {
        guard let url = soundURL(for: soundName) else {
            print("[Focally] Sound not found for selection: \(soundName)")
            return nil
        }
        return NSSound(contentsOf: url, byReference: true)
    }

    private func soundURL(for soundName: String) -> URL? {
        if soundName == "Bell",
           let bundledURL = Bundle.main.url(forResource: "bell", withExtension: "aiff") {
            return bundledURL
        }

        if let bundledURL = Bundle.main.url(forResource: soundName, withExtension: "aiff") {
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

    private func postCompletionNotification() {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Focus session ended"
        content.body = currentActivity
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }

    // MARK: - Persistence

    func lastUsedActivity() -> String {
        defaults.string(forKey: "lastActivity") ?? ""
    }

    func lastUsedEmoji() -> String {
        defaults.string(forKey: "lastEmoji") ?? "📝"
    }

    func lastUsedDuration() -> Int {
        defaults.integer(forKey: "lastDuration") > 0 ? defaults.integer(forKey: "lastDuration") : 25
    }

    private func saveLastUsed(activity: String, emoji: String, duration: Int) {
        defaults.set(activity, forKey: "lastActivity")
        defaults.set(emoji, forKey: "lastEmoji")
        defaults.set(duration, forKey: "lastDuration")
    }

    deinit {
        activeSounds.forEach { $0.stop() }
        stopTimer()
    }
}
