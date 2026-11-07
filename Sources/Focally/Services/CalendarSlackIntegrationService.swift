import EventKit
import Foundation
import Observation

@MainActor
final class CalendarChangeMonitor {
    /// TASK-063: EventKit fires EKEventStoreChanged in bursts; coalesce them
    /// into a single refetch ~2s after the last notification of the burst.
    static let defaultDebounceInterval: TimeInterval = 2.0

    private let notificationCenter: NotificationCenter
    private let notificationName: Notification.Name
    private let onChange: @MainActor () -> Void
    private let debounceInterval: TimeInterval
    private let schedule: (TimeInterval, @escaping @MainActor () -> Void) -> Void
    private let cancel: (UUID) -> Void
    private var observer: NSObjectProtocol?
    private var pendingDebounceID: UUID?

    init(
        notificationCenter: NotificationCenter,
        notificationName: Notification.Name,
        debounceInterval: TimeInterval = CalendarChangeMonitor.defaultDebounceInterval,
        schedule: @escaping (TimeInterval, @escaping @MainActor () -> Void) -> Void = { delay, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { action() }
        },
        cancel: @escaping (UUID) -> Void = { _ in },
        onChange: @escaping @MainActor () -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.notificationName = notificationName
        self.debounceInterval = debounceInterval
        self.schedule = schedule
        self.cancel = cancel
        self.onChange = onChange
    }

    func start() {
        guard observer == nil else { return }
        // Entrega en .main: el bloque corre en el main thread, así que el estado
        // @MainActor se accede sincrónicamente con assumeIsolated (sin Task, que
        // puede morir de hambre bajo Swift Testing).
        observer = notificationCenter.addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if Thread.isMainThread, #available(macOS 14.0, *) {
                MainActor.assumeIsolated {
                    self?.handleChangeNotification()
                }
            } else {
                Task { @MainActor in
                    self?.handleChangeNotification()
                }
            }
        }
    }

    func stop() {
        guard let observer else { return }
        notificationCenter.removeObserver(observer)
        self.observer = nil
        if let pendingDebounceID {
            cancel(pendingDebounceID)
            self.pendingDebounceID = nil
        }
    }

    /// Debounced entry point: N notifications inside the window collapse into
    /// one `onChange` fired after the last one (same pattern as
    /// MediaDeviceCallDetector.handleDeviceEvent).
    private func handleChangeNotification() {
        if let existing = pendingDebounceID { cancel(existing) }
        let id = UUID()
        pendingDebounceID = id
        schedule(debounceInterval) { [weak self] in
            guard let self, self.pendingDebounceID == id else { return }
            self.pendingDebounceID = nil
            self.onChange()
        }
    }
}

@MainActor
@Observable
final class CalendarSlackIntegrationService {
    static let enabledDefaultsKey = "calendarEnabled"
    static let showMeetingTitleDefaultsKey = "calendarShowMeetingTitle"
    static let dndForMeetingsDefaultsKey = "calendarDndForMeetings"
    /// TASK-057: calendar → Slack presence sync is OFF by default; device-based
    /// call detection is the accurate signal.
    static let syncEnabledDefaultsKey = "calendarSlackSyncEnabled"
    static let syncMigratedDefaultsKey = "calendarSlackSyncMigrated"
    /// TASK-063: burst window for EKEventStoreChanged notifications.
    static let eventStoreChangedDebounceInterval: TimeInterval = 2.0
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
    private let notificationCenter: NotificationCenter
    private let eventStoreChangedNotification: Notification.Name
    private let authorizationStatusProvider: () -> EKAuthorizationStatus
    private let eventFetcher: (() -> [CalendarMeeting])?
    private var boundaryTimer: Timer?
    private var isMonitoring = false
    private let eventStoreDebounceInterval: TimeInterval
    private let scheduleDebounce: (TimeInterval, @escaping @MainActor () -> Void) -> Void
    private let cancelDebounce: (UUID) -> Void
    @ObservationIgnored private lazy var changeMonitor = CalendarChangeMonitor(
        notificationCenter: notificationCenter,
        notificationName: eventStoreChangedNotification,
        debounceInterval: eventStoreDebounceInterval,
        schedule: scheduleDebounce,
        cancel: cancelDebounce
    ) { [weak self] in
        self?.reconcileCalendar()
    }

