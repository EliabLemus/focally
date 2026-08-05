import XCTest
@testable import Focally

@MainActor
final class WorkspaceLifecycleCoordinatorTests: XCTestCase {
    func testStartRegistersBothRoutesExactlyOnceAndDoesNotDuplicateRegistration() {
        let center = NotificationCenter()
        let willSleep = Notification.Name("test.workspace.willSleep")
        let didWake = Notification.Name("test.workspace.didWake")
        var sleepCount = 0
        var wakeCount = 0
        let sut = WorkspaceLifecycleCoordinator(
            notificationCenter: center,
            willSleepName: willSleep,
            didWakeName: didWake,
            willSleep: { sleepCount += 1 },
            didWake: { wakeCount += 1 }
        )

        sut.start()
        sut.start()
        center.post(name: willSleep, object: nil)
        center.post(name: didWake, object: nil)

        XCTAssertEqual(sleepCount, 1)
        XCTAssertEqual(wakeCount, 1)
    }

    func testStopRemovesObservers() {
        let center = NotificationCenter()
        let willSleep = Notification.Name("test.workspace.remove.willSleep")
        let didWake = Notification.Name("test.workspace.remove.didWake")
        var sleepCount = 0
        var wakeCount = 0
        let sut = WorkspaceLifecycleCoordinator(
            notificationCenter: center,
            willSleepName: willSleep,
            didWakeName: didWake,
            willSleep: { sleepCount += 1 },
            didWake: { wakeCount += 1 }
        )
        sut.start()

        sut.stop()
        center.post(name: willSleep, object: nil)
        center.post(name: didWake, object: nil)

        XCTAssertEqual(sleepCount, 0)
        XCTAssertEqual(wakeCount, 0)
    }
}
