import Foundation
import Testing
@testable import Focally

@MainActor
@Suite("Presence coordinator")
struct PresenceCoordinatorTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func testReapplyActivePresenceDoesNothingWhileIdle() {
        let (coordinator, slack, dnd) = makeCoordinator()

        coordinator.reapplyActivePresence()

        #expect(slack.allWrites.isEmpty)
        #expect(dnd.writes.isEmpty)
    }

    @Test func testReapplyActivePresenceRestoresManualSlackStatusAfterReconnect() {
        let (coordinator, slack, _) = makeCoordinator()
        coordinator.manualFocusStarted(mode: makeMode(status: "Deep work", emoji: ":brain:"))
        let statusCountBeforeReconnect = slack.statuses.count

        coordinator.reapplyActivePresence()

        #expect(slack.statuses.count == statusCountBeforeReconnect + 1)
        #expect(slack.statuses.last?.text == "Deep work")
        #expect(slack.statuses.last?.emoji == ":brain:")
    }

    @Test func testCalendarMeetingPromotesFromIdle() {
        let (coordinator, slack, _) = makeCoordinator()
        coordinator.calendarSettingsUpdated(calendarSettings(show: true))
        let meeting = makeMeeting()

        coordinator.calendarMeetingUpdated(meeting)

        #expect(coordinator.currentPresence == .calendarMeeting(meeting))
        #expect(slack.statuses.last?.text == meeting.title)
        #expect(slack.statuses.last?.emoji == nil)
    }

    @Test func testManualFocusPromotesOverCalendar() {
        let (coordinator, slack, _) = makeCoordinator()
        coordinator.calendarSettingsUpdated(calendarSettings(show: true))
        coordinator.calendarMeetingUpdated(makeMeeting())
        let mode = makeMode(status: "Deep work", emoji: ":brain:")

        coordinator.manualFocusStarted(mode: mode)

        #expect(coordinator.currentPresence == .manualFocus(mode.sanitized()))
        #expect(slack.statuses.last?.text == "Deep work")
        #expect(slack.statuses.last?.emoji == ":brain:")
    }

    @Test func testCalendarUpdateDuringManualFocusDoesNotOverwritePresence() {
        let (coordinator, slack, dnd) = makeCoordinator()
        let mode = makeMode(status: "Focus")
        coordinator.manualFocusStarted(mode: mode)
        let writesBeforeUpdate = slack.allWrites.count
        let systemWritesBeforeUpdate = dnd.writes.count
        let meeting = makeMeeting(id: "updated", title: "📞 Planning")

        coordinator.calendarMeetingUpdated(meeting)

        #expect(coordinator.currentCalendarMeeting == meeting)
        #expect(coordinator.currentPresence == .manualFocus(mode.sanitized()))
        #expect(slack.allWrites.count == writesBeforeUpdate)
        #expect(dnd.writes.count == systemWritesBeforeUpdate)
    }

    @Test func testManualFocusEndRestoresRememberedCalendarPresenceImmediately() {
        let (coordinator, slack, _) = makeCoordinator()
        coordinator.calendarSettingsUpdated(calendarSettings(show: true))
        let meeting = makeMeeting(title: "Roadmap")
        coordinator.manualFocusStarted(mode: makeMode(status: "Focus"))
        coordinator.calendarMeetingUpdated(meeting)

        coordinator.manualFocusEnded()

        #expect(coordinator.currentPresence == .calendarMeeting(meeting))
        #expect(slack.statuses.last?.text == "Roadmap")
    }

    @Test func testManualFocusEndFallsBackToIdleWhenNoMeetingRemains() {
        let (coordinator, slack, _) = makeCoordinator()
        coordinator.manualFocusStarted(mode: makeMode())

        coordinator.manualFocusEnded()

        #expect(coordinator.currentPresence == .idle)
        #expect(slack.allWrites.last == .clearStatus)
    }

    @Test func testCalendarEndWhileManualFocusActiveOnlyClearsRememberedMeeting() {
        let (coordinator, slack, dnd) = makeCoordinator()
        let mode = makeMode(status: "Manual")
        coordinator.calendarMeetingUpdated(makeMeeting())
        coordinator.manualFocusStarted(mode: mode)
        let slackWrites = slack.allWrites.count
        let dndWrites = dnd.writes.count

        coordinator.calendarMeetingUpdated(nil)

        #expect(coordinator.currentCalendarMeeting == nil)
        #expect(coordinator.currentPresence == .manualFocus(mode.sanitized()))
        #expect(slack.allWrites.count == slackWrites)
        #expect(dnd.writes.count == dndWrites)
    }

    @Test func testCalendarDNDIsRestoredAfterManualFocusWithoutDNDEnds() {
        let (coordinator, slack, dnd) = makeCoordinator()
        coordinator.calendarSettingsUpdated(calendarSettings(show: true, dnd: true))
        coordinator.calendarMeetingUpdated(makeMeeting(video: true))
        coordinator.manualFocusStarted(mode: makeMode(systemDND: false, slackDND: false))

        coordinator.manualFocusEnded()

        #expect(dnd.writes == [.activate, .deactivate, .activate])
        #expect(slack.dndWrites == [.enable(60), .disable, .enable(60)])
    }

    @Test func testCoordinatorOnlyDisablesSystemDNDItActivated() {
        let externalDND = RecordingDNDService(isDNDActive: true)
        let coordinator = DefaultPresenceCoordinator(
            slackService: RecordingSlackService(),
            dndService: externalDND,
            now: { now }
        )
        coordinator.manualFocusStarted(mode: makeMode(systemDND: true))

        coordinator.manualFocusEnded()

        #expect(externalDND.writes.isEmpty)
    }

    @Test func testCoordinatorOnlyDisablesSlackDNDItActivated() {
        let (coordinator, slack, _) = makeCoordinator()
        coordinator.manualFocusStarted(mode: makeMode(slackDND: false))

        coordinator.manualFocusEnded()

        #expect(slack.dndWrites.isEmpty)
    }

    @Test func testDisabledSlackDNDActivationDoesNotRecordOwnership() {
        let slack = RecordingSlackService()
        slack.isEnabled = false
        let coordinator = DefaultPresenceCoordinator(
            slackService: slack,
            dndService: RecordingDNDService(),
            now: { now }
        )

        coordinator.manualFocusStarted(mode: makeMode(slackDND: true))
        coordinator.manualFocusEnded()

        #expect(slack.dndWrites == [.rejected(25)])
    }

    @Test func testSlackDNDPreparationFailureDoesNotRecordOwnership() {
        let slack = RecordingSlackService(acceptsDNDRequests: false)
        let coordinator = DefaultPresenceCoordinator(
            slackService: slack,
            dndService: RecordingDNDService(),
            now: { now }
        )

        coordinator.manualFocusStarted(mode: makeMode(slackDND: true))
        coordinator.manualFocusEnded()

        #expect(slack.dndWrites == [.rejected(25)])
    }

    @Test func testCalendarHiddenFromSlackClearsStatusButCanStillOwnDND() {
        let (coordinator, slack, dnd) = makeCoordinator()
        coordinator.calendarSettingsUpdated(calendarSettings(show: false, dnd: true))

        coordinator.calendarMeetingUpdated(makeMeeting(video: true))

        #expect(slack.allWrites.last == .enableDND(60))
        #expect(slack.allWrites.contains(.clearStatus))
        #expect(dnd.writes == [.activate])
    }

    @Test func testCalendarNonVideoMeetingDoesNotEnableDND() {
        let (coordinator, slack, dnd) = makeCoordinator()
        coordinator.calendarSettingsUpdated(calendarSettings(show: true, dnd: true))

        coordinator.calendarMeetingUpdated(makeMeeting(video: false))

        #expect(dnd.writes.isEmpty)
        #expect(slack.dndWrites.isEmpty)
    }

    @Test func testManualFocusModeReplacementReappliesPresence() {
        let (coordinator, slack, dnd) = makeCoordinator()
        coordinator.manualFocusStarted(mode: makeMode(status: "First", systemDND: true, slackDND: true))

        coordinator.manualFocusStarted(mode: makeMode(status: "Second", emoji: ":zap:", systemDND: false, slackDND: false))

        #expect(slack.statuses.last?.text == "Second")
        #expect(slack.statuses.last?.emoji == ":zap:")
        #expect(dnd.writes == [.activate, .deactivate])
        #expect(slack.dndWrites == [.enable(25), .disable])
    }

    @Test func testManualFocusModeReplacementReappliesSlackDNDForNewDuration() {
        let (coordinator, slack, _) = makeCoordinator()
        coordinator.manualFocusStarted(mode: makeMode(status: "First", duration: 25, slackDND: true))

        coordinator.manualFocusStarted(mode: makeMode(status: "Second", duration: 45, slackDND: true))

        #expect(slack.dndWrites == [.enable(25), .enable(45)])
    }

    @Test func testCalendarToManualTransitionReappliesSlackDNDForNewSource() {
        let (coordinator, slack, _) = makeCoordinator()
        coordinator.calendarSettingsUpdated(calendarSettings(show: true, dnd: true))
        coordinator.calendarMeetingUpdated(makeMeeting(video: true))

        coordinator.manualFocusStarted(mode: makeMode(duration: 60, slackDND: true))

        #expect(slack.dndWrites == [.enable(60), .enable(60)])
    }

    @Test func testMeetingReplacementReappliesSlackDNDForNewSource() {
        let (coordinator, slack, _) = makeCoordinator()
        coordinator.calendarSettingsUpdated(calendarSettings(show: true, dnd: true))
        coordinator.calendarMeetingUpdated(makeMeeting(id: "first", video: true))

        coordinator.calendarMeetingUpdated(makeMeeting(id: "second", video: true))

        #expect(slack.dndWrites == [.enable(60), .enable(60)])
    }

    @Test func testDelayedDNDActivationIsReleasedAfterQuickDemotion() {
        let slack = RecordingSlackService()
        let dnd = DelayedActivationDNDService()
        var reconciliation: (@MainActor () -> Void)?
        let coordinator = DefaultPresenceCoordinator(
            slackService: slack,
            dndService: dnd,
            now: { now },
            scheduleDNDReconciliation: { reconciliation = $0 }
        )

        coordinator.manualFocusStarted(mode: makeMode(systemDND: true))
        coordinator.manualFocusEnded()
        dnd.completeActivation()
        reconciliation?()

        #expect(dnd.writes == [.activate, .deactivate, .deactivate])
        #expect(dnd.isDNDActive == false)
    }

    @Test func testDisabledDirectIntegrationPreservesManualPresenceWithoutSystemDND() {
        let coordinator = RecordingPresenceCoordinator()
        let suiteName = "PresenceCoordinatorTests.disabled-direct-integration"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let service = FocusIntegrationService(
            presenceCoordinator: coordinator,
            defaults: defaults,
            shortcutBackup: { _ in }
        )
        service.isEnabled = false
        let mode = makeMode(status: "Deep work", systemDND: true, slackDND: true)

        service.activateFocus(for: mode)

        #expect(coordinator.startedMode == mode.sanitized())
        #expect(coordinator.systemDNDEnabled == false)
        #expect(coordinator.isManualFocusActive)
        #expect(service.isFocusActive == false)
    }

    @Test func testNilModeDirectEndDoesNotDemoteActiveManualFocus() {
        let coordinator = RecordingPresenceCoordinator()
        let suiteName = "PresenceCoordinatorTests.nil-mode-direct-end"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let service = FocusIntegrationService(
            presenceCoordinator: coordinator,
            defaults: defaults,
            shortcutBackup: { _ in }
        )
        let mode = makeMode(status: "Deep work")
        coordinator.manualFocusStarted(mode: mode, systemDNDEnabled: true)

        service.performDirectFocusAction(.end, mode: nil)

        #expect(coordinator.currentPresence == .manualFocus(mode.sanitized()))
        #expect(coordinator.isManualFocusActive)
        #expect(coordinator.manualFocusEndCount == 0)
        #expect(service.isFocusActive)
    }

    @Test func testDisabledCalendarServiceInitializationDoesNotApplyPresence() {
        let suiteName = "PresenceCoordinatorTests.disabled-calendar-init"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(false, forKey: CalendarSlackIntegrationService.enabledDefaultsKey)
        let coordinator = RecordingPresenceCoordinator()

        _ = CalendarSlackIntegrationService(
            presenceCoordinator: coordinator,
            defaults: defaults
        )

        #expect(coordinator.calendarSettingsUpdateCount == 0)
        #expect(coordinator.calendarMeetingUpdateCount == 0)
    }

    @Test func testSystemDNDPolicyDoesNotSuppressManualSlackPresence() {
        let (coordinator, slack, dnd) = makeCoordinator()
        let mode = makeMode(status: "Deep work", systemDND: true, slackDND: true)

        coordinator.manualFocusStarted(
            mode: mode,
            systemDNDEnabled: false
        )

        #expect(coordinator.currentPresence == .manualFocus(mode.sanitized()))
        #expect(slack.statuses.last?.text == "Deep work")
        #expect(slack.dndWrites == [.enable(25)])
        #expect(dnd.writes.isEmpty)
    }

    private func makeCoordinator() -> (DefaultPresenceCoordinator, RecordingSlackService, RecordingDNDService) {
        let slack = RecordingSlackService()
        let dnd = RecordingDNDService()
        return (
            DefaultPresenceCoordinator(slackService: slack, dndService: dnd, now: { now }),
            slack,
            dnd
        )
    }

    private func makeMeeting(
        id: String = "meeting",
        title: String = "Planning",
        video: Bool = true
    ) -> CalendarMeeting {
        CalendarMeeting(
            id: id,
            title: title,
            startTime: now.addingTimeInterval(-300),
            endTime: now.addingTimeInterval(3_600),
            isAllDay: false,
            hasVideoCall: video
        )
    }

    private func makeMode(
        status: String = "Focus",
        emoji: String = ":brain:",
        duration: Int = 25,
        systemDND: Bool = false,
        slackDND: Bool = false
    ) -> FocusMode {
        FocusMode(
            name: status,
            emoji: emoji,
            statusText: status,
            durationMinutes: duration,
            enableMacOSDND: systemDND,
            enableSlackDND: slackDND
        )
    }

    private func calendarSettings(show: Bool, dnd: Bool = false) -> SlackCalendarSettings {
        SlackCalendarSettings(
            showCalendarInSlack: show,
            titleDisplay: .showFullTitle,
            useEventEmojisForStatus: false,
            activateDNDForVideoCalls: dnd
        )
    }
}