    init(
        eventStore: EKEventStore = EKEventStore(),
        presenceCoordinator: PresenceCoordinating,
        metricsTracker: CalendarMetricsTracker? = nil,
        defaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default,
        eventStoreChangedNotification: Notification.Name = .EKEventStoreChanged,
        debounceInterval: TimeInterval = CalendarSlackIntegrationService.eventStoreChangedDebounceInterval,
        schedule: @escaping (TimeInterval, @escaping @MainActor () -> Void) -> Void = { delay, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { action() }
        },
        cancel: @escaping (UUID) -> Void = { _ in },
        authorizationStatusProvider: @escaping () -> EKAuthorizationStatus = {
            EKEventStore.authorizationStatus(for: .event)
        },
        eventFetcher: (() -> [CalendarMeeting])? = nil
    ) {
        self.eventStore = eventStore
        self.presenceCoordinator = presenceCoordinator
        self.defaults = defaults
        self.notificationCenter = notificationCenter
        self.eventStoreChangedNotification = eventStoreChangedNotification
        self.authorizationStatusProvider = authorizationStatusProvider
        self.eventFetcher = eventFetcher
        self.eventStoreDebounceInterval = debounceInterval
        self.scheduleDebounce = schedule
        self.cancelDebounce = cancel
        self.metricsTracker = metricsTracker ?? CalendarMetricsTracker(
            persistence: UserDefaultsCalendarMetricsDraftPersistence(),
            metrics: FocusMetricsService.shared
        )
        isEnabled = defaults.bool(forKey: Self.enabledDefaultsKey)
        Self.migrateCalendarSlackSyncDefault(defaults: defaults)
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
        hasCalendarAccess = authorizationStatusProvider() == .fullAccess
    }

    // MARK: - TASK-057 calendar sync default off

    /// Whether calendar events may set Slack presence. Default OFF: device-based
    /// call detection is the accurate signal for real call activity.
    var calendarSlackSyncEnabled: Bool {
        get { defaults.bool(forKey: Self.syncEnabledDefaultsKey) }
        set { defaults.set(newValue, forKey: Self.syncEnabledDefaultsKey) }
    }

    /// One-time migration: existing installs keep the behavior they had (the
    /// sync followed the calendar toggle). Fresh installs default to `false`.
    /// Runs only when `calendarSlackSyncMigrated` is absent.
    static func migrateCalendarSlackSyncDefault(defaults: UserDefaults) {
        guard defaults.object(forKey: syncMigratedDefaultsKey) == nil else { return }
        let priorBehavior = defaults.bool(forKey: enabledDefaultsKey)
        defaults.set(priorBehavior, forKey: syncEnabledDefaultsKey)
        defaults.set(true, forKey: syncMigratedDefaultsKey)
    }

