import SwiftUI
import Combine
import AppKit
import Foundation
import os.log

class FocusTimerService: ObservableObject {
    private enum TimerDefaults {
        static let durationRange = 1...600
        static let workDuration = 25
        static let shortBreakDuration = 5
        static let longBreakDuration = 15
        static let roundsUntilLongBreak = 3
        static let autoStartBreaks = true
    }

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

    // Services
    let soundPlayer: SoundPlayerService
    let notificationService: NotificationService
    let historyService: HistoryService

    // Timer management
    private var timer: Timer?
    private var currentPhaseDuration: Int = 0
    private var sessionStartTime: Date = Date()

    let defaults = UserDefaults.standard

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "FocusTimerService")

    // MARK: - Lifecycle

    init(soundPlayer: SoundPlayerService = .shared,
         notificationService: NotificationService = NotificationService(),
         historyService: HistoryService = .shared) {
        self.soundPlayer = soundPlayer
        self.notificationService = notificationService
        self.historyService = historyService
        loadSettings()
        loadLastSession()
    }

    deinit {
        saveLastSession()
        savePomodoroState()
        soundPlayer.stopAll()
        timer?.invalidate()
    }

    // MARK: - Settings

    private func loadSettings() {
        pomodoroState = PomodoroState(rawValue: defaults.string(forKey: "pomodoroState") ?? "idle") ?? .idle
        currentRound = defaults.integer(forKey: "currentRound")
        roundsUntilLongBreak = storedInteger(forKey: "roundsUntilLongBreak", defaultValue: TimerDefaults.roundsUntilLongBreak)
        isAutoStartEnabled = storedBool(forKey: "isAutoStartEnabled", defaultValue: TimerDefaults.autoStartBreaks)
        workDurationMinutes = storedDuration(forKey: "workDurationMinutes", defaultValue: TimerDefaults.workDuration)
        shortBreakDurationMinutes = storedDuration(forKey: "shortBreakDurationMinutes", defaultValue: TimerDefaults.shortBreakDuration)
        longBreakDurationMinutes = storedDuration(forKey: "longBreakDurationMinutes", defaultValue: TimerDefaults.longBreakDuration)
    }

    private func saveSettings() {
        defaults.set(pomodoroState.rawValue, forKey: "pomodoroState")
        defaults.set(currentRound, forKey: "currentRound")
        defaults.set(roundsUntilLongBreak, forKey: "roundsUntilLongBreak")
        defaults.set(isAutoStartEnabled, forKey: "isAutoStartEnabled")
        defaults.set(workDurationMinutes, forKey: "workDurationMinutes")
        defaults.set(shortBreakDurationMinutes, forKey: "shortBreakDurationMinutes")
        defaults.set(longBreakDurationMinutes, forKey: "longBreakDurationMinutes")
    }

    // MARK: - Persistence

    private func loadLastSession() {
        let lastActivity = defaults.string(forKey: "lastActivity") ?? ""
        let lastEmoji = defaults.string(forKey: "lastEmoji") ?? "📝"
        let lastDuration = storedDuration(forKey: "lastDuration", defaultValue: workDurationMinutes)

        currentActivity = lastActivity
        currentEmoji = lastEmoji
        durationMinutes = lastDuration

        // Update work duration if different
        if lastDuration > 0 {
            workDurationMinutes = lastDuration
            saveSettings()
        }
    }

    func updateWorkDuration(minutes: Int) {
        workDurationMinutes = clampDuration(minutes)
        durationMinutes = workDurationMinutes
        saveSettings()
    }

    func updateShortBreakDuration(minutes: Int) {
        shortBreakDurationMinutes = clampDuration(minutes)
        saveSettings()
    }

    func updateLongBreakDuration(minutes: Int) {
        longBreakDurationMinutes = clampDuration(minutes)
        saveSettings()
    }

    func updateAutoStartEnabled(_ isEnabled: Bool) {
        isAutoStartEnabled = isEnabled
        saveSettings()
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

        sessionStartTime = Date()
        pomodoroState = .work
        currentPhaseDuration = workDurationMinutes * 60
        remainingSeconds = currentPhaseDuration
        isActive = true
        isPaused = false

        // Auto-activate DND when session starts
        if let dndService = (NSApp.delegate as? AppDelegate)?.dndService {
            dndService.activateDND()
        }

        startTimer()
        notificationService.notify(.workSessionStarted(activity: currentActivity, durationMinutes: workDurationMinutes))

        NotificationCenter.default.post(name: .focusSessionStarted, object: nil)
    }

    func startShortBreak() {
        pomodoroState = .shortBreak
        currentPhaseDuration = shortBreakDurationMinutes * 60
        remainingSeconds = currentPhaseDuration
        isPaused = false

        startTimer()
        notificationService.notify(.breakStarted)

        NotificationCenter.default.post(name: .focusSessionEnded, object: nil)
    }

    func startLongBreak() {
        pomodoroState = .longBreak
        currentPhaseDuration = longBreakDurationMinutes * 60
        remainingSeconds = currentPhaseDuration
        isPaused = false

        startTimer()
        notificationService.notify(.longBreakStarted)

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

        notificationService.notify(.sessionEnded)
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
        notificationService.notify(.sessionEnded)
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
                notificationService.notify(.workAlmostOver(activity: currentActivity))
            }
        }
    }

    private func handlePhaseComplete() {
        stopTimer()

        switch pomodoroState {
        case .work:
            // Record completed work session
                historyService.recordWorkSession(
                activity: currentActivity,
                emoji: currentEmoji,
                durationMinutes: workDurationMinutes,
                round: currentRound,
                startTime: sessionStartTime,
                endTime: Date()
            )
            currentRound += 1
            soundPlayer.play(.workEnd)

            // Check if long break is due
            if currentRound >= roundsUntilLongBreak {
                currentRound = 0 // Reset round counter after long break
                startLongBreak()
            } else {
                startShortBreak()
            }

        case .shortBreak:
            if isAutoStartEnabled {
                soundPlayer.play(.breakEnd)
                startWorkSession(activity: currentActivity, emoji: currentEmoji, durationMinutes: workDurationMinutes)
            } else {
                endSession()
            }

        case .longBreak:
            if isAutoStartEnabled {
                soundPlayer.play(.longBreakEnd)
                startWorkSession(activity: currentActivity, emoji: currentEmoji, durationMinutes: workDurationMinutes)
            } else {
                endSession()
            }

        case .idle, .completed:
            break
        }
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

    private func storedInteger(forKey key: String, defaultValue: Int) -> Int {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return defaults.integer(forKey: key)
    }

    private func storedBool(forKey key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return defaults.bool(forKey: key)
    }

    private func storedDuration(forKey key: String, defaultValue: Int) -> Int {
        clampDuration(storedInteger(forKey: key, defaultValue: defaultValue))
    }

    private func clampDuration(_ minutes: Int) -> Int {
        min(max(minutes, TimerDefaults.durationRange.lowerBound), TimerDefaults.durationRange.upperBound)
    }
}
