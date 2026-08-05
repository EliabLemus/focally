import Foundation
import Observation
import SwiftUI

@MainActor protocol FocusTimerDND: AnyObject { func deactivateDND() }
@MainActor protocol FocusTimerNotification: AnyObject { func notify(_ event: NotificationService.Event) }
@MainActor protocol FocusTimerSoundPlayer: AnyObject {
    func play(_ soundType: SoundPlayerService.SoundType)
    func playCompletionSound()
}
@MainActor protocol FocusTimerIntegration: AnyObject {
    func activateFocus(for mode: FocusMode)
    func deactivateFocus()
    func performSlackBreakAction(breakLabel: String?, isLongBreak: Bool, breakDurationMinutes: Int, modeName: String, modeEmoji: String)
}
@MainActor protocol FocusTimerMetrics: AnyObject {
    func recordSession(_ record: FocusSessionRecord)
}

extension DNDService: FocusTimerDND {}
extension NotificationService: FocusTimerNotification {}
extension SoundPlayerService: FocusTimerSoundPlayer {}
extension FocusTimerSoundPlayer where Self == SoundPlayerService { static var shared: SoundPlayerService { .shared } }
extension FocusIntegrationService: FocusTimerIntegration {}
extension FocusMetricsService: FocusTimerMetrics {}

@MainActor @Observable
final class FocusTimerService {
    static private(set) weak var shared: FocusTimerService?
    private static let catchUpSafetyCap = 32
    private static let liveTickerTolerance: TimeInterval = 2

    private enum ReconciliationSource: Equatable {
        case liveTicker
        case restoration
        case lifecycleGap

        var permitsFirstTransitionEffects: Bool { self == .liveTicker }
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

    let settingsStore: SettingsStore
    let soundPlayer: any FocusTimerSoundPlayer
    let notificationService: any FocusTimerNotification
    let dndService: any FocusTimerDND
    let focusIntegrationService: any FocusTimerIntegration
    private let metricsService: any FocusTimerMetrics

    private let persistence: any FocusSessionPersisting
    private let ticker: any FocusTimerTicker
    private let now: () -> Date
    private let defaults: UserDefaults
    private var sessionID: UUID?
    private var sessionStartTime: Date?
    private var phaseStartedAt: Date?
    private var phaseTargetEndDate: Date?
    private var currentPhaseDuration = 0
    private var pausedAt: Date?
    private var pausedRemainingSeconds: Int?
    private var accumulatedActiveSeconds: TimeInterval = 0
    private var accumulatedBreakSeconds: TimeInterval = 0
    private var accumulatedPausedSeconds: TimeInterval = 0
    private var didAttemptRestore = false
    private var isPreparedForTermination = false
    private var isLifecycleSuspended = false

    init(settingsStore: SettingsStore,
         soundPlayer: any FocusTimerSoundPlayer = SoundPlayerService.shared,
         notificationService: any FocusTimerNotification = NotificationService(),
         dndService: any FocusTimerDND = DNDService.shared,
         focusIntegrationService: any FocusTimerIntegration,
         persistence: (any FocusSessionPersisting)? = nil,
         ticker: (any FocusTimerTicker)? = nil,
         now: @escaping () -> Date = Date.init,
         defaults: UserDefaults? = nil,
         metricsService: (any FocusTimerMetrics)? = nil) {
        self.settingsStore = settingsStore
        self.soundPlayer = soundPlayer
        self.notificationService = notificationService
        self.dndService = dndService
        self.focusIntegrationService = focusIntegrationService
        self.persistence = persistence ?? SessionPersistenceService()
        self.ticker = ticker ?? FoundationFocusTimerTicker()
        self.now = now
        self.defaults = defaults ?? .standard
        self.metricsService = metricsService ?? FocusMetricsService.shared
        Self.shared = self
        loadLastSession()
    }

    private func loadLastSession() {
        currentActivity = defaults.string(forKey: "lastActivity") ?? ""
        currentStatusText = defaults.string(forKey: "lastStatusText") ?? ""
        currentEmoji = defaults.string(forKey: "lastEmoji") ?? ":brain:"
        durationMinutes = defaults.object(forKey: "lastDuration") == nil ? 25 : min(max(defaults.integer(forKey: "lastDuration"), 1), 600)
    }

