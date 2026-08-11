import XCTest
@testable import Focally

@MainActor
final class FocusTimerServiceTests: XCTestCase {
    private var sut: FocusTimerService!
    private var dndService: RecordingFocusTimerDND!
    private var notificationService: RecordingFocusTimerNotification!
    private var soundPlayer: RecordingFocusTimerSoundPlayer!
    private var focusIntegration: RecordingFocusTimerIntegration!
    private var persistence: RecordingSessionPersistence!
    private var ticker: TestFocusTimerTicker!
    private var clock: TestClock!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!
    private var metrics: RecordingFocusTimerMetrics!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "FocusTimerServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        metrics = RecordingFocusTimerMetrics()
        dndService = RecordingFocusTimerDND()
        notificationService = RecordingFocusTimerNotification()
        soundPlayer = RecordingFocusTimerSoundPlayer()
        focusIntegration = RecordingFocusTimerIntegration()
        persistence = RecordingSessionPersistence()
        ticker = TestFocusTimerTicker()
        clock = TestClock(Date(timeIntervalSince1970: 2_000_000_000))
        sut = FocusTimerService(
            settingsStore: SettingsStore(),
            soundPlayer: soundPlayer,
            notificationService: notificationService,
            dndService: dndService,
            focusIntegrationService: focusIntegration,
            persistence: persistence,
            ticker: ticker,
            now: { [clock] in clock!.date }, defaults: defaults, metricsService: metrics
        )
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        sut = nil
        dndService = nil
        notificationService = nil
        soundPlayer = nil
        focusIntegration = nil
        persistence = nil
        ticker = nil
        clock = nil
        metrics = nil
        defaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    func testHasSessionOnlyForActiveWorkAndBreakStates() {
        let expectations: [(PomodoroState, Bool)] = [
            (.idle, false),
            (.work, true),
            (.shortBreak, true),
            (.longBreak, true),
            (.completed, false)
        ]

        for (state, expected) in expectations {
            sut.pomodoroState = state
            XCTAssertEqual(sut.hasSession, expected, "Unexpected hasSession for \(state)")
        }
    }

    func testSingleRoundNaturalCompletionRecordsOnePomodoro() {
        prepareWorkCompletion(rounds: 1, currentRound: 0)

        sut.completeCurrentPhaseForTesting(sessionStartedAt: clock.date.addingTimeInterval(-6))

        XCTAssertEqual(metrics.records.last?.pomodorosCompleted, 1)
        XCTAssertFalse(sut.hasSession)
    }

    func testFourRoundNaturalCompletionRecordsFourPomodoros() {
        prepareWorkCompletion(rounds: 4, currentRound: 3)

        sut.completeCurrentPhaseForTesting(sessionStartedAt: clock.date.addingTimeInterval(-6))

        XCTAssertEqual(metrics.records.last?.pomodorosCompleted, 4)
        XCTAssertFalse(sut.hasSession)
    }

    func testNonTerminalWorkCompletionAdvancesToBreakAtRoundOne() {
        prepareWorkCompletion(rounds: 2, currentRound: 0)

        sut.completeCurrentPhaseForTesting()

        XCTAssertEqual(sut.currentRound, 1)
        XCTAssertEqual(sut.pomodoroState, .shortBreak)
        XCTAssertEqual(focusIntegration.slackBreakActions.map(\.isLongBreak), [false])
        XCTAssertEqual(focusIntegration.deactivationCount, 1)
    }

    func testRoundFourOfEightAdvancesToLongBreak() {
        prepareWorkCompletion(rounds: 8, currentRound: 3)

        sut.completeCurrentPhaseForTesting()

        XCTAssertEqual(sut.currentRound, 4)
        XCTAssertEqual(sut.pomodoroState, .longBreak)
        XCTAssertEqual(focusIntegration.slackBreakActions.map(\.isLongBreak), [true])
        XCTAssertEqual(focusIntegration.deactivationCount, 1)
    }

    func testStartSessionActivatesIntegrationWithSanitizedMode() {
        let mode = FocusMode(
            name: "Test Focus",
            durationMinutes: 0,
            enableMacOSDND: false,
            enableSlackDND: false
        )

        sut.startSession(mode: mode)

        XCTAssertEqual(focusIntegration.activatedModes.count, 1)
        XCTAssertEqual(focusIntegration.activatedModes.first?.durationMinutes, 5)
    }

