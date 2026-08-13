import Foundation
import Testing
@testable import Focally

@MainActor
@Suite("Focus integration DND transitions")
struct FocusIntegrationServiceTests {
    @Test func startIntentRejectsMissingOrAlreadyRunningSession() {
        #expect(throws: FocusIntegrationError.self) {
            try FocusIntegrationService.validateAppIntentAction(.start, hasSession: false, isPaused: false)
        }
        #expect(throws: FocusIntegrationError.self) {
            try FocusIntegrationService.validateAppIntentAction(.start, hasSession: true, isPaused: false)
        }
        #expect(throws: Never.self) {
            try FocusIntegrationService.validateAppIntentAction(.start, hasSession: true, isPaused: true)
        }
    }

    @Test func endIntentRequiresARealSession() {
        #expect(throws: FocusIntegrationError.self) {
            try FocusIntegrationService.validateAppIntentAction(.end, hasSession: false, isPaused: false)
        }
        #expect(throws: Never.self) {
            try FocusIntegrationService.validateAppIntentAction(.end, hasSession: true, isPaused: false)
        }
    }

    @Test func ownedDeactivationOpensNotificationCenterWithoutRunningFallbackWhenDirectPathSucceeds() async {
        let coordinator = TransitionPresenceCoordinator(active: false)
        let presenter = RecordingPresenter()
        var shortcuts: [FocusIntegrationAction] = []
        let service = makeService(
            coordinator: coordinator,
            presenter: presenter,
            shortcutBackup: { shortcuts.append($0) }
        )
        service.activateFocus(for: makeMode())
        await drainTasks()
        shortcuts.removeAll()

        service.deactivateFocus()
        await drainTasks()

        #expect(service.lastDNDOutcome == .deactivated)
        #expect(shortcuts.isEmpty)
        #expect(presenter.openCount == 1)
    }

    @Test func calendarHandoffDoesNotRunOffFallbackOrOpenNotificationCenter() async {
        let coordinator = TransitionPresenceCoordinator(active: false)
        coordinator.handoffOnEnd = true
        let presenter = RecordingPresenter()
        var shortcuts: [FocusIntegrationAction] = []
        let service = makeService(
            coordinator: coordinator,
            presenter: presenter,
            shortcutBackup: { shortcuts.append($0) }
        )
        service.activateFocus(for: makeMode())
        await drainTasks()
        shortcuts.removeAll()

        service.deactivateFocus()
        await drainTasks()

        #expect(service.lastDNDOutcome == .handedOff)
        #expect(shortcuts.isEmpty)
        #expect(presenter.openCount == 0)
    }

    @Test func missedDirectDeactivationRunsOneFallbackAndOpensOnlyAfterVerifiedInactive() async {
        let coordinator = TransitionPresenceCoordinator(active: false)
        coordinator.directDeactivationSucceeds = false
        let presenter = RecordingPresenter()
        var shortcuts: [FocusIntegrationAction] = []
        let service = makeService(
            coordinator: coordinator,
            presenter: presenter,
            shortcutBackup: { action in
                shortcuts.append(action)
                if action == .end { coordinator.isSystemDNDActive = false }
            }
        )
        service.activateFocus(for: makeMode())
        await drainTasks()
        shortcuts.removeAll()

        service.deactivateFocus()
        await drainTasks()

        #expect(shortcuts == [.end])
        #expect(service.lastDNDOutcome == .deactivated)
        #expect(presenter.openCount == 1)
    }

    @Test func failedDeactivationDoesNotOpenNotificationCenter() async {
        let coordinator = TransitionPresenceCoordinator(active: false)
        coordinator.directDeactivationSucceeds = false
        let presenter = RecordingPresenter()
        var shortcuts: [FocusIntegrationAction] = []
        let service = makeService(
            coordinator: coordinator,
            presenter: presenter,
            shortcutBackup: { shortcuts.append($0) }
        )
        service.activateFocus(for: makeMode())
        await drainTasks()
        shortcuts.removeAll()

        service.deactivateFocus()
        await drainTasks()

        #expect(shortcuts == [.end])
        #expect(service.lastDNDOutcome == .failed(targetActive: false))
        #expect(presenter.openCount == 0)
    }

    @Test func resumeClosesOwnedPanelBeforeStartingPresence() async {
        let coordinator = TransitionPresenceCoordinator(active: false)
        let presenter = RecordingPresenter()
        presenter.ownsVisiblePanel = true
        var events: [String] = []
        presenter.onClose = { events.append("close") }
        coordinator.onStart = { events.append("activate") }
        let service = makeService(coordinator: coordinator, presenter: presenter)

        service.activateFocus(for: makeMode())
        await drainTasks()

        #expect(events.prefix(2) == ["close", "activate"])
    }

    @Test func staleDeactivationCannotOpenPanelAfterResumeStarts() async {
        let coordinator = TransitionPresenceCoordinator(active: false)
        let presenter = RecordingPresenter()
        var suspended: [CheckedContinuation<Void, Never>] = []
        var shortcuts: [FocusIntegrationAction] = []
        let service = makeService(
            coordinator: coordinator,
            presenter: presenter,
            verificationDelay: {
                await withCheckedContinuation { suspended.append($0) }
            },
            shortcutBackup: { shortcuts.append($0) }
        )
        service.activateFocus(for: makeMode())
        await drainTasks()
        suspended.removeFirst().resume()
        await drainTasks()

        service.deactivateFocus()
        service.activateFocus(for: makeMode())
        await drainTasks()
        let pending = suspended
        suspended.removeAll()
        pending.forEach { $0.resume() }
        await drainTasks()

        #expect(presenter.openCount == 0)
        #expect(coordinator.isSystemDNDActive)
        #expect(shortcuts.isEmpty)
    }

    private func makeService(
        coordinator: TransitionPresenceCoordinator,
        presenter: RecordingPresenter,
        verificationDelay: @escaping () async -> Void = {},
        shortcutBackup: @escaping (FocusIntegrationAction) throws -> Void = { _ in }
    ) -> FocusIntegrationService {
        let suite = "FocusIntegrationServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return FocusIntegrationService(
            presenceCoordinator: coordinator,
            defaults: defaults,
            notificationCenterPresenter: presenter,
            verificationDelay: verificationDelay,
            shortcutBackup: shortcutBackup
        )
    }

    private func makeMode() -> FocusMode {
        FocusMode(name: "Focus", durationMinutes: 25, enableMacOSDND: true)
    }

    private func drainTasks() async {
        for _ in 0..<8 { await Task.yield() }
    }
}