    func startSession(mode: FocusMode) {
        let mode = mode.sanitized()
        ticker.stop()
        currentMode = mode
        currentActivity = mode.name
        currentStatusText = mode.statusText
        currentEmoji = mode.emoji
        durationMinutes = mode.sanitizedDurationMinutes
        workDurationMinutes = mode.enablePomodoro ? mode.sanitizedPomodoroWorkMinutes : mode.sanitizedDurationMinutes
        shortBreakDurationMinutes = mode.sanitizedPomodoroBreakMinutes
        longBreakDurationMinutes = mode.sanitizedPomodoroLongBreakMinutes
        pomodoroRounds = mode.enablePomodoro ? mode.sanitizedPomodoroRounds : 1
        currentRound = 0
        sessionID = UUID()
        sessionStartTime = now()
        accumulatedActiveSeconds = 0
        accumulatedBreakSeconds = 0
        accumulatedPausedSeconds = 0
        isPreparedForTermination = false
        isLifecycleSuspended = false
        saveLastUsed()
        establishPhase(.work, startedAt: now())
        applyCurrentIntegration()
        startTicker()
        persist()
        notificationService.notify(.workSessionStarted(activity: currentActivity, durationMinutes: workDurationMinutes))
    }

    func pauseSession() {
        guard isActive, !isPaused else { return }
        reconcileTime(source: .liveTicker)
        guard isActive else { return }
        let date = now()
        remainingSeconds = derivedRemaining(at: date)
        pausedRemainingSeconds = remainingSeconds
        pausedAt = date
        phaseTargetEndDate = nil
        isPaused = true
        ticker.stop()
        deactivateFocusIntegration()
        persist(at: date)
    }

    func resumeSession() {
        guard isActive, isPaused, let pausedAt, let pausedRemainingSeconds else { return }
        let date = now()
        accumulatedPausedSeconds += max(0, date.timeIntervalSince(pausedAt))
        self.pausedAt = nil
        self.pausedRemainingSeconds = nil
        phaseTargetEndDate = date.addingTimeInterval(TimeInterval(pausedRemainingSeconds))
        remainingSeconds = pausedRemainingSeconds
        isPaused = false
        isPreparedForTermination = false
        applyCurrentIntegration()
        startTicker()
        persist(at: date)
    }

    func togglePause() { isPaused ? resumeSession() : pauseSession() }

    func restoreSessionIfNeeded() {
        guard !didAttemptRestore else { return }
        didAttemptRestore = true
        guard let snapshot = persistence.load(), snapshot.isValid(at: now()) else {
            persistence.clear()
            return
        }
        restore(snapshot)
        if isPaused { return }
        if let target = phaseTargetEndDate, target > now() {
            applyCurrentIntegration()
            startTicker()
        } else {
            reconcileTime(source: .restoration)
        }
    }

    func reconcileTime() { reconcileTime(source: .liveTicker) }

    func reconcileAfterLifecycleGap() { reconcileTime(source: .lifecycleGap) }

    func prepareForSleep() {
        guard hasSession else {
            isLifecycleSuspended = true
            ticker.stop()
            return
        }
        let date = now()
        if !isPaused { remainingSeconds = derivedRemaining(at: date) }
        persist(at: date)
        isLifecycleSuspended = true
        ticker.stop()
    }

    func reconcileAfterWake() {
        isLifecycleSuspended = false
        reconcileTime(source: .lifecycleGap)
    }

    func persistForLifecycleBoundary() {
        guard hasSession else { return }
        if !isPaused { remainingSeconds = derivedRemaining(at: now()) }
        persist()
    }

    func prepareForTermination() {
        guard hasSession, !isPreparedForTermination else { return }
        isPreparedForTermination = true
        persistForLifecycleBoundary()
        ticker.stop()
        deactivateFocusIntegration()
    }

    func resetToIdle() {
        let date = now()
        addPartialCurrentPhase(at: date)
        recordMetricsOnCompletion(endTime: date)
        finishAndClear()
        notificationService.notify(.sessionEnded)
    }