    func testStartSessionDraftPersistsResolvedSnapshotWithoutMutatingBaseMode() throws {
        let baseMode = FocusMode(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            name: "Focus Time",
            emoji: ":brain:",
            statusText: "In focus mode",
            durationMinutes: 25,
            enableMacOSDND: true,
            enableSlackDND: true,
            enablePomodoro: true,
            pomodoroWorkMinutes: 25,
            pomodoroBreakMinutes: 5,
            pomodoroLongBreakMinutes: 15,
            pomodoroRounds: 4,
            typeDescriptor: .builtIn(.focusTime)
        )
        let original = baseMode
        var draft = FocusSessionDraft(mode: baseMode)
        draft.activity = "  Prepare launch  "
        draft.durationMinutes = 40
        let expected = draft.resolvedMode()

        sut.startSession(draft: draft)

        XCTAssertEqual(sut.currentActivity, "Prepare launch")
        XCTAssertEqual(sut.durationMinutes, 40)
        XCTAssertEqual(sut.workDurationMinutes, 40)
        XCTAssertEqual(sut.remainingSeconds, 40 * 60)
        XCTAssertEqual(sut.currentMode, expected)
        XCTAssertEqual(try XCTUnwrap(persistence.snapshot).modeSnapshot, expected)
        XCTAssertEqual(focusIntegration.activatedModes, [expected])
        XCTAssertEqual(baseMode, original)
    }

    func testEndSessionDeactivatesOnlyInjectedIntegration() {
        prepareWorkCompletion(rounds: 1, currentRound: 0)

        sut.endSession(playCompletionSound: false)

        XCTAssertEqual(dndService.deactivationCount, 0)
        XCTAssertEqual(focusIntegration.deactivationCount, 1)
        XCTAssertTrue(focusIntegration.activatedModes.isEmpty)
        XCTAssertFalse(sut.hasSession)
    }

    func testFiveMinuteClockAdvanceNeedsOnlyOneTick() {
        sut.startSession(mode: FocusMode(name: "Focus", durationMinutes: 25))
        clock.advance(5 * 60)
        ticker.fire()
        XCTAssertEqual(sut.remainingSeconds, 20 * 60)
    }

    func testStartPersistsExactSanitizedSnapshot() throws {
        let mode = FocusMode(name: "  Focus  ", durationMinutes: 25, enablePomodoro: true, pomodoroRounds: 3)
        sut.startSession(mode: mode)
        let snapshot = try XCTUnwrap(persistence.snapshot)
        XCTAssertEqual(snapshot.modeSnapshot, mode.sanitized())
        XCTAssertEqual(snapshot.phase, .work)
        XCTAssertEqual(snapshot.phaseStartedAt, clock.date)
        XCTAssertEqual(snapshot.phaseTargetEndDate, clock.date.addingTimeInterval(25 * 60))
        XCTAssertEqual(snapshot.phaseDurationSeconds, 25 * 60)
    }

    func testPauseGapDoesNotConsumeTimeAndAccumulates() throws {
        sut.startSession(mode: FocusMode(name: "Focus", durationMinutes: 25))
        clock.advance(5 * 60)
        sut.pauseSession()
        clock.advance(10 * 60)
        sut.resumeSession()
        XCTAssertEqual(sut.remainingSeconds, 20 * 60)
        XCTAssertEqual(try XCTUnwrap(persistence.snapshot).accumulatedPausedSeconds, 10 * 60)
    }

    func testPausedWallClockDoesNotInflateRecordedFocus() throws {
        sut.startSession(mode: FocusMode(name: "Focus", durationMinutes: 25))
        clock.advance(5 * 60)
        sut.pauseSession()
        clock.advance(10 * 60)
        sut.endSession(playCompletionSound: false)

        let record = try XCTUnwrap(metrics.records.last)
        XCTAssertEqual(record.recordVersion, 2)
        XCTAssertEqual(record.source, .manual)
        XCTAssertEqual(record.duration, 5 * 60)
        XCTAssertEqual(record.activeDuration, 5 * 60)
        XCTAssertEqual(record.pausedDuration, 10 * 60)
        XCTAssertEqual(record.breakDuration, 0)
    }

    func testNonPomodoroFiveActiveMinutesRecordsOnlyManualActiveTime() throws {
        sut.startSession(mode: FocusMode(name: "Focus", durationMinutes: 25))
        clock.advance(5 * 60)
        sut.endSession(playCompletionSound: false)
        assertHonestManualRecord(try XCTUnwrap(metrics.records.last), active: 300, paused: 0, breaks: 0)
        XCTAssertNil(metrics.records.last?.pomodorosCompleted)
    }