@MainActor
private final class RecordingSlackService: PresenceSlackServicing {
    struct Status: Equatable {
        let text: String
        let expiration: Int
        let emoji: String?
        let fallbackEmoji: String?
    }

    enum Write: Equatable {
        case status(Status)
        case clearStatus
        case enableDND(Int)
        case disableDND
    }

    enum DNDWrite: Equatable {
        case enable(Int)
        case rejected(Int)
        case disable
    }

    var isEnabled = true
    private let acceptsDNDRequests: Bool
    private(set) var allWrites: [Write] = []
    private(set) var statuses: [Status] = []
    private(set) var dndWrites: [DNDWrite] = []

    init(acceptsDNDRequests: Bool = true) {
        self.acceptsDNDRequests = acceptsDNDRequests
    }

    func savedStatusEmoji() -> String { ":saved:" }

    func setStatus(text: String, expirationTimestamp: Int, taskEmoji: String?, fallbackEmoji: String?) {
        let status = Status(text: text, expiration: expirationTimestamp, emoji: taskEmoji, fallbackEmoji: fallbackEmoji)
        statuses.append(status)
        allWrites.append(.status(status))
    }

    func clearStatus() {
        allWrites.append(.clearStatus)
    }

    func requestSlackDNDSnooze(minutes: Int) -> Bool {
        guard isEnabled, acceptsDNDRequests else {
            dndWrites.append(.rejected(minutes))
            return false
        }
        dndWrites.append(.enable(minutes))
        allWrites.append(.enableDND(minutes))
        return true
    }

