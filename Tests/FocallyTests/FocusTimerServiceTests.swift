import XCTest
@testable import Focally

@MainActor
final class FocusTimerServiceTests: XCTestCase {
    private static let userDefaultsKeys = [
        "focally.metrics.records",
        "lastActivity",
        "lastStatusText",
        "lastEmoji",
        "lastDuration"
    ]

    private var sut: FocusTimerService!
    private var dndService: RecordingFocusTimerDND!
    private var notificationService: RecordingFocusTimerNotification!
    private var soundPlayer: RecordingFocusTimerSoundPlayer!
    private var focusIntegration: RecordingFocusTimerIntegration!
    private var priorUserDefaults: [(key: String, value: Any?)] = []

    override func setUp() {
        super.setUp()
        priorUserDefaults = Self.userDefaultsKeys.map {
            (key: $0, value: UserDefaults.standard.object(forKey: $0))
        }
        FocusMetricsService.shared.clearAllRecords()
        dndService = RecordingFocusTimerDND()
        notificationService = RecordingFocusTimerNotification()
        soundPlayer = RecordingFocusTimerSoundPlayer()
        focusIntegration = RecordingFocusTimerIntegration()
        sut = FocusTimerService(
            settingsStore: SettingsStore(),
            soundPlayer: soundPlayer,
            notificationService: notificationService,
            dndService: dndService,
            focusIntegrationService: focusIntegration
        )
    }

    override func tearDown() {
        defer {
            for entry in priorUserDefaults {
                if let value = entry.value {
                    UserDefaults.standard.set(value, forKey: entry.key)
                } else {
                    UserDefaults.standard.removeObject(forKey: entry.key)
                }
            }
            priorUserDefaults = []
            super.tearDown()
        }

        sut.resetToIdle()
        FocusMetricsService.shared.clearAllRecords()
        sut = nil
        dndService = nil
        notificationService = nil
        soundPlayer = nil
        focusIntegration = nil
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

        sut.completeCurrentPhaseForTesting(sessionStartedAt: Date().addingTimeInterval(-6))

        XCTAssertEqual(FocusMetricsService.shared.records.last?.pomodorosCompleted, 1)
        XCTAssertFalse(sut.hasSession)
    }

    func testFourRoundNaturalCompletionRecordsFourPomodoros() {
        prepareWorkCompletion(rounds: 4, currentRound: 3)

        sut.completeCurrentPhaseForTesting(sessionStartedAt: Date().addingTimeInterval(-6))

        XCTAssertEqual(FocusMetricsService.shared.records.last?.pomodorosCompleted, 4)
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

    func testEndSessionDeactivatesOnlyInjectedIntegration() {
        prepareWorkCompletion(rounds: 1, currentRound: 0)

        sut.endSession(playCompletionSound: false)

        XCTAssertEqual(dndService.deactivationCount, 0)
        XCTAssertEqual(focusIntegration.deactivationCount, 1)
        XCTAssertTrue(focusIntegration.activatedModes.isEmpty)
        XCTAssertFalse(sut.hasSession)
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
    private(set) var events: [NotificationService.Event] = []

    func notify(_ event: NotificationService.Event) {
        events.append(event)
    }
}

@MainActor
private final class RecordingFocusTimerSoundPlayer: FocusTimerSoundPlayer {
    private(set) var playedSounds: [SoundPlayerService.SoundType] = []
    private(set) var completionSoundCount = 0

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

    private(set) var activatedModes: [FocusMode] = []
    private(set) var deactivationCount = 0
    private(set) var slackBreakActions: [SlackBreakAction] = []

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