    func testEndingDuringBreakSeparatesPartialBreakFromActiveFocus() throws {
        sut.startSession(mode: FocusMode(name: "Focus", enablePomodoro: true,
            pomodoroWorkMinutes: 5, pomodoroBreakMinutes: 2, pomodoroRounds: 2))
        clock.advance(5 * 60); sut.reconcileAfterLifecycleGap()
        clock.advance(60); sut.endSession(playCompletionSound: false)

        let record = try XCTUnwrap(metrics.records.last)
        XCTAssertEqual(record.duration, 5 * 60)
        XCTAssertEqual(record.activeDuration, 5 * 60)
        XCTAssertEqual(record.breakDuration, 60)
    }

    func testBelowFiveActiveSecondsIsDiscardedDespiteLongPause() {
        sut.startSession(mode: FocusMode(name: "Focus", durationMinutes: 25))
        clock.advance(4); sut.pauseSession(); clock.advance(10 * 60)
        sut.endSession(playCompletionSound: false)
        XCTAssertTrue(metrics.records.isEmpty)
    }

    func testPausedSnapshotRestoresWithoutTickerOrIntegration() {
        sut.startSession(mode: FocusMode(name: "Original", durationMinutes: 25))
        clock.advance(5 * 60)
        sut.pauseSession()
        let saved = persistence.snapshot
        focusIntegration.activatedModes.removeAll()
        ticker.stop()
        persistence.snapshot = saved
        sut = FocusTimerService(settingsStore: SettingsStore(), soundPlayer: soundPlayer,
            notificationService: notificationService, dndService: dndService,
            focusIntegrationService: focusIntegration, persistence: persistence, ticker: ticker,
            now: { [clock] in clock!.date }, defaults: defaults, metricsService: metrics)
        sut.restoreSessionIfNeeded()
        XCTAssertTrue(sut.isPaused)
        XCTAssertEqual(sut.currentMode?.name, "Original")
        XCTAssertFalse(ticker.isRunning)
        XCTAssertTrue(focusIntegration.activatedModes.isEmpty)
    }

    func testActiveRestoreIsIdempotentAndDoesNotReplayHistory() {
        sut.startSession(mode: FocusMode(name: "Original", durationMinutes: 25))
        focusIntegration.activatedModes.removeAll()
        notificationService.events.removeAll()
        soundPlayer.playedSounds.removeAll()
        ticker.stop()
        sut = FocusTimerService(settingsStore: SettingsStore(), soundPlayer: soundPlayer,
            notificationService: notificationService, dndService: dndService,
            focusIntegrationService: focusIntegration, persistence: persistence, ticker: ticker,
            now: { [clock] in clock!.date }, defaults: defaults, metricsService: metrics)
        sut.restoreSessionIfNeeded()
        sut.restoreSessionIfNeeded()
        XCTAssertEqual(focusIntegration.activatedModes.count, 1)
        XCTAssertTrue(ticker.isRunning)
        XCTAssertTrue(notificationService.events.isEmpty)
        XCTAssertTrue(soundPlayer.playedSounds.isEmpty)
    }

    func testExpiredPomodoroPhasesCatchUpWithoutHistoricalEffects() throws {
        sut.startSession(mode: FocusMode(name: "Focus", enablePomodoro: true,
            pomodoroWorkMinutes: 5, pomodoroBreakMinutes: 1, pomodoroRounds: 3))
        notificationService.events.removeAll(); soundPlayer.playedSounds.removeAll()
        focusIntegration.slackBreakActions.removeAll(); focusIntegration.activatedModes.removeAll()
        clock.advance(12 * 60)
        sut.reconcileAfterLifecycleGap()
        XCTAssertEqual(sut.pomodoroState, .work)
        XCTAssertEqual(sut.currentRound, 2)
        XCTAssertEqual(sut.remainingSeconds, 5 * 60)
        XCTAssertTrue(notificationService.events.isEmpty)
        XCTAssertTrue(soundPlayer.playedSounds.isEmpty)
        XCTAssertTrue(focusIntegration.slackBreakActions.isEmpty)
        let snapshot = try XCTUnwrap(persistence.snapshot)
        XCTAssertEqual(snapshot.accumulatedActiveSeconds, 10 * 60)
        XCTAssertEqual(snapshot.accumulatedBreakSeconds, 2 * 60)
    }

