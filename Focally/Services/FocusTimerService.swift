import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class FocusTimerService {
    static private(set) weak var shared: FocusTimerService?

    private enum TimerDefaults {
        static let durationRange = 1...600
    }

    var isActive = false
    var isPaused = false
    var currentActivity = ""
    var currentStatusText = ""
    var currentEmoji = ":brain:"
    var currentMode: FocusMode?
    var remainingSeconds = 0
    var durationMinutes = 25

    var pomodoroState: PomodoroState = .idle
    var currentRound = 0
    var pomodoroRounds = 1
    var workDurationMinutes = 25
    var shortBreakDurationMinutes = 5
    var longBreakDurationMinutes = 15

    /// Tracks when the current session was started (for metrics recording).
    private var sessionStartTime: Date?

    let settingsStore: SettingsStore
    let soundPlayer: SoundPlayerService
    let notificationService: NotificationService
    let dndService: DNDService
    let focusIntegrationService: FocusIntegrationService

    private var timer: Timer?
    private var currentPhaseDuration = 0
    private let defaults = UserDefaults.standard

    init(settingsStore: SettingsStore,
         soundPlayer: SoundPlayerService = .shared,
         notificationService: NotificationService = NotificationService(),
         dndService: DNDService = DNDService.shared,
         focusIntegrationService: FocusIntegrationService) {
        self.settingsStore = settingsStore
        self.soundPlayer = soundPlayer
        self.notificationService = notificationService
        self.dndService = dndService
        self.focusIntegrationService = focusIntegrationService
        Self.shared = self
        loadLastSession()
    }

    private func loadLastSession() {
        currentActivity = defaults.string(forKey: "lastActivity") ?? ""
        currentStatusText = defaults.string(forKey: "lastStatusText") ?? ""
        currentEmoji = defaults.string(forKey: "lastEmoji") ?? ":brain:"
        durationMinutes = storedDuration(forKey: "lastDuration", defaultValue: 25)
    }

    func startSession(mode: FocusMode) {
        let sanitizedMode = mode.sanitized()
        currentMode = sanitizedMode
        currentActivity = sanitizedMode.name
        currentStatusText = sanitizedMode.statusText
        currentEmoji = sanitizedMode.emoji
        durationMinutes = sanitizedMode.sanitizedDurationMinutes
        workDurationMinutes = sanitizedMode.enablePomodoro ? sanitizedMode.sanitizedPomodoroWorkMinutes : sanitizedMode.sanitizedDurationMinutes
        shortBreakDurationMinutes = sanitizedMode.sanitizedPomodoroBreakMinutes
        longBreakDurationMinutes = sanitizedMode.sanitizedPomodoroLongBreakMinutes
        pomodoroRounds = sanitizedMode.enablePomodoro ? sanitizedMode.sanitizedPomodoroRounds : 1
        currentRound = 0

        saveLastUsed(
            activity: currentActivity,
            statusText: currentStatusText,
            emoji: currentEmoji,
            duration: durationMinutes
        )

        sessionStartTime = Date()
        startWorkPhase()
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
        isPaused ? resumeSession() : pauseSession()
    }

    func resetToIdle() {
        recordMetricsOnCompletion()
        stopTimer()
        deactivateFocusIntegration()
        clearSessionState()
        notificationService.notify(.sessionEnded)
    }

    func endSession(playCompletionSound: Bool = true) {
        recordMetricsOnCompletion()
        stopTimer()
        deactivateFocusIntegration()
        clearSessionState()

        if playCompletionSound {
            soundPlayer.playCompletionSound()
        }

        notificationService.notify(.sessionEnded)
    }

    // MARK: - Metrics Recording

    /// Records the completed session to `FocusMetricsService` for analytics.
    /// Called automatically when a session ends (either by completion or manual stop).
    private func recordMetricsOnCompletion() {
        // Only record if we have a valid session with start time and mode.
        guard let startTime = sessionStartTime, let mode = currentMode else {
            print("[Metrics] Skipping: no sessionStartTime or currentMode")
            return
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        // Ignore sessions shorter than 5 seconds (likely accidental clicks).
        guard duration >= 5 else {
            print("[Metrics] Skipping: duration \(duration)s < 5s threshold")
            return
        }

        let pomodorosCompleted: Int?
        if mode.enablePomodoro {
            pomodorosCompleted = currentRound
        } else {
            pomodorosCompleted = nil
        }

        let record = FocusSessionRecord(
            modeType: mode.type,
            modeID: mode.id,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            pomodorosCompleted: pomodorosCompleted
        )

        print("[Metrics] Recording session: \(record)")
        FocusMetricsService.shared.recordSession(record)
        print("[Metrics] Total records: \(FocusMetricsService.shared.records.count)")
    }

    private func startWorkPhase() {
        currentPhaseDuration = workDurationMinutes * 60
        remainingSeconds = currentPhaseDuration
        durationMinutes = workDurationMinutes
        pomodoroState = .work
        isActive = true
        isPaused = false

        // Restore original mode emoji and activity after break
        if let mode = currentMode {
            currentEmoji = mode.emoji
            currentActivity = mode.name
        }

        activateFocusIntegration()
        startTimer()
        notificationService.notify(.workSessionStarted(activity: currentActivity, durationMinutes: workDurationMinutes))
    }

    private func startShortBreak() {
        currentPhaseDuration = shortBreakDurationMinutes * 60
        remainingSeconds = currentPhaseDuration
        pomodoroState = .shortBreak
        isPaused = false
        currentActivity = currentMode?.breakLabel ?? "\(currentActivity) — Break"

        // Extract emoji from breakLabel and update currentEmoji for menu bar display
        if let label = currentMode?.breakLabel, let breakEmoji = extractEmoji(from: label) {
            currentEmoji = breakEmoji
        }

        // Update Slack status for short break
        if let mode = currentMode {
            focusIntegrationService.performSlackBreakAction(
                breakLabel: mode.breakLabel,
                isLongBreak: false,
                breakDurationMinutes: shortBreakDurationMinutes,
                modeName: mode.name,
                modeEmoji: mode.emoji
            )
        }

        deactivateFocusIntegration()
        startTimer()
        notificationService.notify(.breakStarted)
    }

    private func startLongBreak() {
        currentPhaseDuration = longBreakDurationMinutes * 60
        remainingSeconds = currentPhaseDuration
        pomodoroState = .longBreak
        isPaused = false

        let label = currentMode?.breakLabel
        currentActivity = label.map { "\($0) — Long Break" } ?? "\(currentActivity) — Long Break"

        // Extract emoji from breakLabel and update currentEmoji for menu bar display
        if let label = currentMode?.breakLabel, let breakEmoji = extractEmoji(from: label) {
            currentEmoji = breakEmoji
        }

        // Update Slack status for long break BEFORE deactivating DND
        if let mode = currentMode {
            focusIntegrationService.performSlackBreakAction(
                breakLabel: mode.breakLabel,
                isLongBreak: true,
                breakDurationMinutes: longBreakDurationMinutes,
                modeName: mode.name,
                modeEmoji: mode.emoji
            )
        }

        deactivateFocusIntegration()
        startTimer()
        notificationService.notify(.breakStarted)
    }

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
    }

    private func handlePhaseComplete() {
        stopTimer()

        switch pomodoroState {
        case .work:
            let completedRounds = currentRound + 1
            guard currentMode?.enablePomodoro == true else {
                endSession()
                return
            }

            // After every 4 rounds (set), take a long break; after individual rounds, short break
            let roundsInSet = 4
            if completedRounds % roundsInSet == 0 && completedRounds < pomodoroRounds {
                currentRound = completedRounds
                soundPlayer.play(.workEnd)
                startLongBreak()
            } else if completedRounds < pomodoroRounds {
                currentRound = completedRounds
                soundPlayer.play(.workEnd)
                startShortBreak()
            } else {
                endSession()
            }
        case .shortBreak:
            soundPlayer.play(.breakEnd)
            startWorkPhase()
        case .longBreak:
            soundPlayer.play(.breakEnd)
            startWorkPhase()
        case .idle, .completed:
            break
        }
    }

    private func clearSessionState() {
        pomodoroState = .idle
        currentRound = 0
        remainingSeconds = 0
        isActive = false
        isPaused = false
        currentActivity = ""
        currentStatusText = ""
        currentEmoji = ":brain:"
        currentMode = nil
        sessionStartTime = nil
    }

    private func saveLastUsed(activity: String, statusText: String, emoji: String, duration: Int) {
        defaults.set(activity, forKey: "lastActivity")
        defaults.set(statusText, forKey: "lastStatusText")
        defaults.set(emoji, forKey: "lastEmoji")
        defaults.set(duration, forKey: "lastDuration")
    }

    private func storedDuration(forKey key: String, defaultValue: Int) -> Int {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }
        return min(max(defaults.integer(forKey: key), TimerDefaults.durationRange.lowerBound), TimerDefaults.durationRange.upperBound)
    }

    var hasSession: Bool {
        pomodoroState != .idle && pomodoroState != .completed
    }

    var isWork: Bool {
        pomodoroState == .work
    }

    var isBreak: Bool {
        pomodoroState == .shortBreak || pomodoroState == .longBreak
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
        return seconds > 0 ? "\(minutes + 1)m" : "\(minutes)m"
    }

    var phaseName: String {
        switch pomodoroState {
        case .idle:
            return "Idle"
        case .work:
            return currentMode?.enablePomodoro == true ? "Focus Round" : "Focus"
        case .shortBreak:
            return "Break"
        case .longBreak:
            return "Long Break"
        case .completed:
            return "Completed"
        }
    }

    /// Extract emoji from a string like "Coffee time :coffee:" or ":coffee: break"
    /// - Parameter text: String containing emoji shortcode or unicode emoji
    /// - Returns: Emoji shortcode (e.g., ":coffee:") or nil if no emoji found
    private func extractEmoji(from text: String) -> String? {
        // Try to find Slack shortcode pattern :text:
        let shortcodePattern = ":[a-zA-Z0-9_+-]+:"
        if let range = text.range(of: shortcodePattern, options: .regularExpression) {
            return String(text[range])
        }

        // Try to extract unicode emoji (fallback)
        let emojiPattern = "[\\p{Emoji}&&\\p{GraphemeCluster}]"
        if let range = text.range(of: emojiPattern, options: .regularExpression) {
            let emoji = String(text[range])
            // Try to convert unicode emoji back to shortcode for consistency
            if let shortcode = EmojiValidator.convertUnicodeToShortcode(emoji, workspaceEmojis: []) {
                return shortcode
            }
            // Return unicode emoji as-is if no shortcode mapping exists
            return emoji
        }

        return nil
    }

    private func activateFocusIntegration() {
        guard let currentMode else { return }
        focusIntegrationService.activateFocus(for: currentMode)
    }

    private func deactivateFocusIntegration() {
        focusIntegrationService.deactivateFocus()
    }
}
