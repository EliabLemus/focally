import SwiftUI
import Combine
import UserNotifications
import AppKit
import Foundation

class FocusTimerService: ObservableObject {
    // Existing properties for UI compatibility
    @Published var isActive = false
    @Published var isPaused = false
    @Published var currentActivity = ""
    @Published var currentEmoji = "📝"
    @Published var remainingSeconds: Int = 0
    @Published var durationMinutes: Int = 25

    // Pomodoro-specific properties
    @Published var pomodoroState: PomodoroState = .idle
    @Published var currentRound: Int = 0
    @Published var roundsUntilLongBreak: Int = 3
    @Published var isAutoStartEnabled: Bool = true
    @Published var workDurationMinutes: Int = 25
    @Published var shortBreakDurationMinutes: Int = 5
    @Published var longBreakDurationMinutes: Int = 15

    // Sound preferences
    @Published var soundEnabled: Bool = true
    @Published var workSoundName: String = "Bell"
    @Published var breakSoundName: String = "Ping"
    @Published var longBreakSoundName: String = "Glass"
    @Published var soundVolume: Double = 1.0

    // Timer management
    private var timer: Timer?
    private var currentPhaseDuration: Int = 0

    // Active sounds
    private var activeSounds: [NSSound] = []
    private var soundRepeatCount: Int = 5

    // History
    private let historyDirectory: URL = {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let focallyDir = supportDir.appendingPathComponent("Focally", isDirectory: true)
        let historyDir = focallyDir.appendingPathComponent("history", isDirectory: true)

        if !FileManager.default.fileExists(atPath: historyDir.path) {
            try? FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
        }

        return historyDir
    }()

    let defaults = UserDefaults.standard

    // MARK: - Lifecycle

    init() {
        loadSettings()
        loadLastSession()
    }

    deinit {
        saveLastSession()
        savePomodoroState()
        activeSounds.forEach { $0.stop() }
        timer?.invalidate()
    }

    // MARK: - Settings

    private func loadSettings() {
        pomodoroState = PomodoroState(rawValue: defaults.string(forKey: "pomodoroState") ?? "idle") ?? .idle
        currentRound = defaults.integer(forKey: "currentRound")
        roundsUntilLongBreak = defaults.integer(forKey: "roundsUntilLongBreak")
        isAutoStartEnabled = defaults.bool(forKey: "isAutoStartEnabled")
        workDurationMinutes = defaults.integer(forKey: "workDurationMinutes")
        shortBreakDurationMinutes = defaults.integer(forKey: "shortBreakDurationMinutes")
        longBreakDurationMinutes = defaults.integer(forKey: "longBreakDurationMinutes")
        soundEnabled = defaults.bool(forKey: "soundEnabled")
        workSoundName = defaults.string(forKey: "workSoundName") ?? "Bell"
        breakSoundName = defaults.string(forKey: "breakSoundName") ?? "Ping"
        longBreakSoundName = defaults.string(forKey: "longBreakSoundName") ?? "Glass"
        soundVolume = defaults.double(forKey: "soundVolume")
        soundRepeatCount = max(defaults.object(forKey: "soundRepeatCount") as? Int ?? 5, 1)
    }

    private func saveSettings() {
        defaults.set(pomodoroState.rawValue, forKey: "pomodoroState")
        defaults.set(currentRound, forKey: "currentRound")
        defaults.set(roundsUntilLongBreak, forKey: "roundsUntilLongBreak")
        defaults.set(isAutoStartEnabled, forKey: "isAutoStartEnabled")
        defaults.set(workDurationMinutes, forKey: "workDurationMinutes")
        defaults.set(shortBreakDurationMinutes, forKey: "shortBreakDurationMinutes")
        defaults.set(longBreakDurationMinutes, forKey: "longBreakDurationMinutes")
        defaults.set(soundEnabled, forKey: "soundEnabled")
        defaults.set(workSoundName, forKey: "workSoundName")
        defaults.set(breakSoundName, forKey: "breakSoundName")
        defaults.set(longBreakSoundName, forKey: "longBreakSoundName")
        defaults.set(soundVolume, forKey: "soundVolume")
    }

    // MARK: - Persistence

    private func loadLastSession() {
        let lastActivity = defaults.string(forKey: "lastActivity") ?? ""
        let lastEmoji = defaults.string(forKey: "lastEmoji") ?? "📝"
        let lastDuration = defaults.integer(forKey: "lastDuration") > 0 ? defaults.integer(forKey: "lastDuration") : 25

        currentActivity = lastActivity
        currentEmoji = lastEmoji
        durationMinutes = lastDuration

        // Update work duration if different
        if lastDuration > 0 {
            workDurationMinutes = lastDuration
            saveSettings()
        }
    }