    func testPrepareForTerminationPreservesSnapshotWithoutEndEffects() {
        sut.startSession(mode: FocusMode(name: "Focus", durationMinutes: 25))
        notificationService.events.removeAll(); soundPlayer.completionSoundCount = 0
        let clearCount = persistence.clearCount
        sut.prepareForTermination()
        XCTAssertNotNil(persistence.snapshot)
        XCTAssertEqual(persistence.clearCount, clearCount)
        XCTAssertFalse(ticker.isRunning)
        XCTAssertTrue(notificationService.events.isEmpty)
        XCTAssertEqual(soundPlayer.completionSoundCount, 0)
        XCTAssertEqual(focusIntegration.deactivationCount, 1)
        sut.prepareForTermination()
        XCTAssertEqual(focusIntegration.deactivationCount, 1)
    }

    func testMultiplePauseIntervalsAccumulateExactly() throws {
        sut.startSession(mode: FocusMode(name: "Focus", durationMinutes: 25))
        clock.advance(60); sut.pauseSession(); clock.advance(120); sut.resumeSession()
        clock.advance(60); sut.pauseSession(); clock.advance(180); sut.resumeSession()
        XCTAssertEqual(sut.remainingSeconds, 23 * 60)
        XCTAssertEqual(try XCTUnwrap(persistence.snapshot).accumulatedPausedSeconds, 5 * 60)
    }

    func testMultiplePauseIntervalsRecordExactlyOnce() throws {
        sut.startSession(mode: FocusMode(name: "Focus", durationMinutes: 25))
        clock.advance(60); sut.pauseSession(); clock.advance(120); sut.resumeSession()
        clock.advance(60); sut.pauseSession(); clock.advance(180)
        sut.endSession(playCompletionSound: false)
        assertHonestManualRecord(try XCTUnwrap(metrics.records.last), active: 120, paused: 300, breaks: 0)
    }

    func testRestoreThenEndPreservesAllThreeAccumulators() throws {
        sut.startSession(mode: FocusMode(name: "Focus", enablePomodoro: true,
            pomodoroWorkMinutes: 5, pomodoroBreakMinutes: 1, pomodoroRounds: 3))
        clock.advance(6 * 60); sut.reconcileAfterLifecycleGap()
        clock.advance(2 * 60); sut.pauseSession(); clock.advance(3 * 60)
        sut.prepareForTermination()
        reconstructAndRestore()
        sut.endSession(playCompletionSound: false)
        assertHonestManualRecord(try XCTUnwrap(metrics.records.last), active: 7 * 60,
            paused: 3 * 60, breaks: 60)
    }

    func testPausedLifecycleGapAndRestoreThenResumeDoNotDoubleCount() throws {
        sut.startSession(mode: FocusMode(name: "Focus", durationMinutes: 25))
        clock.advance(5 * 60); sut.pauseSession(); clock.advance(10 * 60)
        sut.reconcileAfterLifecycleGap()
        XCTAssertEqual(sut.remainingSeconds, 20 * 60)
        reconstructAndRestore()
        XCTAssertTrue(sut.isPaused)
        sut.resumeSession()
        XCTAssertEqual(try XCTUnwrap(persistence.snapshot).accumulatedPausedSeconds, 10 * 60)
        sut.pauseSession(); clock.advance(60); sut.resumeSession()
        XCTAssertEqual(try XCTUnwrap(persistence.snapshot).accumulatedPausedSeconds, 11 * 60)
    }

    func testActiveBreakRestorationKeepsIntegrationInactiveAndExactModeSnapshot() throws {
        let mode = FocusMode(name: "Deleted Elsewhere", emoji: ":rocket:", statusText: "Exact",
            enablePomodoro: true, pomodoroWorkMinutes: 5, pomodoroBreakMinutes: 2, pomodoroRounds: 2,
            breakLabel: ":coffee: Reset", typeDescriptor: .builtIn(.focusTime))
        sut.startSession(mode: mode)
        clock.advance(5 * 60); sut.reconcileAfterLifecycleGap()
        XCTAssertEqual(sut.pomodoroState, .shortBreak)
        let saved = try XCTUnwrap(persistence.snapshot)
        focusIntegration.activatedModes.removeAll(); notificationService.events.removeAll()
        reconstructAndRestore()
        XCTAssertEqual(sut.currentMode, mode.sanitized())
        XCTAssertTrue(ticker.isRunning)
        XCTAssertTrue(focusIntegration.activatedModes.isEmpty)
        XCTAssertTrue(notificationService.events.isEmpty)
        XCTAssertEqual(persistence.snapshot?.modeSnapshot, saved.modeSnapshot)
    }

