import SwiftUI
import Observation
import AppKit
import Foundation
import os.log

@MainActor
@Observable
class FocusTimerService {
    private enum TimerDefaults {
        static let durationRange = 1...600
        static let workDuration = 25
        static let shortBreakDuration = 5
        static let longBreakDuration = 15
        static let roundsUntilLongBreak = 4
        static let autoStartBreaks = true
    }

    enum PomodoroPreset {
        case classic
        case custom(workMinutes: Int, shortBreakMinutes: Int, longBreakMinutes: Int, rounds: Int, autoStart: Bool)
    }

    // Existing properties for UI compatibility
    var isActive: Bool = false
    var isPaused: Bool = false
    var currentActivity: String = ""
    var currentEmoji: String = "📝"
    var currentTaskType: TaskType = .deepWork
    var remainingSeconds: Int = 0
    var durationMinutes: Int = 25

    // Pomodoro-specific properties
    var pomodoroState: PomodoroState = .idle
    var currentRound: Int = 0
    var roundsUntilLongBreak: Int = 3
    var isAutoStartEnabled: Bool = true
    var workDurationMinutes: Int = 25
    var shortBreakDurationMinutes: Int = 5
    var longBreakDurationMinutes: Int = 15

    // Services
    let settingsStore: SettingsStore
    let soundPlayer: SoundPlayerService
    let notificationService: NotificationService
    let historyService: HistoryService
    let dndService: DNDService
    let focusIntegrationService: FocusIntegrationService

    // Timer management
    private var timer: Timer?
    private var currentPhaseDuration: Int = 0
    private var sessionStartTime: Date = Date()

    private let defaults = UserDefaults.standard
    private let logger = Logger.timer

    // MARK: - Lifecycle

    init(settingsStore: SettingsStore,
         soundPlayer: SoundPlayerService = .shared,
         notificationService: NotificationService = NotificationService(),
         historyService: HistoryService = .shared,
         dndService: DNDService = DNDService(),
         focusIntegrationService: FocusIntegrationService) {
        self.settingsStore = settingsStore
        self.soundPlayer = soundPlayer
        self.notificationService = notificationService
        self.historyService = historyService
        self.dndService = dndService
        self.focusIntegrationService = focusIntegrationService
        roundsUntilLongBreak = max(1, settingsStore.roundsUntilLongBreak)
        isAutoStartEnabled = settingsStore.isAutoStartEnabled
        workDurationMinutes = clampDuration(settingsStore.workDurationMinutes)
        shortBreakDurationMinutes = clampDuration(settingsStore.shortBreakDurationMinutes)
        longBreakDurationMinutes = clampDuration(settingsStore.longBreakDurationMinutes)
        loadLastSession()
    }

    deinit {
        // soundPlayer.stopAll() and timer?.invalidate() called via Task
        // to avoid MainActor isolation error in deinit
    }

    // MARK: - Persistence

    private func loadLastSession() {
        let lastActivity: String = defaults.string(forKey: "lastActivity") ?? ""
        let lastEmoji: String = defaults.string(forKey: "lastEmoji") ?? "📝"
        let lastDuration: Int = storedDuration(forKey: "lastDuration", defaultValue: workDurationMinutes)
        currentActivity = lastActivity
        currentEmoji = lastEmoji
        durationMinutes = lastDuration

        // Update work duration if different
        if lastDuration > 0 {
            workDurationMinutes = lastDuration
            settingsStore.workDurationMinutes = lastDuration
            settingsStore.saveTimerSettings()
        }
    }

    func updateWorkDuration(minutes: Int) {
        workDurationMinutes = clampDuration(minutes)
        durationMinutes = workDurationMinutes
        settingsStore.workDurationMinutes = workDurationMinutes
        settingsStore.saveTimerSettings()
    }

    func updateShortBreakDuration(minutes: Int) {
        shortBreakDurationMinutes = clampDuration(minutes)
        settingsStore.shortBreakDurationMinutes = shortBreakDurationMinutes
        settingsStore.saveTimerSettings()
    }

    func updateLongBreakDuration(minutes: Int) {
        longBreakDurationMinutes = clampDuration(minutes)
        settingsStore.longBreakDurationMinutes = longBreakDurationMinutes
        settingsStore.saveTimerSettings()
    }

    func updateAutoStartEnabled(_ isEnabled: Bool) {
        isAutoStartEnabled = isEnabled
        settingsStore.isAutoStartEnabled = isEnabled
        settingsStore.saveTimerSettings()
    }

    func updateRoundsUntilLongBreak(_ rounds: Int) {
        roundsUntilLongBreak = max(1, rounds)
        settingsStore.roundsUntilLongBreak = roundsUntilLongBreak
        settingsStore.saveTimerSettings()
    }