    private func saveLastUsed(activity: String, emoji: String, duration: Int) {
        defaults.set(activity, forKey: "lastActivity")
        defaults.set(emoji, forKey: "lastEmoji")
        defaults.set(duration, forKey: "lastDuration")
    }

    private func saveLastSession() {
        saveSettings()
    }

    private func savePomodoroState() {
        saveSettings()
    }

    // MARK: - Session Control

    func startWorkSession(activity: String, emoji: String, durationMinutes workMins: Int) {
        currentActivity = activity
        currentEmoji = emoji
        durationMinutes = workMins
        workDurationMinutes = workMins

        saveLastUsed(activity: activity, emoji: emoji, duration: workMins)

        pomodoroState = .work
        currentPhaseDuration = workDurationMinutes * 60
        remainingSeconds = currentPhaseDuration
        isActive = true
        isPaused = false

        startTimer()
        playSound(.workStart)
        postNotification(.workSessionStarted)

        NotificationCenter.default.post(name: .focusSessionStarted, object: nil)
    }

    func startShortBreak() {
        pomodoroState = .shortBreak
        currentPhaseDuration = shortBreakDurationMinutes * 60
        remainingSeconds = currentPhaseDuration
        isPaused = false

        startTimer()
        playSound(.breakStart)
        postNotification(.breakStarted)

        NotificationCenter.default.post(name: .focusSessionEnded, object: nil)
    }

    func startLongBreak() {
        pomodoroState = .longBreak
        currentPhaseDuration = longBreakDurationMinutes * 60
        remainingSeconds = currentPhaseDuration
        isPaused = false

        startTimer()
        playSound(.longBreakStart)
        postNotification(.longBreakStarted)

        NotificationCenter.default.post(name: .focusSessionEnded, object: nil)
    }

    func endSession() {
        stopTimer()
        pomodoroState = .idle
        currentRound = 0
        remainingSeconds = 0
        isActive = false
        isPaused = false
        currentActivity = ""
        currentEmoji = "📝"

        postNotification(.sessionEnded)
        NotificationCenter.default.post(name: .focusSessionEnded, object: nil)
    }

    func skipToNextPhase() {
        switch pomodoroState {
        case .work:
            currentRound += 1
            if currentRound >= roundsUntilLongBreak {
                startLongBreak()
            } else {
                startShortBreak()
            }
        case .shortBreak, .longBreak:
            startWorkSession(activity: currentActivity, emoji: currentEmoji, durationMinutes: workDurationMinutes)
        case .idle, .completed:
            break
        }
    }

    func resumeOrStartWork() {
        if pomodoroState == .work {
            isPaused = false
            startTimer()
        } else {
            startWorkSession(activity: currentActivity, emoji: currentEmoji, durationMinutes: workDurationMinutes)
        }
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

    func resetToIdle() {
        stopTimer()
        pomodoroState = .idle
        currentRound = 0
        remainingSeconds = 0
        isActive = false
        isPaused = false
        postNotification(.sessionEnded)
        NotificationCenter.default.post(name: .focusSessionEnded, object: nil)
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
            handlePhaseComplete()
            return
        }

        remainingSeconds -= 1

        if pomodoroState == .work {
            // Check if work session is almost over (5 min remaining)
            if remainingSeconds == currentPhaseDuration - 300 {
                postNotification(.workAlmostOver)
            }
        }
    }

    private func handlePhaseComplete() {
        stopTimer()

        switch pomodoroState {
        case .work:
            // Record completed work session
            recordWorkSession()
            currentRound += 1

            // Check if long break is due
            if currentRound >= roundsUntilLongBreak {
                currentRound = 0 // Reset round counter after long break
                startLongBreak()
            } else {
                startShortBreak()
            }

        case .shortBreak:
            if isAutoStartEnabled {
                startWorkSession(activity: currentActivity, emoji: currentEmoji, durationMinutes: workDurationMinutes)
            } else {
                endSession()
            }

        case .longBreak:
            if isAutoStartEnabled {
                startWorkSession(activity: currentActivity, emoji: currentEmoji, durationMinutes: workDurationMinutes)
            } else {
                endSession()
            }

        case .idle, .completed:
            break
        }
    }

    // MARK: - Sound System

