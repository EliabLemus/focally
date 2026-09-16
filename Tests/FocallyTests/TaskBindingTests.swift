import XCTest
@testable import Focally

@MainActor
final class TaskBindingTests: XCTestCase {
    private let baseDate = Date(timeIntervalSince1970: 2_000_000_000)
    private let taskID = UUID()

    // MARK: - Fakes (file-private; the ones in FocusTimerServiceTests are private to that file)

    private final class StubDND: FocusTimerDND {
        func deactivateDND() {}
    }

    private final class StubSoundPlayer: FocusTimerSoundPlayer {
        func play(_ soundType: SoundPlayerService.SoundType) {}
        func playCompletionSound() {}
    }

    private final class StubNotification: FocusTimerNotification {
        func notify(_ event: NotificationService.Event) {}
    }

    private final class StubIntegration: FocusTimerIntegration {
        func activateFocus(for mode: FocusMode) {}
        func deactivateFocus() {}
        func performSlackBreakAction(breakLabel: String?, isLongBreak: Bool, breakDurationMinutes: Int, modeName: String, modeEmoji: String) {}
    }

    private final class StubPersistence: FocusSessionPersisting {
        var snapshot: PersistedFocusSession?
        func load() -> PersistedFocusSession? { snapshot }
        func save(_ snapshot: PersistedFocusSession) { self.snapshot = snapshot }
        func clear() { snapshot = nil }
    }

    private final class StubTicker: FocusTimerTicker {
        var action: (@MainActor () -> Void)?
        var isRunning: Bool { action != nil }
        func start(_ tick: @escaping @MainActor () -> Void) { action = tick }
        func stop() { action = nil }
    }

    private func makeTimer(persistence: StubPersistence, ticker: StubTicker) -> FocusTimerService {
        FocusTimerService(
            settingsStore: SettingsStore(),
            soundPlayer: StubSoundPlayer(),
            notificationService: StubNotification(),
            dndService: StubDND(),
            focusIntegrationService: StubIntegration(),
            persistence: persistence,
            ticker: ticker,
            now: { [baseDate] in baseDate },
            defaults: UserDefaults(suiteName: "TaskBindingTests.\(UUID().uuidString)")
        )
    }

    private func makeSnapshot(taskID: UUID?) -> PersistedFocusSession {
        PersistedFocusSession(
            sessionID: UUID(),
            modeSnapshot: FocusMode.builtInModes[0],
            sessionStartedAt: baseDate,
            phase: .work,
            phaseStartedAt: baseDate,
            phaseTargetEndDate: baseDate.addingTimeInterval(1500),
            phaseDurationSeconds: 1500,
            isPaused: false,
            pausedAt: nil,
            pausedRemainingSeconds: nil,
            currentRound: 0,
            pomodoroRounds: 4,
            accumulatedActiveSeconds: 0,
            accumulatedBreakSeconds: 0,
            accumulatedPausedSeconds: 0,
            savedAt: baseDate.addingTimeInterval(100),
            taskID: taskID
        )
    }

    private func roundTrip(_ snapshot: PersistedFocusSession) throws -> PersistedFocusSession {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PersistedFocusSession.self, from: encoder.encode(snapshot))
    }

    // MARK: - Snapshot round trip (schema stays v1)

    func testSnapshotRoundTripPreservesTaskID() throws {
        let snapshot = makeSnapshot(taskID: taskID)
        XCTAssertTrue(snapshot.isValid(at: baseDate.addingTimeInterval(200)))
        let decoded = try roundTrip(snapshot)
        XCTAssertEqual(decoded.taskID, taskID)
        XCTAssertEqual(decoded.schemaVersion, 1)
    }

    func testLegacySnapshotWithoutTaskIDDecodesNilAndStaysValid() throws {
        let decoded = try roundTrip(makeSnapshot(taskID: nil))
        XCTAssertNil(decoded.taskID)
        XCTAssertTrue(decoded.isValid(at: baseDate.addingTimeInterval(200)))
    }

    // MARK: - Session start persists the binding

    func testStartSessionWithTaskIDPersistsBindingInSnapshot() {
        let persistence = StubPersistence()
        let timer = makeTimer(persistence: persistence, ticker: StubTicker())

        let draft = FocusSessionDraft(mode: FocusMode.builtInModes[0], activity: "Deep work")
        timer.startSession(draft: draft, taskID: taskID)

        XCTAssertEqual(persistence.snapshot?.taskID, taskID)
        XCTAssertEqual(timer.activeTaskID, taskID)
    }

    func testStartSessionWithoutTaskKeepsBindingNil() {
        let persistence = StubPersistence()
        let timer = makeTimer(persistence: persistence, ticker: StubTicker())

        timer.startSession(mode: FocusMode.builtInModes[0])

        XCTAssertNil(persistence.snapshot?.taskID)
        XCTAssertNil(timer.activeTaskID)
    }
}
