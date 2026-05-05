import XCTest
@testable import Focally

// MARK: - TimerService Tests

class TimerServiceTests: XCTestCase {

    var timerService: FocusTimerService!

    override func setUp() {
        super.setUp()
        // Use minimal dependencies for unit testing
        timerService = FocusTimerService(
            soundPlayer: MockSoundPlayerService(),
            notificationService: MockNotificationService(),
            historyService: MockHistoryService()
        )
    }

    override func tearDown() {
        timerService = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(timerService.pomodoroState, .idle)
        XCTAssertFalse(timerService.isActive)
        XCTAssertFalse(timerService.isPaused)
        XCTAssertEqual(timerService.remainingSeconds, 0)
    }

    func testStartWorkSession() {
        let expectation = XCTestExpectation(description: "Session should start")

        timerService.startWorkSession(
            activity: "Test Task",
            emoji: "📝",
            durationMinutes: 25
        )

        // Verify state changes
        XCTAssertEqual(timerService.pomodoroState, .work)
        XCTAssertEqual(timerService.currentActivity, "Test Task")
        XCTAssertEqual(timerService.currentEmoji, "📝")
        XCTAssertEqual(timerService.remainingSeconds, 25 * 60)
        XCTAssertEqual(timerService.durationMinutes, 25)
        XCTAssert(timerService.isActive)
        XCTAssertFalse(timerService.isPaused)

        // Verify timer started
        XCTAssertNotNil(timerService.timer)

        // Wait a bit to verify timer counts down
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            XCTAssertGreaterThan(self.timerService.remainingSeconds, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
    }

    func testPauseAndResume() {
        // Start session
        timerService.startWorkSession(
            activity: "Test Task",
            emoji: "📝",
            durationMinutes: 25
        )

        // Pause session
        timerService.pauseSession()
        XCTAssertTrue(timerService.isPaused)

        // Verify timer is still active but paused
        XCTAssertNotNil(timerService.timer)

        // Resume session
        timerService.resumeSession()
        XCTAssertFalse(timerService.isPaused)

        // Verify timer is still active after resume
        XCTAssertNotNil(timerService.timer)
    }

    func testResetToIdle() {
        // Start session
        timerService.startWorkSession(
            activity: "Test Task",
            emoji: "📝",
            durationMinutes: 25
        )

        // Reset
        timerService.resetToIdle()

        // Verify state
        XCTAssertEqual(timerService.pomodoroState, .idle)
        XCTAssertFalse(timerService.isActive)
        XCTAssertFalse(timerService.isPaused)
        XCTAssertEqual(timerService.remainingSeconds, 0)
        XCTAssertEqual(timerService.currentActivity, "")
        XCTAssertEqual(timerService.currentEmoji, "📝")
    }

    func testDurationClamping() {
        // Test valid duration
        XCTAssertEqual(timerService.updateWorkDuration(minutes: 1), 1)
        XCTAssertEqual(timerService.updateShortBreakDuration(minutes: 5), 5)
        XCTAssertEqual(timerService.updateLongBreakDuration(minutes: 15), 15)

        // Test out of range (should clamp)
        XCTAssertEqual(timerService.updateWorkDuration(minutes: 0), 1)
        XCTAssertEqual(timerService.updateWorkDuration(minutes: 601), 600)
        XCTAssertEqual(timerService.updateShortBreakDuration(minutes: 0), 1)
        XCTAssertEqual(timerService.updateShortBreakDuration(minutes: 61), 60)
        XCTAssertEqual(timerService.updateLongBreakDuration(minutes: 0), 1)
        XCTAssertEqual(timerService.updateLongBreakDuration(minutes: 61), 60)
    }

    func testComputedProperties() {
        XCTAssertEqual(timerService.stateIcon, "⏸️")

        timerService.startWorkSession(
            activity: "Test Task",
            emoji: "📝",
            durationMinutes: 25
        )

        XCTAssertEqual(timerService.stateIcon, "🟢")
        XCTAssertTrue(timerService.isWork)
        XCTAssertFalse(timerService.isBreak)
        XCTAssertFalse(timerService.isLongBreak)

        timerService.startShortBreak()
        XCTAssertEqual(timerService.stateIcon, "🟡")
        XCTAssertTrue(timerService.isBreak)
        XCTAssertFalse(timerService.isWork)

        timerService.startLongBreak()
        XCTAssertEqual(timerService.stateIcon, "🔵")
        XCTAssertTrue(timerService.isLongBreak)

        timerService.resetToIdle()
        XCTAssertEqual(timerService.stateIcon, "⏸️")
    }
}

// MARK: - DNDService Tests

class DNDServiceTests: XCTestCase {

    var dndService: DNDService!

    override func setUp() {
        super.setUp()
        dndService = DNDService()
    }

    override func tearDown() {
        dndService = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertFalse(dndService.isDNDActive)
    }

    func testDeactivateDNDWhenNotActive() {
        // Should not error if called when already inactive
        dndService.deactivateDND()
        XCTAssertFalse(dndService.isDNDActive)
    }

    func testActivateDeactivateFlow() {
        // Activate
        dndService.activateDND()
        XCTAssertTrue(dndService.isDNDActive)

        // Deactivate
        dndService.deactivateDND()
        XCTAssertFalse(dndService.isDNDActive)
    }

    func testDoubleActivation() {
        // Activate twice
        dndService.activateDND()
        dndService.activateDND()

        // Should remain active (no error)
        XCTAssertTrue(dndService.isDNDActive)

        // Deactivate
        dndService.deactivateDND()
        XCTAssertFalse(dndService.isDNDActive)
    }

    func testDoubleDeactivation() {
        // Deactivate twice
        dndService.deactivateDND()
        dndService.deactivateDND()

        // Should remain inactive (no error)
        XCTAssertFalse(dndService.isDNDActive)

        // Activate
        dndService.activateDND()
        XCTAssertTrue(dndService.isDNDActive)
    }

    func testActivateDeactivateCycle() {
        // Activate
        dndService.activateDND()
        XCTAssertTrue(dndService.isDNDActive)

        // Deactivate
        dndService.deactivateDND()
        XCTAssertFalse(dndService.isDNDActive)

        // Activate again
        dndService.activateDND()
        XCTAssertTrue(dndService.isDNDActive)

        // Deactivate again
        dndService.deactivateDND()
        XCTAssertFalse(dndService.isDNDActive)
    }
}

// MARK: - Mock Services

class MockSoundPlayerService: SoundPlayerService {
    var shouldPlaySound = false

    func play(_ sound: SoundType) {
        shouldPlaySound = true
    }

    func stopAll() {
        shouldPlaySound = false
    }
}

class MockNotificationService: NotificationService {
    var notificationsSent: [String] = []

    func notify(_ type: NotificationType) {
        notificationsSent.append(type.rawValue)
    }

    func requestAuthorization() {
        // Mock implementation
    }
}

class MockHistoryService: HistoryService {
    var recordedSessions: [(activity: String, emoji: String, duration: Int, round: Int, startTime: Date, endTime: Date)] = []

    func recordWorkSession(
        activity: String,
        emoji: String,
        durationMinutes: Int,
        round: Int,
        startTime: Date,
        endTime: Date
    ) {
        recordedSessions.append((activity, emoji, durationMinutes, round, startTime, endTime))
    }
}