    func startIfEnabled() {
        // TASK-057: `calendarSlackSyncEnabled` is the master gate. Monitoring
        // only runs while the sync is on; with it off, calendar events never
        // reach presence (call detection owns presence instead).
        guard calendarSlackSyncEnabled else {
            metricsTracker.finishBecauseMonitoringStopped()
            return
        }
        hasCalendarAccess = Self.canReadCalendar(
            isEnabled: calendarSlackSyncEnabled,
            authorizationStatus: authorizationStatusProvider()
        )
        if hasCalendarAccess {
            startMonitoring()
        } else if isMonitoring {
            stopMonitoring()
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
        // TASK-057: the master sync gate owns calendar prompting, not the
        // legacy per-feature flag.
        guard calendarSlackSyncEnabled else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                hasCalendarAccess = granted
                connectionError = granted ? nil : "Calendar access was not granted"
                if granted {
                    startMonitoring()
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
        let authorizationStatus = authorizationStatusProvider()
        // TASK-057: the master sync gate decides calendar access, not the
        // legacy per-feature flag.
        let syncEnabled = calendarSlackSyncEnabled
        hasCalendarAccess = Self.canReadCalendar(
            isEnabled: syncEnabled,
            authorizationStatus: authorizationStatus
        )
        guard hasCalendarAccess else {
            events = []
            if syncEnabled {
                connectionError = "Calendar access was not granted"
            }
            return
        }

        if let eventFetcher {
            events = eventFetcher().sorted { $0.startTime < $1.startTime }
        } else {
            let start = Calendar.current.startOfDay(for: Date())
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
            let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
            events = eventStore.events(matching: predicate)
                .map(CalendarMeeting.init(event:))
                .sorted { $0.startTime < $1.startTime }
        }
        connectionError = nil
    }

    func stopMonitoring() {
        boundaryTimer?.invalidate()
        boundaryTimer = nil
        changeMonitor.stop()
        isMonitoring = false
        events = []
        metricsTracker.finishBecauseMonitoringStopped()
        transition(to: nil)
    }

    func prepareForTermination() {
        boundaryTimer?.invalidate()
        boundaryTimer = nil
        changeMonitor.stop()
        isMonitoring = false
        metricsTracker.prepareForTermination()
    }

    func prepareForSystemSleep() {
        boundaryTimer?.invalidate()
        boundaryTimer = nil
        metricsTracker.prepareForSystemSleep()
    }

    func reconcileAfterWake() {
        guard calendarSlackSyncEnabled else { return }
        hasCalendarAccess = Self.canReadCalendar(
            isEnabled: calendarSlackSyncEnabled,
            authorizationStatus: authorizationStatusProvider()
        )
        guard hasCalendarAccess else {
            stopMonitoring()
            return
        }
        isMonitoring = true
        changeMonitor.start()
        reconcileCalendar()
    }

    private func saveCalendarSettings() {
        guard let data = try? JSONEncoder().encode(calendarSettings) else { return }
        defaults.set(data, forKey: Self.slackSettingsDefaultsKey)
    }

    private func startMonitoring(reapplyCalendarSettings: Bool = true) {
        guard !isMonitoring else { return }
        isMonitoring = true
        changeMonitor.start()
        if reapplyCalendarSettings {
            presenceCoordinator.calendarSettingsUpdated(calendarSettings)
        }
        reconcileCalendar()
    }

    private func reconcileCalendar() {
        fetchTodayEvents()
        guard hasCalendarAccess else {
            stopMonitoring()
            return
        }
        let now = Date()
        transition(to: Self.activeMeeting(at: now, in: events))
        scheduleNextBoundary(after: now)
    }

    private func scheduleNextBoundary(after date: Date) {
        boundaryTimer?.invalidate()
        let calendar = Calendar.current
        let nextDayStart = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: date)
        ) ?? date.addingTimeInterval(86_400)
        guard let boundary = Self.nextBoundary(
            after: date,
            events: events,
            nextDayStart: nextDayStart
        ) else {
            boundaryTimer = nil
            return
        }
        boundaryTimer = Timer.scheduledTimer(
            withTimeInterval: max(0.1, boundary.timeIntervalSince(date)),
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reconcileCalendar()
            }
        }
    }

    private func transition(to meeting: CalendarMeeting?) {
        if let meeting {
            metricsTracker.reconcileActiveMeeting(meeting)
        } else {
            metricsTracker.reconcileNoActiveMeeting()
        }

        guard Self.isPresenceTransition(currentMeeting: currentMeeting, nextMeeting: meeting) else {
            return
        }
        currentMeeting = meeting
        // calendarSlackSyncEnabled gate: with the sync off, calendar events
        // never set Slack presence (call detection owns presence instead).
        guard defaults.bool(forKey: Self.syncEnabledDefaultsKey) else { return }
        presenceCoordinator.calendarMeetingUpdated(meeting)
    }

    static func activeMeeting(at date: Date, in events: [CalendarMeeting]) -> CalendarMeeting? {
        events.first { event in
            !event.isAllDay && date >= event.startTime && date < event.endTime
        }
    }

    static func nextBoundary(
        after date: Date,
        events: [CalendarMeeting],
        nextDayStart: Date
    ) -> Date? {
        let eventBoundaries = events
            .filter { !$0.isAllDay }
            .flatMap { [$0.startTime, $0.endTime] }
            .filter { $0 > date }
        return (eventBoundaries + [nextDayStart].filter { $0 > date }).min()
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