    func testExpiredNonPomodoroCompletesAtLogicalTargetAndIsIdempotent() throws {
        sut.startSession(mode: FocusMode(name: "Short", durationMinutes: 5))
        let logicalEnd = try XCTUnwrap(persistence.snapshot?.phaseTargetEndDate)
        clock.advance(8 * 60); sut.reconcileAfterLifecycleGap(); sut.reconcileAfterLifecycleGap()
        XCTAssertFalse(sut.hasSession)
        XCTAssertNil(persistence.snapshot)
        XCTAssertEqual(metrics.records.count, 1)
        XCTAssertEqual(metrics.records[0].endTime, logicalEnd)
    }

    func testOnePomodoroPhaseAdvancesHistoricallyWithoutEffects() {
        sut.startSession(mode: FocusMode(name: "Focus", enablePomodoro: true,
            pomodoroWorkMinutes: 5, pomodoroBreakMinutes: 2, pomodoroRounds: 2))
        notificationService.events.removeAll(); soundPlayer.playedSounds.removeAll()
        focusIntegration.slackBreakActions.removeAll()
        clock.advance(5 * 60); sut.reconcileAfterLifecycleGap()
        XCTAssertEqual(sut.currentRound, 1)
        XCTAssertEqual(sut.pomodoroState, .shortBreak)
        XCTAssertTrue(notificationService.events.isEmpty)
        XCTAssertTrue(soundPlayer.playedSounds.isEmpty)
        XCTAssertTrue(focusIntegration.slackBreakActions.isEmpty)
    }

    func testFullyElapsedMultiRoundCompletesWithLogicalTerminalState() throws {
        sut.startSession(mode: FocusMode(name: "Focus", enablePomodoro: true,
            pomodoroWorkMinutes: 5, pomodoroBreakMinutes: 1, pomodoroRounds: 2))
        let start = try XCTUnwrap(persistence.snapshot?.phaseStartedAt)
        clock.advance(20 * 60); sut.reconcileAfterLifecycleGap()
        XCTAssertEqual(metrics.records.count, 1)
        XCTAssertEqual(metrics.records[0].endTime, start.addingTimeInterval(11 * 60))
        XCTAssertEqual(metrics.records[0].pomodorosCompleted, 2)
        XCTAssertEqual(metrics.records[0].duration, 10 * 60)
        XCTAssertEqual(metrics.records[0].activeDuration, 10 * 60)
        XCTAssertEqual(metrics.records[0].breakDuration, 60)
        XCTAssertNil(persistence.snapshot)
        sut.reconcileAfterLifecycleGap()
        XCTAssertEqual(metrics.records.count, 1)
    }

    func testHistoricalThreeRoundCatchUpRecordsEveryWorkAndBreakComponent() throws {
        sut.startSession(mode: FocusMode(name: "Focus", enablePomodoro: true,
            pomodoroWorkMinutes: 5, pomodoroBreakMinutes: 1, pomodoroRounds: 3))
        let logicalStart = try XCTUnwrap(persistence.snapshot?.phaseStartedAt)
        clock.advance(30 * 60)
        sut.reconcileAfterLifecycleGap()
        let record = try XCTUnwrap(metrics.records.last)
        assertHonestManualRecord(record, active: 15 * 60, paused: 0, breaks: 2 * 60)
        XCTAssertEqual(record.pomodorosCompleted, 3)
        XCTAssertEqual(record.endTime, logicalStart.addingTimeInterval(17 * 60))
    }

    func testEndSessionAndResetToIdleClearPersistence() {
        sut.startSession(mode: FocusMode(name: "Focus", durationMinutes: 25))
        sut.endSession(playCompletionSound: false)
        XCTAssertNil(persistence.snapshot)
        sut.startSession(mode: FocusMode(name: "Focus", durationMinutes: 25))
        sut.resetToIdle()
        XCTAssertNil(persistence.snapshot)
    }

