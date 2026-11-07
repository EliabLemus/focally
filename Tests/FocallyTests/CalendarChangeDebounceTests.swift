import Foundation
import EventKit
import Testing

@testable import Focally

// TASK-063: EKEventStoreChanged bursts coalesce into a single refetch after
// the debounce window. Manual scheduler mirrors MediaDeviceCallDetectorTests.

@MainActor
private final class ManualScheduler {
    private(set) var pending: [(delay: TimeInterval, action: @MainActor () -> Void)] = []
    private(set) var cancelCount = 0

    func schedule(_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        pending.append((delay, action))
    }

    func cancel(_ id: UUID) { cancelCount += 1 }

    func advance(_ interval: TimeInterval) {
        let due = pending.filter { $0.delay <= interval }
        pending.removeAll { $0.delay <= interval }
        for item in due { item.action() }
    }
}

@MainActor
private final class CountingPresenceCoordinator: PresenceCoordinating {
    var currentPresence: PresenceState = .idle
    var isManualFocusActive = false
    var currentCalendarMeeting: CalendarMeeting?
    var isSystemDNDActive = false

    func manualFocusStarted(mode: FocusMode, systemDNDEnabled: Bool) {}
    func manualFocusEnded() {}
    func calendarMeetingUpdated(_ meeting: CalendarMeeting?) {}
    func calendarSettingsUpdated(_ settings: SlackCalendarSettings) {}
}

@MainActor
final class CalendarChangeDebounceTests {
    /// Reference cell so the closure above can mutate the count (class box
    /// keeps the closure escaping-safe).
    private final class FetchBox: @unchecked Sendable {
        var count = 0
    }

    /// NotificationCenter delivers the observer block via the main queue and
    /// the handler runs as a MainActor task; neither reliably interleaves with
    /// Task.yield or main-queue hops, so poll until the condition holds.
    private func waitUntil(
        _ condition: @MainActor () -> Bool,
        timeout: TimeInterval = 2.0
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            // El observer corre en la main DispatchQueue: Task.sleep NO la drena.
            // Rotar el runloop main sí ejecuta los bloques encolados en .main.
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    @Test func burstOfNotificationsCoalescesIntoOneRefetch() async {
        let scheduler = ManualScheduler()
        let notificationCenter = NotificationCenter()
        let name = Notification.Name("CalendarChangeDebounceTests.burst.\(UUID().uuidString)")
        let box = FetchBox()
        let coordinator = CountingPresenceCoordinator()
        let defaults = UserDefaults(suiteName: "CalendarChangeDebounceTests.burst.\(UUID().uuidString)")!
        let service = CalendarSlackIntegrationService(
            presenceCoordinator: coordinator,
            defaults: defaults,
            notificationCenter: notificationCenter,
            eventStoreChangedNotification: name,
            debounceInterval: 2.0,
            schedule: { scheduler.schedule($0, $1) },
            cancel: { scheduler.cancel($0) },
            authorizationStatusProvider: { .fullAccess },
            eventFetcher: { box.count += 1; return [] }
        )
        defaults.set(true, forKey: CalendarSlackIntegrationService.syncEnabledDefaultsKey) // DESPUÉS del init: migrateCalendarSlackSyncDefault puede sobrescribir
        service.startIfEnabled()

        // Burst: 5 notifications inside the window.
        for _ in 0..<5 {
            notificationCenter.post(name: name, object: nil)
        }
        // All 5 scheduled (each cancels the previous token), only the last fires.
        // Baseline: startMonitoring hace 1 refetch inicial.
        #expect(await waitUntil { scheduler.pending.count == 5 })
        #expect(box.count == 1)

        scheduler.advance(2.0)
        #expect(await waitUntil { box.count == 2 })
    }

    @Test func isolatedNotificationRefetchesAfterWindow() async {
        let scheduler = ManualScheduler()
        let notificationCenter = NotificationCenter()
        let name = Notification.Name("CalendarChangeDebounceTests.single.\(UUID().uuidString)")
        let box = FetchBox()
        let coordinator = CountingPresenceCoordinator()
        let defaults = UserDefaults(suiteName: "CalendarChangeDebounceTests.single.\(UUID().uuidString)")!
        let service = CalendarSlackIntegrationService(
            presenceCoordinator: coordinator,
            defaults: defaults,
            notificationCenter: notificationCenter,
            eventStoreChangedNotification: name,
            debounceInterval: 2.0,
            schedule: { scheduler.schedule($0, $1) },
            cancel: { scheduler.cancel($0) },
            authorizationStatusProvider: { .fullAccess },
            eventFetcher: { box.count += 1; return [] }
        )
        defaults.set(true, forKey: CalendarSlackIntegrationService.syncEnabledDefaultsKey) // DESPUÉS del init: migrateCalendarSlackSyncDefault puede sobrescribir
        service.startIfEnabled()

        notificationCenter.post(name: name, object: nil)
        #expect(await waitUntil { scheduler.pending.count == 1 })
        scheduler.advance(2.0)
        #expect(await waitUntil { box.count == 2 }) // baseline 1 (refetch inicial) + 1 debounced
    }

    @Test func stopCancelsPendingDebounce() async {
        let scheduler = ManualScheduler()
        let notificationCenter = NotificationCenter()
        let name = Notification.Name("CalendarChangeDebounceTests.stop.\(UUID().uuidString)")
        let box = FetchBox()
        let coordinator = CountingPresenceCoordinator()
        let defaults = UserDefaults(suiteName: "CalendarChangeDebounceTests.stop.\(UUID().uuidString)")!
        let service = CalendarSlackIntegrationService(
            presenceCoordinator: coordinator,
            defaults: defaults,
            notificationCenter: notificationCenter,
            eventStoreChangedNotification: name,
            debounceInterval: 2.0,
            schedule: { scheduler.schedule($0, $1) },
            cancel: { scheduler.cancel($0) },
            authorizationStatusProvider: { .fullAccess },
            eventFetcher: { box.count += 1; return [] }
        )
        defaults.set(true, forKey: CalendarSlackIntegrationService.syncEnabledDefaultsKey) // DESPUÉS del init: migrateCalendarSlackSyncDefault puede sobrescribir
        service.startIfEnabled()
        print("DEBUG_START access=\(service.hasCalendarAccess) sync=\(service.calendarSlackSyncEnabled)")

        notificationCenter.post(name: name, object: nil)
        #expect(await waitUntil { scheduler.pending.count == 1 })
        service.stopMonitoring()

        scheduler.advance(2.0)
        #expect(box.count == 1) // solo el refetch inicial: el debounce quedó cancelado
    }
}
