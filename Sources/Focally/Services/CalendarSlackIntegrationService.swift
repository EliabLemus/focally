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
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledDefaultsKey)
        }
    }
    private(set) var hasCalendarAccess: Bool
    private var events: [CalendarMeeting] = []
    private(set) var currentMeeting: CalendarMeeting?
    var connectionError: String?
    var calendarSettings: SlackCalendarSettings {
        didSet {
            saveCalendarSettings()
            publishCurrentMeetingToSlack()
            updateDNDForCurrentMeeting()
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
    private let slackService: SlackService
    private let dndService: DNDService
    private let metricsTracker: CalendarMetricsTracker
    private var timer: Timer?
    private var didActivateDNDForMeeting = false
    private var didActivateSlackDNDForMeeting = false
    private var focusChannelObserver: NSObjectProtocol?

    init(
        eventStore: EKEventStore = EKEventStore(),
        slackService: SlackService,
        dndService: DNDService,
        metricsTracker: CalendarMetricsTracker? = nil
    ) {
        self.eventStore = eventStore
        self.slackService = slackService
        self.dndService = dndService
        self.metricsTracker = metricsTracker ?? CalendarMetricsTracker(
            persistence: UserDefaultsCalendarMetricsDraftPersistence(),
            metrics: FocusMetricsService.shared
        )
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
        if let data = UserDefaults.standard.data(forKey: Self.slackSettingsDefaultsKey),
           let settings = try? JSONDecoder().decode(SlackCalendarSettings.self, from: data) {
            calendarSettings = settings
        } else {
            calendarSettings = SlackCalendarSettings(
                showCalendarInSlack: UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey),
                titleDisplay: UserDefaults.standard.bool(forKey: Self.showMeetingTitleDefaultsKey)
                    ? .showFullTitle
                    : .showVideoCallOnly,
                useEventEmojisForStatus: false,
                activateDNDForVideoCalls: UserDefaults.standard.bool(forKey: Self.dndForMeetingsDefaultsKey)
            )
        }
        hasCalendarAccess = EKEventStore.authorizationStatus(for: .event) == .fullAccess

        focusChannelObserver = NotificationCenter.default.addObserver(
            forName: .focallyFocusChannelDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.publishCurrentMeetingToSlack()
                self?.updateDNDForCurrentMeeting()
            }
        }
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
        guard isEnabled, hasCalendarAccess else {
            events = []
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

    private func saveCalendarSettings() {
        guard let data = try? JSONEncoder().encode(calendarSettings) else { return }
        UserDefaults.standard.set(data, forKey: Self.slackSettingsDefaultsKey)
    }

    private func startPeriodicCheck() {
        timer?.invalidate()
        checkForActiveMeeting()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForActiveMeeting()
            }
        }
    }

    private func checkForActiveMeeting() {
        fetchTodayEvents()
        let now = Date()
        let activeMeeting = events.first { event in
            !event.isAllDay && now >= event.startTime && now < event.endTime
        }
        transition(to: activeMeeting)
    }

    private func transition(to meeting: CalendarMeeting?) {
        if let meeting {
            metricsTracker.observeActiveMeeting(meeting)
        } else {
            metricsTracker.observeNoActiveMeeting()
        }

        guard Self.isPresenceTransition(
            currentMeetingID: currentMeeting?.id,
            nextMeetingID: meeting?.id
        ) else {
            updateDNDForCurrentMeeting()
            return
        }

        if meeting == nil, currentMeeting != nil {
            if !FocusIntegrationService.shared.isFocusModeActive {
                slackService.clearStatus()
            }
        }

        currentMeeting = meeting
        publishCurrentMeetingToSlack()
        updateDNDForCurrentMeeting()
    }

    static func isPresenceTransition(currentMeetingID: String?, nextMeetingID: String?) -> Bool {
        nextMeetingID != currentMeetingID
    }

    private func publishCurrentMeetingToSlack() {
        guard !FocusIntegrationService.shared.isFocusModeActive else { return }
        guard calendarSettings.showCalendarInSlack, let meeting = currentMeeting else {
            slackService.clearStatus()
            return
        }

        let text: String
        switch calendarSettings.titleDisplay {
        case .showFullTitle:
            text = meeting.title
        case .showVideoCallOnly:
            text = AppLanguage.shared.localizedString(
                meeting.hasVideoCall ? "calendar_in_video_call" : "calendar_in_meeting"
            )
        case .hideTitle:
            text = ""
        }

        let extractedEmojis = EmojiExtractor.shared.extractAllEmojis(from: meeting.title)
        let eventEmoji = calendarSettings.useEventEmojisForStatus && !extractedEmojis.isEmpty
            ? EmojiExtractor.shared.concatenate(emojis: extractedEmojis)
            : nil

        slackService.setStatus(
            text: text,
            expirationTimestamp: Int(meeting.endTime.timeIntervalSince1970),
            taskEmoji: eventEmoji,
            fallbackEmoji: nil
        )
    }

    private func updateDNDForCurrentMeeting() {
        let shouldActivate = calendarSettings.activateDNDForVideoCalls
            && currentMeeting?.hasVideoCall == true
            && !FocusIntegrationService.shared.isFocusModeActive
        if shouldActivate, !dndService.isDNDActive {
            dndService.activateDND()
            didActivateDNDForMeeting = true
        } else if !shouldActivate, didActivateDNDForMeeting {
            dndService.deactivateDND()
            didActivateDNDForMeeting = false
        }

        if shouldActivate, !didActivateSlackDNDForMeeting, let meeting = currentMeeting {
            let remainingMinutes = max(1, Int(ceil(meeting.endTime.timeIntervalSinceNow / 60)))
            slackService.setSlackDNDSnooze(minutes: remainingMinutes)
            didActivateSlackDNDForMeeting = true
        } else if !shouldActivate, didActivateSlackDNDForMeeting {
            slackService.disableSlackDND()
            didActivateSlackDNDForMeeting = false
        }
    }
}

extension Notification.Name {
    static let focallyFocusChannelDidChange = Notification.Name("focally.focusChannelDidChange")
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