@MainActor
private final class TransitionPresenceCoordinator: PresenceCoordinating {
    var currentPresence: PresenceState = .idle
    var isManualFocusActive = false
    var currentCalendarMeeting: CalendarMeeting?
    var isSystemDNDActive: Bool
    var ownsSystemDND = false
    var wantsSystemDND = false
    var handoffOnEnd = false
    var directDeactivationSucceeds = true
    var onStart: (() -> Void)?

    init(active: Bool) { isSystemDNDActive = active }

    func manualFocusStarted(mode: FocusMode, systemDNDEnabled: Bool) {
        onStart?()
        isManualFocusActive = true
        currentPresence = .manualFocus(mode)
        wantsSystemDND = systemDNDEnabled && mode.enableMacOSDND
        guard wantsSystemDND else { return }
        if !isSystemDNDActive {
            isSystemDNDActive = true
            ownsSystemDND = true
        }
    }

    func manualFocusEnded() {
        isManualFocusActive = false
        if handoffOnEnd {
            wantsSystemDND = true
            currentPresence = .calendarMeeting(CalendarMeeting(
                id: "meeting",
                title: "Meeting",
                startTime: Date(),
                endTime: Date().addingTimeInterval(300),
                isAllDay: false,
                hasVideoCall: true
            ))
            isSystemDNDActive = true
            return
        }
        currentPresence = .idle
        wantsSystemDND = false
        if ownsSystemDND && directDeactivationSucceeds {
            isSystemDNDActive = false
            ownsSystemDND = false
        }
    }

    func calendarMeetingUpdated(_ meeting: CalendarMeeting?) { currentCalendarMeeting = meeting }
    func calendarSettingsUpdated(_ settings: SlackCalendarSettings) {}
    func reapplyActivePresence() {}
}

@MainActor
private final class RecordingPresenter: NotificationCenterPresenting {
    var isAvailable = true
    var ownsVisiblePanel = false
    private(set) var openCount = 0
    private(set) var closeCount = 0
    var onClose: (() -> Void)?

    func openForBreak() async -> Bool {
        openCount += 1
        ownsVisiblePanel = true
        return true
    }

    func closeIfOwned() async {
        guard ownsVisiblePanel else { return }
        closeCount += 1
        onClose?()
        ownsVisiblePanel = false
    }
}