    func testTickerTransitionWithinTwoSecondsEmitsLiveEffectsOnce() {
        let mode = FocusMode(name: "Focus", enablePomodoro: true,
            pomodoroWorkMinutes: 5, pomodoroBreakMinutes: 1, pomodoroRounds: 2)
        sut.startSession(mode: mode)
        notificationService.events.removeAll(); soundPlayer.playedSounds.removeAll()
        focusIntegration.slackBreakActions.removeAll()
        clock.advance(5 * 60 + 2); ticker.fire(); ticker.fire()
        XCTAssertEqual(soundPlayer.playedSounds, [.workEnd])
        XCTAssertEqual(notificationService.events.count, 1)
        guard case .breakStarted = notificationService.events[0] else {
            return XCTFail("Expected exactly one live break-start notification")
        }
        XCTAssertEqual(focusIntegration.slackBreakActions.count, 1)
    }

    func testTickerTransitionBeyondTwoSecondsIsHistorical() {
        sut.startSession(mode: FocusMode(name: "Focus", enablePomodoro: true,
            pomodoroWorkMinutes: 5, pomodoroBreakMinutes: 1, pomodoroRounds: 2))
        notificationService.events.removeAll(); soundPlayer.playedSounds.removeAll()
        focusIntegration.slackBreakActions.removeAll()

        clock.advance(5 * 60 + 2.001)
        ticker.fire()

        XCTAssertEqual(sut.pomodoroState, .shortBreak)
        XCTAssertTrue(notificationService.events.isEmpty)
        XCTAssertTrue(soundPlayer.playedSounds.isEmpty)
        XCTAssertTrue(focusIntegration.slackBreakActions.isEmpty)
        XCTAssertTrue(ticker.isRunning)
    }

    func testSleepStopsTickerPersistsAndIgnoresQueuedTickerCallback() {
        sut.startSession(mode: FocusMode(name: "Focus", durationMinutes: 25))
        let savesBeforeSleep = persistence.saveCount
        clock.advance(60)

        sut.prepareForSleep()

        XCTAssertFalse(ticker.isRunning)
        XCTAssertEqual(persistence.saveCount, savesBeforeSleep + 1)
        XCTAssertEqual(persistence.snapshot?.savedAt, clock.date)
        XCTAssertEqual(sut.remainingSeconds, 24 * 60)

        clock.advance(25 * 60)
        ticker.fireLastScheduledCallback()
        XCTAssertTrue(sut.hasSession)
        XCTAssertEqual(metrics.records.count, 0)
    }

    func testWakeNearExpiryReconcilesHistoricallyAndRestartsFinalActivePhase() {
        sut.startSession(mode: FocusMode(name: "Focus", enablePomodoro: true,
            pomodoroWorkMinutes: 5, pomodoroBreakMinutes: 1, pomodoroRounds: 2))
        notificationService.events.removeAll(); soundPlayer.playedSounds.removeAll()
        focusIntegration.slackBreakActions.removeAll(); focusIntegration.activatedModes.removeAll()
        clock.advance(5 * 60 - 1)
        sut.prepareForSleep()
        clock.advance(2)

        sut.reconcileAfterWake()

        XCTAssertEqual(sut.pomodoroState, .shortBreak)
        XCTAssertEqual(sut.remainingSeconds, 59)
        XCTAssertTrue(ticker.isRunning)
        XCTAssertTrue(notificationService.events.isEmpty)
        XCTAssertTrue(soundPlayer.playedSounds.isEmpty)
        XCTAssertTrue(focusIntegration.slackBreakActions.isEmpty)
        XCTAssertTrue(focusIntegration.activatedModes.isEmpty)
    }

    func testWakeAfterTerminalPhaseStaysStoppedAndSilent() {
        sut.startSession(mode: FocusMode(name: "Focus", durationMinutes: 5))
        notificationService.events.removeAll(); soundPlayer.completionSoundCount = 0
        clock.advance(5 * 60 - 1)
        sut.prepareForSleep()
        clock.advance(2)

        sut.reconcileAfterWake()

        XCTAssertFalse(sut.hasSession)
        XCTAssertFalse(ticker.isRunning)
        XCTAssertTrue(notificationService.events.isEmpty)
        XCTAssertEqual(soundPlayer.completionSoundCount, 0)
    }