    func endSession(playCompletionSound: Bool = true) {
        let date = now()
        addPartialCurrentPhase(at: date)
        recordMetricsOnCompletion(endTime: date)
        finishAndClear()
        if playCompletionSound { soundPlayer.playCompletionSound() }
        notificationService.notify(.sessionEnded)
    }

    private func reconcileTime(source: ReconciliationSource) {
        guard isActive, !isPaused, !isLifecycleSuspended else { return }
        let date = now()
        var transitions = 0
        var needsFinalIntegrationState = false

        while let target = phaseTargetEndDate, target <= date, transitions < Self.catchUpSafetyCap {
            let lateness = date.timeIntervalSince(target)
            let live = source.permitsFirstTransitionEffects
                && transitions == 0
                && lateness <= Self.liveTickerTolerance
            completeCurrentPhaseAccumulator()
            transitions += 1
            if !advanceAfterCompletedPhase(startedAt: target, liveEffects: live) {
                recordMetricsOnCompletion(endTime: target)
                finishAndClear(playDeactivation: true)
                if live {
                    soundPlayer.playCompletionSound()
                    notificationService.notify(.sessionEnded)
                }
                return
            }
            if !live { needsFinalIntegrationState = true }
        }

        guard transitions < Self.catchUpSafetyCap else {
            persistence.clear()
            finishAndClear(playDeactivation: true)
            return
        }
        remainingSeconds = derivedRemaining(at: date)
        if transitions > 0 {
            if needsFinalIntegrationState || source != .liveTicker { applyCurrentIntegration() }
            persist(at: date)
        }
        startTicker()
    }

    private func advanceAfterCompletedPhase(startedAt: Date, liveEffects: Bool) -> Bool {
        switch pomodoroState {
        case .work:
            currentRound += 1
            guard currentMode?.enablePomodoro == true, currentRound < pomodoroRounds else { return false }
            let next: PomodoroState = currentRound % 4 == 0 ? .longBreak : .shortBreak
            if liveEffects { soundPlayer.play(.workEnd) }
            establishPhase(next, startedAt: startedAt)
            if liveEffects { applyLivePhaseStartEffects() }
        case .shortBreak, .longBreak:
            if liveEffects { soundPlayer.play(.breakEnd) }
            establishPhase(.work, startedAt: startedAt)
            if liveEffects { applyLivePhaseStartEffects() }
        case .idle, .completed:
            return false
        }
        return true
    }

    private func establishPhase(_ phase: PomodoroState, startedAt: Date) {
        pomodoroState = phase
        let minutes: Int
        switch phase {
        case .work: minutes = workDurationMinutes
        case .shortBreak: minutes = shortBreakDurationMinutes
        case .longBreak: minutes = longBreakDurationMinutes
        case .idle, .completed: return
        }
        currentPhaseDuration = minutes * 60
        phaseStartedAt = startedAt
        phaseTargetEndDate = startedAt.addingTimeInterval(TimeInterval(currentPhaseDuration))
        remainingSeconds = currentPhaseDuration
        isActive = true
        isPaused = false
        pausedAt = nil
        pausedRemainingSeconds = nil
        updatePhasePresentation()
    }

    private func updatePhasePresentation() {
        guard let mode = currentMode else { return }
        switch pomodoroState {
        case .work:
            durationMinutes = workDurationMinutes
            currentActivity = mode.name
            currentEmoji = mode.emoji
        case .shortBreak:
            currentActivity = mode.breakLabel ?? "\(mode.name) — Break"
            if let label = mode.breakLabel, let emoji = extractEmoji(from: label) { currentEmoji = emoji }
        case .longBreak:
            currentActivity = mode.breakLabel.map { "\($0) — Long Break" } ?? "\(mode.name) — Long Break"
            if let label = mode.breakLabel, let emoji = extractEmoji(from: label) { currentEmoji = emoji }
        case .idle, .completed: break
        }
    }

