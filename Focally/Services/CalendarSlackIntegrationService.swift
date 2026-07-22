import EventKit
import Foundation
import Observation

@MainActor
@Observable
final class CalendarSlackIntegrationService {
    static let enabledDefaultsKey = "calendarEnabled"
    static let showMeetingTitleDefaultsKey = "calendarShowMeetingTitle"
    static let dndForMeetingsDefaultsKey = "calendarDndForMeetings"

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledDefaultsKey)
        }
    }
    private(set) var hasCalendarAccess: Bool
    private var events: [CalendarMeeting] = []
    private var currentMeeting: CalendarMeeting?
    var connectionError: String?
    var showMeetingTitle: Bool {
        didSet {
            UserDefaults.standard.set(showMeetingTitle, forKey: Self.showMeetingTitleDefaultsKey)
        }
    }
    var dndForMeetings: Bool {
        didSet {
            UserDefaults.standard.set(dndForMeetings, forKey: Self.dndForMeetingsDefaultsKey)
            updateDNDForCurrentMeeting()
        }
    }

    private let eventStore: EKEventStore
    private let slackService: SlackService
    private let dndService: DNDService
    private var timer: Timer?
    private var didActivateDNDForMeeting = false

    init(
        eventStore: EKEventStore = EKEventStore(),
        slackService: SlackService,
        dndService: DNDService
    ) {
        self.eventStore = eventStore
        self.slackService = slackService
        self.dndService = dndService
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
        showMeetingTitle = UserDefaults.standard.bool(forKey: Self.showMeetingTitleDefaultsKey)
        dndForMeetings = UserDefaults.standard.bool(forKey: Self.dndForMeetingsDefaultsKey)
        hasCalendarAccess = EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func startIfEnabled() {
        guard isEnabled else { return }
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
        transition(to: nil)
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
        guard meeting?.id != currentMeeting?.id else {
            updateDNDForCurrentMeeting()
            return
        }

        if meeting == nil, currentMeeting != nil {
            slackService.clearStatus()
        }

        currentMeeting = meeting
        if let meeting {
            slackService.setStatus(
                text: showMeetingTitle ? meeting.title : "In a meeting",
                expirationTimestamp: Int(meeting.endTime.timeIntervalSince1970),
                fallbackEmoji: ":calendar:"
            )
        }
        updateDNDForCurrentMeeting()
    }

    private func updateDNDForCurrentMeeting() {
        let shouldActivate = dndForMeetings && currentMeeting?.hasVideoCall == true
        if shouldActivate, !dndService.isDNDActive {
            dndService.activateDND()
            didActivateDNDForMeeting = true
        } else if !shouldActivate, didActivateDNDForMeeting {
            dndService.deactivateDND()
            didActivateDNDForMeeting = false
        }
    }
}

private struct CalendarMeeting: Identifiable, Equatable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let isAllDay: Bool
    let hasVideoCall: Bool

    init(event: EKEvent) {
        id = event.eventIdentifier ?? UUID().uuidString
        title = event.title ?? "Untitled Event"
        startTime = event.startDate
        endTime = event.endDate
        isAllDay = event.isAllDay

        let searchableText = [event.location, event.url?.absoluteString, event.notes]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        hasVideoCall = ["meet.google.com", "zoom.us", "teams.microsoft.com", "webex.com"]
            .contains { searchableText.contains($0) }
    }
}
