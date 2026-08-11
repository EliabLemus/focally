import EventKit
import Foundation
import Observation

@MainActor
@Observable
final class CalendarSlackIntegrationService {
    static let enabledDefaultsKey = "calendarEnabled"
    static let showMeetingTitleDefaultsKey = "calendarShowMeetingTitle"
    static let dndForMeetingsDefaultsKey = "calendarDndForMeetings"
    private static let slackSettingsDefaultsKey = "focally.calendar.slackSettings"

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Self.enabledDefaultsKey)
        }
    }
    private(set) var hasCalendarAccess: Bool
    private var events: [CalendarMeeting] = []
    private(set) var currentMeeting: CalendarMeeting?
    var connectionError: String?
    var calendarSettings: SlackCalendarSettings {
        didSet {
            saveCalendarSettings()
            presenceCoordinator.calendarSettingsUpdated(calendarSettings)
        }
    }

    var showCalendarInSlack: Bool {
        get { calendarSettings.showCalendarInSlack }
        set { calendarSettings.showCalendarInSlack = newValue }
    }

    var titleDisplay: CalendarTitleDisplay {
        get { calendarSettings.titleDisplay }
        set { calendarSettings.titleDisplay = newValue }
    }

    var useEventEmojisForStatus: Bool {
        get { calendarSettings.useEventEmojisForStatus }
        set { calendarSettings.useEventEmojisForStatus = newValue }
    }

    var activateDNDForVideoCalls: Bool {
        get { calendarSettings.activateDNDForVideoCalls }
        set { calendarSettings.activateDNDForVideoCalls = newValue }
    }

    var showMeetingTitle: Bool {
        get { titleDisplay == .showFullTitle }
        set { titleDisplay = newValue ? .showFullTitle : .showVideoCallOnly }
    }

    var dndForMeetings: Bool {
        get { activateDNDForVideoCalls }
        set { activateDNDForVideoCalls = newValue }
    }

    private let eventStore: EKEventStore
    private let presenceCoordinator: PresenceCoordinating
    private let metricsTracker: CalendarMetricsTracker
    private let defaults: UserDefaults
    private var timer: Timer?

    init(
        eventStore: EKEventStore = EKEventStore(),
        presenceCoordinator: PresenceCoordinating,
        metricsTracker: CalendarMetricsTracker? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.eventStore = eventStore
        self.presenceCoordinator = presenceCoordinator
        self.defaults = defaults
        self.metricsTracker = metricsTracker ?? CalendarMetricsTracker(
            persistence: UserDefaultsCalendarMetricsDraftPersistence(),
            metrics: FocusMetricsService.shared
        )
        isEnabled = defaults.bool(forKey: Self.enabledDefaultsKey)
        if let data = defaults.data(forKey: Self.slackSettingsDefaultsKey),
           let settings = try? JSONDecoder().decode(SlackCalendarSettings.self, from: data) {
            calendarSettings = settings
        } else {
            calendarSettings = SlackCalendarSettings(
                showCalendarInSlack: defaults.bool(forKey: Self.enabledDefaultsKey),
                titleDisplay: defaults.bool(forKey: Self.showMeetingTitleDefaultsKey)
                    ? .showFullTitle
                    : .showVideoCallOnly,
                useEventEmojisForStatus: false,
                activateDNDForVideoCalls: defaults.bool(forKey: Self.dndForMeetingsDefaultsKey)
            )
        }
        hasCalendarAccess = EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func startIfEnabled() {
        guard isEnabled else {
            metricsTracker.finishBecauseMonitoringStopped()
            return
        }
        if hasCalendarAccess {
            startPeriodicCheck()
        } else {
            requestCalendarAccess()
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            requestCalendarAccess()
        } else {
            stopMonitoring()
        }
    }

    func requestCalendarAccess() {
        guard isEnabled else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                hasCalendarAccess = granted
                connectionError = granted ? nil : "Calendar access was not granted"
                if granted {
                    startPeriodicCheck()
                } else {
                    stopMonitoring()
                }
            } catch {
                hasCalendarAccess = false
                connectionError = error.localizedDescription
                stopMonitoring()
            }
        }
    }

    func fetchTodayEvents() {
        let authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        hasCalendarAccess = Self.canReadCalendar(
            isEnabled: isEnabled,
            authorizationStatus: authorizationStatus
        )
        guard hasCalendarAccess else {
            events = []
            if isEnabled {
                connectionError = "Calendar access was not granted"
            }
            return
        }

        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = eventStore.events(matching: predicate)
            .map(CalendarMeeting.init(event:))
            .sorted { $0.startTime < $1.startTime }
        connectionError = nil
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        events = []
        metricsTracker.finishBecauseMonitoringStopped()
        transition(to: nil)
    }

    func prepareForTermination() {
        metricsTracker.prepareForTermination()
    }

    func prepareForSystemSleep() {
        metricsTracker.prepareForSystemSleep()
    }

    func reconcileAfterWake() {
        guard isEnabled else { return }
        hasCalendarAccess = Self.canReadCalendar(
            isEnabled: isEnabled,
            authorizationStatus: EKEventStore.authorizationStatus(for: .event)
        )
        guard hasCalendarAccess else {
            stopMonitoring()
            return
        }
        startPeriodicCheck(reapplyCalendarSettings: false)
    }

    private func saveCalendarSettings() {
        guard let data = try? JSONEncoder().encode(calendarSettings) else { return }
        defaults.set(data, forKey: Self.slackSettingsDefaultsKey)
    }

    private func startPeriodicCheck(reapplyCalendarSettings: Bool = true) {
        timer?.invalidate()
        if reapplyCalendarSettings {
            presenceCoordinator.calendarSettingsUpdated(calendarSettings)
        }
        checkForActiveMeeting()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForActiveMeeting()
            }
        }
    }

    private func checkForActiveMeeting() {
        fetchTodayEvents()
        let activeMeeting = Self.activeMeeting(at: Date(), in: events)
        transition(to: activeMeeting)
    }

    private func transition(to meeting: CalendarMeeting?) {
        if let meeting {
            metricsTracker.observeActiveMeeting(meeting)
        } else {
            metricsTracker.observeNoActiveMeeting()
        }

        guard Self.isPresenceTransition(currentMeeting: currentMeeting, nextMeeting: meeting) else {
            return
        }
        currentMeeting = meeting
        presenceCoordinator.calendarMeetingUpdated(meeting)
    }

    static func activeMeeting(at date: Date, in events: [CalendarMeeting]) -> CalendarMeeting? {
        events.first { event in
            !event.isAllDay && date >= event.startTime && date < event.endTime
        }
    }

    static func canReadCalendar(
        isEnabled: Bool,
        authorizationStatus: EKAuthorizationStatus
    ) -> Bool {
        isEnabled && authorizationStatus == .fullAccess
    }

    static func isPresenceTransition(
        currentMeeting: CalendarMeeting?,
        nextMeeting: CalendarMeeting?
    ) -> Bool {
        currentMeeting != nextMeeting
    }

}

struct CalendarMeeting: Identifiable, Equatable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let isAllDay: Bool
    let hasVideoCall: Bool

    init(id: String, title: String, startTime: Date, endTime: Date, isAllDay: Bool, hasVideoCall: Bool) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.isAllDay = isAllDay
        self.hasVideoCall = hasVideoCall
    }

    init(event: EKEvent) {
        id = event.eventIdentifier ?? UUID().uuidString
        title = event.title ?? "Untitled Event"
        startTime = event.startDate
        endTime = event.endDate
        isAllDay = event.isAllDay

        hasVideoCall = CalendarEventAnalyzer.shared.isVideoCall(event)
    }
}