    private func playSound(_ soundType: SoundType) {
        guard soundEnabled else { return }

        let soundName: String
        switch soundType {
        case .workStart:
            soundName = workSoundName
        case .workEnd:
            soundName = breakSoundName
        case .breakStart:
            soundName = breakSoundName
        case .breakEnd:
            soundName = workSoundName
        case .longBreakStart:
            soundName = longBreakSoundName
        case .longBreakEnd:
            soundName = breakSoundName
        }

        let repeatCount = max(soundRepeatCount, 1)
        for i in 0..<repeatCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.8) { [weak self] in
                guard let self = self else { return }
                guard let sound = self.makeSound(named: soundName) else { return }
                sound.volume = Float(self.soundVolume)
                self.activeSounds.append(sound)
                sound.play()
            }
        }
    }

    private enum SoundType {
        case workStart
        case workEnd
        case breakStart
        case breakEnd
        case longBreakStart
        case longBreakEnd
    }

    private func makeSound(named soundName: String) -> NSSound? {
        guard let url = soundURL(for: soundName) else {
            print("[Focally] Sound not found: \(soundName)")
            return nil
        }
        return NSSound(contentsOf: url, byReference: true)
    }

    private func soundURL(for soundName: String) -> URL? {
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

    // MARK: - History Storage

    private func recordWorkSession() {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: today)

        let historyFile = historyDirectory.appendingPathComponent("\(dateKey).json")

        var history: [PomodoroHistoryEntry] = []

        // Load existing history
        if let data = try? Data(contentsOf: historyFile),
           let decoded = try? JSONDecoder().decode([PomodoroHistoryEntry].self, from: data) {
            history = decoded
        }

        // Create new entry
        let entry = PomodoroHistoryEntry(
            id: UUID(),
            activity: currentActivity,
            emoji: currentEmoji,
            durationMinutes: workDurationMinutes,
            startTime: Date(),
            endTime: Date(),
            phase: .work,
            round: currentRound,
            pomodoroState: .work
        )

        history.append(entry)

        // Save back to file
        if let encoded = try? JSONEncoder().encode(history) {
            try? encoded.write(to: historyFile)
        }
    }

    struct PomodoroHistoryEntry: Codable {
        let id: UUID
        let activity: String
        let emoji: String
        let durationMinutes: Int
        let startTime: Date
        let endTime: Date
        let phase: PomodoroPhase
        let round: Int
        let pomodoroState: PomodoroState

        enum PomodoroPhase: String, Codable {
            case work
            case shortBreak
            case longBreak
        }
    }

    // MARK: - Notifications

    private enum NotificationName {
        case workSessionStarted
        case workAlmostOver
        case breakStarted
        case longBreakStarted
        case sessionEnded
    }

    private func postNotification(_ name: NotificationName) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()

        switch name {
        case .workSessionStarted:
            content.title = "Focus Session Started"
            content.body = "\(currentActivity) - \(workDurationMinutes) min"

        case .workAlmostOver:
            content.title = "Almost Time for Break!"
            content.body = "Your \(currentActivity) session is ending in 5 minutes"

        case .breakStarted:
            content.title = "Break Time"
            content.body = "Time for a short break. Stay relaxed."

        case .longBreakStarted:
            content.title = "Long Break Time"
            content.body = "Great work! Time for a longer break."

        case .sessionEnded:
            content.title = "Session Ended"
            content.body = "Your focus session has finished"
        }

        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }

    // MARK: - Computed Properties

    var hasSession: Bool {
        pomodoroState != .idle && pomodoroState != .completed
    }

    var isWork: Bool {
        pomodoroState == .work
    }

    var isBreak: Bool {
        pomodoroState == .shortBreak || pomodoroState == .longBreak
    }

    var isLongBreak: Bool {
        pomodoroState == .longBreak
    }

    var progress: Double {
        guard currentPhaseDuration > 0 else { return 0 }
        return Double(currentPhaseDuration - remainingSeconds) / Double(currentPhaseDuration)
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

    var stateIcon: String {
        switch pomodoroState {
        case .idle:
            return "⏸️"
        case .work:
            return "🟢"
        case .shortBreak:
            return "🟡"
        case .longBreak:
            return "🔵"
        case .completed:
            return "✅"
        }
    }

    var phaseName: String {
        switch pomodoroState {
        case .idle:
            return "Idle"
        case .work:
            return "Focus"
        case .shortBreak:
            return "Short Break"
        case .longBreak:
            return "Long Break"
        case .completed:
            return "Completed"
        }
    }

    var isAutoStartingNextPhase: Bool {
        isAutoStartEnabled && pomodoroState != .idle && pomodoroState != .completed
    }
}
