import Foundation
import EventKit
import Testing

@testable import Focally

// TASK-057 tests 11, 12: calendar → Slack sync default OFF + one-time
// migration via an injected UserDefaults suite.

@MainActor
private final class CountingPresenceCoordinator: PresenceCoordinating {
    var currentPresence: PresenceState = .idle
    var isManualFocusActive = false
    var currentCalendarMeeting: CalendarMeeting?
    var isSystemDNDActive = false
    private(set) var calendarMeetingUpdateCount = 0
    private(set) var lastMeetingUpdate: CalendarMeeting?

    func manualFocusStarted(mode: FocusMode, systemDNDEnabled: Bool) {}
    func manualFocusEnded() {}
    func calendarMeetingUpdated(_ meeting: CalendarMeeting?) {
        calendarMeetingUpdateCount += 1
        lastMeetingUpdate = meeting
    }
    func calendarSettingsUpdated(_ settings: SlackCalendarSettings) {}
}

@MainActor
final class CalendarSyncDefaultTests {
    private func makeMeeting(now: Date) -> CalendarMeeting {
        CalendarMeeting(
            id: "evt",
            title: "Planning",
            startTime: now.addingTimeInterval(-300),
            endTime: now.addingTimeInterval(3_600),
            isAllDay: false,
            hasVideoCall: true
        )
    }

    private func makeService(
        defaults: UserDefaults,
        coordinator: CountingPresenceCoordinator,
        meeting: CalendarMeeting?
    ) -> CalendarSlackIntegrationService {
        CalendarSlackIntegrationService(
            presenceCoordinator: coordinator,
            defaults: defaults,
            notificationCenter: NotificationCenter(),
            eventStoreChangedNotification: Notification.Name("CalendarSyncDefaultTests.\(UUID().uuidString)"),
            authorizationStatusProvider: { .fullAccess },
            eventFetcher: { meeting == nil ? [] : [meeting!] }
        )
    }

    // MARK: Test 11 — sync off by default on fresh install

    @Test func freshInstallDefaultsSyncOffAndEventDoesNotReachPresenceCoordinator() {
        let suiteName = "CalendarSyncDefaultTests.fresh.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = CountingPresenceCoordinator()
        let now = Date()
        let service = makeService(defaults: defaults, coordinator: coordinator, meeting: makeMeeting(now: now))

        #expect(service.calendarSlackSyncEnabled == false)

        service.startIfEnabled()

        // An event is inside the calendar window right now, but the sync gate
        // is off → monitoring never starts and presence never hears about it.
        #expect(service.currentMeeting == nil)
        #expect(coordinator.calendarMeetingUpdateCount == 0)
        service.stopMonitoring()
    }

    @Test func enablingSyncRestoresTask004CalendarPresenceBehavior() {
        let suiteName = "CalendarSyncDefaultTests.enabled.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = CountingPresenceCoordinator()
        let now = Date()
        let service = makeService(defaults: defaults, coordinator: coordinator, meeting: makeMeeting(now: now))

        service.startIfEnabled()
        #expect(coordinator.calendarMeetingUpdateCount == 0)

        // User toggles the sync ON (settings panel): same event now sets presence.
        service.calendarSlackSyncEnabled = true
        service.stopMonitoring()
        service.startIfEnabled()

        #expect(coordinator.calendarMeetingUpdateCount >= 1)
        #expect(coordinator.lastMeetingUpdate?.id == "evt")
        service.stopMonitoring()
    }

    // MARK: Test 12 — one-time migration

    @Test func migrationPreservesPriorBehaviorAndStampsKeyOnce() {
        let suiteName = "CalendarSyncDefaultTests.migration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Existing install that relied on the sync (calendar toggle was ON).
        defaults.set(true, forKey: CalendarSlackIntegrationService.enabledDefaultsKey)
        #expect(defaults.object(forKey: CalendarSlackIntegrationService.syncMigratedDefaultsKey) == nil)

        CalendarSlackIntegrationService.migrateCalendarSlackSyncDefault(defaults: defaults)

        #expect(defaults.bool(forKey: CalendarSlackIntegrationService.syncEnabledDefaultsKey) == true)
        #expect(defaults.bool(forKey: CalendarSlackIntegrationService.syncMigratedDefaultsKey) == true)

        // Second launch / re-run does NOT re-migrate: a changed effective state
        // stays as the user set it.
        defaults.set(false, forKey: CalendarSlackIntegrationService.syncEnabledDefaultsKey)
        CalendarSlackIntegrationService.migrateCalendarSlackSyncDefault(defaults: defaults)
        #expect(defaults.bool(forKey: CalendarSlackIntegrationService.syncEnabledDefaultsKey) == false)
    }

    @Test func migrationOfExistingInstallWithoutSyncDefaultsSyncOff() {
        let suiteName = "CalendarSyncDefaultTests.migration-off.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Existing install with the calendar feature OFF → sync stays off too.
        defaults.set(false, forKey: CalendarSlackIntegrationService.enabledDefaultsKey)
        CalendarSlackIntegrationService.migrateCalendarSlackSyncDefault(defaults: defaults)

        #expect(defaults.bool(forKey: CalendarSlackIntegrationService.syncEnabledDefaultsKey) == false)
        #expect(defaults.bool(forKey: CalendarSlackIntegrationService.syncMigratedDefaultsKey) == true)
    }

    @Test func freshInstallInitRunsMigrationAndGatesEvents() {
        let suiteName = "CalendarSyncDefaultTests.init-migrates.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = CountingPresenceCoordinator()
        _ = makeService(defaults: defaults, coordinator: coordinator, meeting: nil)

        // init called migrateCalendarSlackSyncDefault exactly once.
        #expect(defaults.bool(forKey: CalendarSlackIntegrationService.syncMigratedDefaultsKey) == true)
    }
}
