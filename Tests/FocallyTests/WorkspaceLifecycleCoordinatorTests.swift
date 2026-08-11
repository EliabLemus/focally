import XCTest
@testable import Focally

@MainActor
final class WorkspaceLifecycleCoordinatorTests: XCTestCase {
    func testPopoverRoutingShowsWhenHidden() {
        let target = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)

        XCTAssertEqual(
            MenuBarPopoverRouting.action(
                isShown: false,
                currentScreenFrame: nil,
                targetScreenFrame: target
            ),
            .show
        )
    }

    func testPopoverRoutingClosesForSameDisplayClick() {
        let screen = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)

        XCTAssertEqual(
            MenuBarPopoverRouting.action(
                isShown: true,
                currentScreenFrame: screen,
                targetScreenFrame: screen
            ),
            .close
        )
    }

    func testPopoverRoutingReanchorsForDifferentDisplayClick() {
        let primary = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        let secondary = CGRect(x: 1_920, y: 0, width: 2_560, height: 1_440)

        XCTAssertEqual(
            MenuBarPopoverRouting.action(
                isShown: true,
                currentScreenFrame: primary,
                targetScreenFrame: secondary
            ),
            .reanchor
        )
    }

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