    private func reconstructAndRestore() {
        ticker.stop()
        sut = FocusTimerService(settingsStore: SettingsStore(), soundPlayer: soundPlayer,
            notificationService: notificationService, dndService: dndService,
            focusIntegrationService: focusIntegration, persistence: persistence, ticker: ticker,
            now: { [clock] in clock!.date }, defaults: defaults, metricsService: metrics)
        sut.restoreSessionIfNeeded()
    }

    private func prepareWorkCompletion(rounds: Int, currentRound: Int) {
        sut.currentMode = FocusMode(
            name: "Test Focus",
            enableMacOSDND: false,
            enableSlackDND: false,
            enablePomodoro: true,
            pomodoroRounds: rounds
        )
        sut.pomodoroRounds = rounds
        sut.currentRound = currentRound
        sut.pomodoroState = .work
        sut.isActive = true
    }

    private func assertHonestManualRecord(_ record: FocusSessionRecord, active: TimeInterval,
                                          paused: TimeInterval, breaks: TimeInterval,
                                          file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(record.recordVersion, 2, file: file, line: line)
        XCTAssertEqual(record.source, .manual, file: file, line: line)
        XCTAssertEqual(record.duration, active, file: file, line: line)
        XCTAssertEqual(record.activeDuration, active, file: file, line: line)
        XCTAssertEqual(record.pausedDuration, paused, file: file, line: line)
        XCTAssertEqual(record.breakDuration, breaks, file: file, line: line)
    }
}

@MainActor
private final class RecordingFocusTimerMetrics: FocusTimerMetrics {
    var records: [FocusSessionRecord] = []
    func recordSession(_ record: FocusSessionRecord) { records.append(record) }
}

@MainActor
private final class RecordingFocusTimerDND: FocusTimerDND {
    private(set) var deactivationCount = 0

    func deactivateDND() {
        deactivationCount += 1
    }
}

@MainActor
private final class RecordingFocusTimerNotification: FocusTimerNotification {
    var events: [NotificationService.Event] = []

    func notify(_ event: NotificationService.Event) {
        events.append(event)
    }
}

@MainActor
private final class RecordingFocusTimerSoundPlayer: FocusTimerSoundPlayer {
    var playedSounds: [SoundPlayerService.SoundType] = []
    var completionSoundCount = 0

    func play(_ soundType: SoundPlayerService.SoundType) {
        playedSounds.append(soundType)
    }

    func playCompletionSound() {
        completionSoundCount += 1
    }
}

@MainActor
private final class RecordingFocusTimerIntegration: FocusTimerIntegration {
    struct SlackBreakAction {
        let breakLabel: String?
        let isLongBreak: Bool
        let breakDurationMinutes: Int
        let modeName: String
        let modeEmoji: String
    }

    var activatedModes: [FocusMode] = []
    private(set) var deactivationCount = 0
    var slackBreakActions: [SlackBreakAction] = []

    func activateFocus(for mode: FocusMode) {
        activatedModes.append(mode)
    }

    func deactivateFocus() {
        deactivationCount += 1
    }

    func performSlackBreakAction(
        breakLabel: String?,
        isLongBreak: Bool,
        breakDurationMinutes: Int,
        modeName: String,
        modeEmoji: String
    ) {
        slackBreakActions.append(
            SlackBreakAction(
                breakLabel: breakLabel,
                isLongBreak: isLongBreak,
                breakDurationMinutes: breakDurationMinutes,
                modeName: modeName,
                modeEmoji: modeEmoji
            )
        )
    }
}

@MainActor private final class RecordingSessionPersistence: FocusSessionPersisting {
    var snapshot: PersistedFocusSession?
    private(set) var saveCount = 0
    private(set) var clearCount = 0
    func load() -> PersistedFocusSession? { snapshot }
    func save(_ snapshot: PersistedFocusSession) { self.snapshot = snapshot; saveCount += 1 }
    func clear() { snapshot = nil; clearCount += 1 }
}

@MainActor private final class TestFocusTimerTicker: FocusTimerTicker {
    private var action: (@MainActor () -> Void)?
    private var lastScheduledAction: (@MainActor () -> Void)?
    var isRunning: Bool { action != nil }
    func start(_ tick: @escaping @MainActor () -> Void) { action = tick; lastScheduledAction = tick }
    func stop() { action = nil }
    func fire() { action?() }
    func fireLastScheduledCallback() { lastScheduledAction?() }
}

@MainActor private final class TestClock {
    var date: Date
    init(_ date: Date) { self.date = date }
    func advance(_ seconds: TimeInterval) { date.addTimeInterval(seconds) }
}
