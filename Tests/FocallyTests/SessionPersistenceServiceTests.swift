import XCTest
@testable import Focally

@MainActor
final class SessionPersistenceServiceTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL!
    private var now: Date!
    private var sut: SessionPersistenceService!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        fileURL = directory.appendingPathComponent("active_session.json")
        now = Date(timeIntervalSince1970: 2_000_000_000)
        sut = SessionPersistenceService(fileURL: fileURL, now: { [unowned self] in now })
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        sut = nil; fileURL = nil; directory = nil; now = nil
    }

    func testCodableRoundTripPreservesFullModeAndAllFields() throws {
        let snapshot = makeSnapshot()
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode(PersistedFocusSession.self, from: encoder.encode(snapshot)), snapshot)
    }

    func testFirstAtomicSaveAndReplacementBothSucceed() {
        let first = makeSnapshot()
        sut.save(first)
        XCTAssertEqual(sut.load(), first)
        var replacement = first
        replacement.currentRound = 1
        replacement.savedAt = now.addingTimeInterval(1)
        now.addTimeInterval(1)
        sut.save(replacement)
        XCTAssertEqual(sut.load(), replacement)
    }

    func testClearRemovesSnapshot() {
        sut.save(makeSnapshot())
        sut.clear()
        XCTAssertNil(sut.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testCorruptJSONIsRejectedAndCleared() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: fileURL)
        XCTAssertNil(sut.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testUnknownSchemaIsRejectedAndCleared() {
        var snapshot = makeSnapshot(); snapshot.schemaVersion = 2
        writeUnvalidated(snapshot)
        XCTAssertNil(sut.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testInvalidInvariantsAreRejected() {
        var invalid = makeSnapshot()
        invalid.phase = .idle
        writeUnvalidated(invalid)
        XCTAssertNil(sut.load())

        invalid = makeSnapshot(); invalid.phaseDurationSeconds = 0
        writeUnvalidated(invalid)
        XCTAssertNil(sut.load())

        invalid = makeSnapshot(); invalid.isPaused = true; invalid.pausedAt = now; invalid.pausedRemainingSeconds = 30
        writeUnvalidated(invalid)
        XCTAssertNil(sut.load())
    }

    func testRoundsAndCurrentRoundValidation() {
        var snapshot = makeSnapshot(); snapshot.pomodoroRounds = 0
        XCTAssertFalse(snapshot.isValid(at: now))
        snapshot = makeSnapshot(); snapshot.currentRound = snapshot.pomodoroRounds
        XCTAssertFalse(snapshot.isValid(at: now))
        snapshot = makeSnapshot(); snapshot.pomodoroRounds = 3
        XCTAssertFalse(snapshot.isValid(at: now))
    }

    func testActiveTargetRejectsRemainingExtensionAndTimelineExtensionAttack() {
        var snapshot = makeSnapshot()
        snapshot.savedAt = now.addingTimeInterval(10 * 60)
        snapshot.phaseTargetEndDate = snapshot.savedAt.addingTimeInterval(1500 + PersistedFocusSession.clockTolerance + 1)
        XCTAssertFalse(snapshot.isValid(at: snapshot.savedAt))

        snapshot = makeSnapshot()
        snapshot.accumulatedPausedSeconds = 60
        snapshot.phaseTargetEndDate = snapshot.phaseStartedAt.addingTimeInterval(1500 + 60 + PersistedFocusSession.clockTolerance + 1)
        XCTAssertFalse(snapshot.isValid(at: now))
    }

    func testValidExpiredActiveAndCoherentPausedSnapshotsSurviveValidation() {
        var expired = makeSnapshot()
        expired.savedAt = now.addingTimeInterval(30 * 60)
        XCTAssertTrue(expired.isValid(at: expired.savedAt))

        var paused = makeSnapshot()
        paused.isPaused = true
        paused.phaseTargetEndDate = nil
        paused.pausedAt = now.addingTimeInterval(5 * 60)
        paused.savedAt = paused.pausedAt!
        paused.pausedRemainingSeconds = 20 * 60
        XCTAssertTrue(paused.isValid(at: paused.savedAt))
    }

    func testPausedDatesAndRemainingMustBeCoherent() {
        var snapshot = makeSnapshot()
        snapshot.isPaused = true; snapshot.phaseTargetEndDate = nil
        snapshot.pausedAt = now.addingTimeInterval(5 * 60); snapshot.savedAt = snapshot.pausedAt!
        snapshot.pausedRemainingSeconds = 24 * 60
        XCTAssertFalse(snapshot.isValid(at: snapshot.savedAt))

        snapshot.pausedRemainingSeconds = 20 * 60
        snapshot.pausedAt = snapshot.savedAt.addingTimeInterval(10)
        XCTAssertFalse(snapshot.isValid(at: snapshot.savedAt))
    }

    func testNegativeAndNonFiniteAccumulatorsAreRejected() {
        var snapshot = makeSnapshot(); snapshot.accumulatedActiveSeconds = -1
        XCTAssertFalse(snapshot.isValid(at: now))
        snapshot = makeSnapshot(); snapshot.accumulatedBreakSeconds = -.infinity
        XCTAssertFalse(snapshot.isValid(at: now))
        snapshot = makeSnapshot(); snapshot.accumulatedPausedSeconds = .nan
        XCTAssertFalse(snapshot.isValid(at: now))
    }

    func testFutureAndOutOfOrderDatesAreRejected() {
        var snapshot = makeSnapshot()
        snapshot.savedAt = now.addingTimeInterval(PersistedFocusSession.maximumFutureSkew + 1)
        XCTAssertFalse(snapshot.isValid(at: now))

        snapshot = makeSnapshot()
        snapshot.sessionStartedAt = snapshot.phaseStartedAt.addingTimeInterval(1)
        XCTAssertFalse(snapshot.isValid(at: now))

        snapshot = makeSnapshot()
        snapshot.phaseStartedAt = snapshot.savedAt.addingTimeInterval(PersistedFocusSession.maximumFutureSkew + 1)
        snapshot.phaseTargetEndDate = snapshot.phaseStartedAt.addingTimeInterval(1500)
        XCTAssertFalse(snapshot.isValid(at: now))
    }

    func testSnapshotOlderThanSevenDaysIsRejected() {
        var snapshot = makeSnapshot()
        snapshot.sessionStartedAt = now.addingTimeInterval(-PersistedFocusSession.maximumAge - 1)
        snapshot.phaseStartedAt = snapshot.sessionStartedAt
        snapshot.phaseTargetEndDate = snapshot.phaseStartedAt.addingTimeInterval(1500)
        writeUnvalidated(snapshot)
        XCTAssertNil(sut.load())
    }

    private func makeSnapshot() -> PersistedFocusSession {
        let mode = FocusMode(
            name: "Deep Work", emoji: ":rocket:", statusText: "Busy", durationMinutes: 25,
            enableMacOSDND: true, enableSlackDND: true, enablePomodoro: true,
            pomodoroWorkMinutes: 25, pomodoroBreakMinutes: 5, pomodoroLongBreakMinutes: 15,
            pomodoroRounds: 4, breakLabel: ":coffee: Reset", typeDescriptor: .builtIn(.focusTime)
        ).sanitized()
        return PersistedFocusSession(
            sessionID: UUID(), modeSnapshot: mode, sessionStartedAt: now,
            phase: .work, phaseStartedAt: now, phaseTargetEndDate: now.addingTimeInterval(1500),
            phaseDurationSeconds: 1500, isPaused: false, pausedAt: nil, pausedRemainingSeconds: nil,
            currentRound: 0, pomodoroRounds: 4, accumulatedActiveSeconds: 0,
            accumulatedBreakSeconds: 0, accumulatedPausedSeconds: 0, savedAt: now
        )
    }

    private func writeUnvalidated(_ snapshot: PersistedFocusSession) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try? encoder.encode(snapshot).write(to: fileURL)
    }
}