    private func applyLivePhaseStartEffects() {
        guard let mode = currentMode else { return }
        if pomodoroState == .work {
            applyCurrentIntegration()
            notificationService.notify(.workSessionStarted(activity: currentActivity, durationMinutes: workDurationMinutes))
        } else {
            focusIntegrationService.performSlackBreakAction(
                breakLabel: mode.breakLabel,
                isLongBreak: pomodoroState == .longBreak,
                breakDurationMinutes: pomodoroState == .longBreak ? longBreakDurationMinutes : shortBreakDurationMinutes,
                modeName: mode.name,
                modeEmoji: mode.emoji
            )
            deactivateFocusIntegration()
            notificationService.notify(.breakStarted)
        }
    }

    private func applyCurrentIntegration() {
        guard pomodoroState == .work, let currentMode else {
            deactivateFocusIntegration()
            return
        }
        focusIntegrationService.activateFocus(for: currentMode)
    }

    private func startTicker() {
        guard isActive, !isPaused, !isLifecycleSuspended else { return }
        ticker.start { [weak self] in self?.reconcileTime(source: .liveTicker) }
    }

    private func derivedRemaining(at date: Date) -> Int {
        if isPaused { return min(max(pausedRemainingSeconds ?? 0, 0), currentPhaseDuration) }
        guard let target = phaseTargetEndDate else { return 0 }
        return min(max(Int(ceil(target.timeIntervalSince(date))), 0), currentPhaseDuration)
    }

    private func completeCurrentPhaseAccumulator() {
        if pomodoroState == .work { accumulatedActiveSeconds += TimeInterval(currentPhaseDuration) }
        else if isBreak { accumulatedBreakSeconds += TimeInterval(currentPhaseDuration) }
    }

    private func addPartialCurrentPhase(at date: Date) {
        guard hasSession else { return }
        let elapsed = TimeInterval(max(0, currentPhaseDuration - derivedRemaining(at: date)))
        if pomodoroState == .work { accumulatedActiveSeconds += elapsed }
        else if isBreak { accumulatedBreakSeconds += elapsed }
        if isPaused, let pausedAt { accumulatedPausedSeconds += max(0, date.timeIntervalSince(pausedAt)) }
    }

    private func restore(_ s: PersistedFocusSession) {
        sessionID = s.sessionID; currentMode = s.modeSnapshot; sessionStartTime = s.sessionStartedAt
        pomodoroState = s.phase; phaseStartedAt = s.phaseStartedAt; phaseTargetEndDate = s.phaseTargetEndDate
        currentPhaseDuration = s.phaseDurationSeconds; isPaused = s.isPaused; pausedAt = s.pausedAt
        pausedRemainingSeconds = s.pausedRemainingSeconds; currentRound = s.currentRound; pomodoroRounds = s.pomodoroRounds
        accumulatedActiveSeconds = s.accumulatedActiveSeconds; accumulatedBreakSeconds = s.accumulatedBreakSeconds
        accumulatedPausedSeconds = s.accumulatedPausedSeconds; isActive = true
        let mode = s.modeSnapshot
        workDurationMinutes = mode.enablePomodoro ? mode.sanitizedPomodoroWorkMinutes : mode.sanitizedDurationMinutes
        shortBreakDurationMinutes = mode.sanitizedPomodoroBreakMinutes
        longBreakDurationMinutes = mode.sanitizedPomodoroLongBreakMinutes
        currentStatusText = mode.statusText
        remainingSeconds = derivedRemaining(at: now())
        updatePhasePresentation()
    }

    private func persist(at date: Date? = nil) {
        guard let sessionID, let modeSnapshot = currentMode, let sessionStartTime, let phaseStartedAt, hasSession else { return }
        let date = date ?? now()
        persistence.save(PersistedFocusSession(
            sessionID: sessionID, modeSnapshot: modeSnapshot, sessionStartedAt: sessionStartTime,
            phase: pomodoroState, phaseStartedAt: phaseStartedAt, phaseTargetEndDate: phaseTargetEndDate,
            phaseDurationSeconds: currentPhaseDuration, isPaused: isPaused, pausedAt: pausedAt,
            pausedRemainingSeconds: pausedRemainingSeconds, currentRound: currentRound, pomodoroRounds: pomodoroRounds,
            accumulatedActiveSeconds: accumulatedActiveSeconds, accumulatedBreakSeconds: accumulatedBreakSeconds,
            accumulatedPausedSeconds: accumulatedPausedSeconds, savedAt: date
        ))
    }