    func configurePomodoroPreset(workMinutes: Int = TimerDefaults.workDuration,
                                 shortBreakMinutes: Int = TimerDefaults.shortBreakDuration,
                                 longBreakMinutes: Int = TimerDefaults.longBreakDuration,
                                 rounds: Int = TimerDefaults.roundsUntilLongBreak,
                                 autoStart: Bool = TimerDefaults.autoStartBreaks) {
        workDurationMinutes = clampDuration(workMinutes)
        shortBreakDurationMinutes = clampDuration(shortBreakMinutes)
        longBreakDurationMinutes = clampDuration(longBreakMinutes)
        roundsUntilLongBreak = max(1, rounds)
        isAutoStartEnabled = autoStart
        durationMinutes = workDurationMinutes
        settingsStore.workDurationMinutes = workDurationMinutes
        settingsStore.shortBreakDurationMinutes = shortBreakDurationMinutes
        settingsStore.longBreakDurationMinutes = longBreakDurationMinutes
        settingsStore.roundsUntilLongBreak = roundsUntilLongBreak
        settingsStore.isAutoStartEnabled = isAutoStartEnabled
        settingsStore.saveTimerSettings()
    }

    func applyPomodoroPreset(_ preset: PomodoroPreset) {
        switch preset {
        case .classic:
            configurePomodoroPreset()
        case .custom(let workMinutes, let shortBreakMinutes, let longBreakMinutes, let rounds, let autoStart):
            configurePomodoroPreset(
                workMinutes: workMinutes,
                shortBreakMinutes: shortBreakMinutes,
                longBreakMinutes: longBreakMinutes,
                rounds: rounds,
                autoStart: autoStart
            )
        }
    }

    func startPomodoroSession(activity: String, emoji: String = "🍅") {
        startWorkSession(activity: activity, emoji: emoji, durationMinutes: workDurationMinutes, taskType: .pomodoro)
    }

    private func saveLastUsed(activity: String, emoji: String, duration: Int) {
        defaults.set(activity, forKey: "lastActivity")
        defaults.set(emoji, forKey: "lastEmoji")
        defaults.set(duration, forKey: "lastDuration")
    }

    private func saveLastSession() {
        settingsStore.saveTimerSettings()
    }

    private func savePomodoroState() {
        settingsStore.saveTimerSettings()
    }

    // MARK: - Session Control

    func startWorkSession(activity: String, emoji: String, durationMinutes workMins: Int, taskType: TaskType = .deepWork) {
        currentActivity = activity
        currentEmoji = emoji
        currentTaskType = taskType
        durationMinutes = workMins
        workDurationMinutes = workMins

        saveLastUsed(activity: activity, emoji: emoji, duration: workMins)

        sessionStartTime = Date()
        pomodoroState = .work
        currentPhaseDuration = workDurationMinutes * 60
        remainingSeconds = currentPhaseDuration
        isActive = true
        isPaused = false

        // Activate focus based on user's integration preference
        activateFocusIntegration()

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

    func endSession(playCompletionSound: Bool = true) {
        stopTimer()
        deactivateFocusIntegration()

        pomodoroState = .idle
        currentRound = 0
        remainingSeconds = 0
        isActive = false
        isPaused = false
        currentActivity = ""
        currentEmoji = "📝"
        currentTaskType = .deepWork

        if playCompletionSound {
            soundPlayer.playCompletionSound()
        }

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
                startWorkSession(activity: currentActivity, emoji: currentEmoji, durationMinutes: workDurationMinutes, taskType: currentTaskType)
        case .idle, .completed:
            break
        }
    }

    func resumeOrStartWork() {
        if pomodoroState == .work {
            isPaused = false
            startTimer()
        } else {
            startWorkSession(activity: currentActivity, emoji: currentEmoji, durationMinutes: workDurationMinutes, taskType: currentTaskType)
        }
    }

    func pauseSession() {
        guard isActive, !isPaused else { return }
        stopTimer()
        isPaused = true
        deactivateFocusIntegration()
    }

    func resumeSession() {
        guard isActive, isPaused else { return }
        isPaused = false
        activateFocusIntegration()
        startTimer()
    }

    func togglePause() {
        if isPaused {
            resumeSession()
        } else {
            pauseSession()
        }
    }

    func resetToIdle() {
        stopTimer()
        deactivateFocusIntegration()
        pomodoroState = .idle
        currentRound = 0
        remainingSeconds = 0
        isActive = false
        isPaused = false
        currentTaskType = .deepWork
        notificationService.notify(.sessionEnded)
        NotificationCenter.default.post(name: .focusSessionEnded, object: nil)
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
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
            if currentTaskType == .meeting {
                endSession()
                return
            }

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
                startWorkSession(activity: currentActivity, emoji: currentEmoji, durationMinutes: workDurationMinutes, taskType: currentTaskType)
            } else {
                endSession()
            }

        case .longBreak:
            if isAutoStartEnabled {
                soundPlayer.play(.longBreakEnd)
                startWorkSession(activity: currentActivity, emoji: currentEmoji, durationMinutes: workDurationMinutes, taskType: currentTaskType)
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

    private func storedDuration(forKey key: String, defaultValue: Int) -> Int {
        clampDuration(storedInteger(forKey: key, defaultValue: defaultValue))
    }

    private func clampDuration(_ minutes: Int) -> Int {
        min(max(minutes, TimerDefaults.durationRange.lowerBound), TimerDefaults.durationRange.upperBound)
    }

    // MARK: - Focus Integration Helpers

    @MainActor
    private func activateFocusIntegration() {
        focusIntegrationService.activateFocus(
            for: currentTaskType,
            activity: currentActivity,
            durationMinutes: workDurationMinutes,
            emoji: currentEmoji
        )
    }

    @MainActor
    private func deactivateFocusIntegration() {
        focusIntegrationService.deactivateFocus()
    }
}