    func disableSlackDND() {
        dndWrites.append(.disable)
        allWrites.append(.disableDND)
    }
}

@MainActor
private final class RecordingDNDService: PresenceDNDServicing {
    enum Write: Equatable {
        case activate
        case deactivate
    }

    private(set) var isDNDActive: Bool
    private(set) var writes: [Write] = []

    init(isDNDActive: Bool = false) {
        self.isDNDActive = isDNDActive
    }

    func activateDND() {
        writes.append(.activate)
        isDNDActive = true
    }

    func deactivateDND() {
        writes.append(.deactivate)
        isDNDActive = false
    }
}

@MainActor
private final class DelayedActivationDNDService: PresenceDNDServicing {
    typealias Write = RecordingDNDService.Write
    private(set) var isDNDActive = false
    private(set) var writes: [Write] = []

    func activateDND() { writes.append(.activate) }
    func completeActivation() { isDNDActive = true }
    func deactivateDND() {
        writes.append(.deactivate)
        guard isDNDActive else { return }
        isDNDActive = false
    }
}

@MainActor
private final class RecordingPresenceCoordinator: PresenceCoordinating {
    var currentPresence: PresenceState = .idle
    var isManualFocusActive = false
    var currentCalendarMeeting: CalendarMeeting?
    var isSystemDNDActive = false
    private(set) var startedMode: FocusMode?
    private(set) var systemDNDEnabled: Bool?
    private(set) var manualFocusEndCount = 0
    private(set) var calendarMeetingUpdateCount = 0
    private(set) var calendarSettingsUpdateCount = 0

    func manualFocusStarted(mode: FocusMode, systemDNDEnabled: Bool) {
        startedMode = mode
        self.systemDNDEnabled = systemDNDEnabled
        isManualFocusActive = true
        currentPresence = .manualFocus(mode)
    }

    func manualFocusEnded() {
        manualFocusEndCount += 1
        isManualFocusActive = false
        currentPresence = .idle
    }

    func calendarMeetingUpdated(_ meeting: CalendarMeeting?) {
        calendarMeetingUpdateCount += 1
        currentCalendarMeeting = meeting
    }

    func calendarSettingsUpdated(_ settings: SlackCalendarSettings) {
        calendarSettingsUpdateCount += 1
    }
}