    private func recordMetricsOnCompletion(endTime: Date) {
        guard let start = sessionStartTime, let mode = currentMode else { return }
        let duration = endTime.timeIntervalSince(start)
        guard duration >= 5 else { return }
        metricsService.recordSession(FocusSessionRecord(
            modeType: mode.type, modeID: mode.id, startTime: start, endTime: endTime,
            duration: duration, pomodorosCompleted: mode.enablePomodoro ? currentRound : nil
        ))
    }

    private func finishAndClear(playDeactivation: Bool = true) {
        ticker.stop()
        if playDeactivation { deactivateFocusIntegration() }
        persistence.clear()
        clearSessionState()
    }

    private func clearSessionState() {
        pomodoroState = .idle; currentRound = 0; remainingSeconds = 0; isActive = false; isPaused = false
        currentActivity = ""; currentStatusText = ""; currentEmoji = ":brain:"; currentMode = nil
        sessionID = nil; sessionStartTime = nil; phaseStartedAt = nil; phaseTargetEndDate = nil
        pausedAt = nil; pausedRemainingSeconds = nil; currentPhaseDuration = 0
        accumulatedActiveSeconds = 0; accumulatedBreakSeconds = 0; accumulatedPausedSeconds = 0
        isPreparedForTermination = false
        isLifecycleSuspended = false
    }

#if DEBUG
    func completeCurrentPhaseForTesting(sessionStartedAt: Date? = nil) {
        let date = now()
        if self.sessionStartTime == nil { self.sessionStartTime = sessionStartedAt ?? date.addingTimeInterval(-6) }
        if sessionID == nil { sessionID = UUID() }
        if currentPhaseDuration == 0 { currentPhaseDuration = max(1, workDurationMinutes * 60) }
        phaseStartedAt = date.addingTimeInterval(-TimeInterval(currentPhaseDuration))
        phaseTargetEndDate = date
        reconcileTime(source: .liveTicker)
    }
#endif

    private func saveLastUsed() {
        defaults.set(currentActivity, forKey: "lastActivity")
        defaults.set(currentStatusText, forKey: "lastStatusText")
        defaults.set(currentEmoji, forKey: "lastEmoji")
        defaults.set(durationMinutes, forKey: "lastDuration")
    }

    var hasSession: Bool { pomodoroState != .idle && pomodoroState != .completed }
    var isWork: Bool { pomodoroState == .work }
    var isBreak: Bool { pomodoroState == .shortBreak || pomodoroState == .longBreak }
    var progress: Double { currentPhaseDuration > 0 ? Double(currentPhaseDuration - remainingSeconds) / Double(currentPhaseDuration) : 0 }
    var remainingTimeString: String { String(format: "%d:%02d", remainingSeconds / 60, remainingSeconds % 60) }
    var remainingMinutesString: String {
        let minutes = remainingSeconds / 60, seconds = remainingSeconds % 60
        return minutes < 1 ? "<1m" : (seconds > 0 ? "\(minutes + 1)m" : "\(minutes)m")
    }
    var phaseName: String {
        switch pomodoroState {
        case .idle: return "Idle"
        case .work: return currentMode?.enablePomodoro == true ? "Focus Round" : "Focus"
        case .shortBreak: return "Break"
        case .longBreak: return "Long Break"
        case .completed: return "Completed"
        }
    }

    private func extractEmoji(from text: String) -> String? {
        if let range = text.range(of: ":[a-zA-Z0-9_+-]+:", options: .regularExpression) { return String(text[range]) }
        if let range = text.range(of: "[\\p{Emoji}&&\\p{GraphemeCluster}]", options: .regularExpression) {
            let emoji = String(text[range])
            return EmojiValidator.convertUnicodeToShortcode(emoji, workspaceEmojis: []) ?? emoji
        }
        return nil
    }

    private func deactivateFocusIntegration() { focusIntegrationService.deactivateFocus() }
}
