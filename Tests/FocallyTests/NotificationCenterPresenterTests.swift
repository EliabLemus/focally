import Testing
@testable import Focally

@MainActor
@Suite("Notification Center presenter")
struct NotificationCenterPresenterTests {
    @Test func openRecordsOwnershipOnlyAfterSystemPanelBecomesVisible() async {
        let system = RecordingNotificationCenterSystem(isTrusted: true)
        system.openResult = true
        let presenter = NotificationCenterPresenter(system: system)

        let opened = await presenter.openForBreak()

        #expect(opened)
        #expect(presenter.ownsVisiblePanel)
        #expect(system.openCount == 1)
    }

    @Test func unavailableAccessibilityDoesNotAttemptToOpen() async {
        let system = RecordingNotificationCenterSystem(isTrusted: false)
        let presenter = NotificationCenterPresenter(system: system)

        let opened = await presenter.openForBreak()

        #expect(!opened)
        #expect(!presenter.ownsVisiblePanel)
        #expect(system.openCount == 0)
    }

    @Test func closeOnlyClosesPanelOwnedByFocally() async {
        let system = RecordingNotificationCenterSystem(isTrusted: true)
        system.openResult = true
        let presenter = NotificationCenterPresenter(system: system)
        _ = await presenter.openForBreak()

        await presenter.closeIfOwned()
        await presenter.closeIfOwned()

        #expect(system.closeCount == 1)
        #expect(!presenter.ownsVisiblePanel)
    }

    @Test func userClosingPanelInvalidatesOwnershipWithoutTogglingItBackOpen() async {
        let system = RecordingNotificationCenterSystem(isTrusted: true)
        system.openResult = true
        let presenter = NotificationCenterPresenter(system: system)
        _ = await presenter.openForBreak()
        system.isVisible = false

        await presenter.closeIfOwned()

        #expect(system.closeCount == 0)
        #expect(!presenter.ownsVisiblePanel)
    }
}

@MainActor
private final class RecordingNotificationCenterSystem: NotificationCenterSystemControlling {
    var isTrusted: Bool
    var isVisible = false
    var openResult = false
    private(set) var openCount = 0
    private(set) var closeCount = 0

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func open() async -> Bool {
        openCount += 1
        isVisible = openResult
        return openResult
    }

    func close() async -> Bool {
        closeCount += 1
        isVisible = false
        return true
    }
}
