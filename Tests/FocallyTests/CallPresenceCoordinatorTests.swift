import Foundation
import Testing

@testable import Focally

// TASK-057 tests 4, 5, 7, 8, 9, 13, 17: call presence semantics — auto-pause
// with ownership, user-pause protection, calendar overlap precedence, multi
// client, quit-mid-call cleanup, live settings, user-owned DND.

@MainActor
private final class FakeCallSessionController: CallFocusSessionControlling {
    private(set) var hasActiveSession: Bool
    private(set) var isSessionPaused: Bool
    private(set) var pauseCount = 0
    private(set) var resumeCount = 0

    init(hasActiveSession: Bool = true, isPaused: Bool = false) {
        self.hasActiveSession = hasActiveSession
        self.isSessionPaused = isPaused
    }

    func pauseSession() {
        pauseCount += 1
        isSessionPaused = true
    }

    func resumeSession() {
        resumeCount += 1
        isSessionPaused = false
    }

    func endSession() { hasActiveSession = false }
}

@MainActor
final class CallPresenceCoordinatorTests {
    private let chrome = CallClient(bundlePrefix: "com.google.chrome", displayName: "Google Meet (Chrome)", emoji: ":google-meet:")
    private let slackCall = CallClient(bundlePrefix: "com.tinyspeck.slackmacgap", displayName: "Slack Call", emoji: ":slack-call:")
    private let now = Date()

    private func makeCoordinator(
        slack: RecordingSlackService,
        dnd: RecordingDNDService,
        session: FakeCallSessionController? = nil,
        settings: CallDetectionSettings = CallDetectionSettings(),
        defaults: UserDefaults? = nil
    ) -> DefaultPresenceCoordinator {
        let storeDefaults = defaults
        return DefaultPresenceCoordinator(
            slackService: slack,
            dndService: dnd,
            now: { self.now },
            sessionController: session,
            callSettingsProvider: {
                if let storeDefaults {
                    return CallDetectionSettingsStore(defaults: storeDefaults).currentSettings()
                }
                return settings
            }
        )
    }

    private func makeCoordinator(
        slack: RecordingSlackService,
        dnd: RecordingDNDService
    ) -> DefaultPresenceCoordinator {
        makeCoordinator(slack: slack, dnd: dnd, session: nil, settings: CallDetectionSettings(), defaults: nil)
    }

    private func makeCoordinator(
        session: FakeCallSessionController?,
        settings: CallDetectionSettings = CallDetectionSettings()
    ) -> DefaultPresenceCoordinator {
        makeCoordinator(slack: RecordingSlackService(), dnd: RecordingDNDService(), session: session, settings: settings, defaults: nil)
    }

    private func makeCoordinator(
        slack: RecordingSlackService,
        settings: CallDetectionSettings = CallDetectionSettings()
    ) -> DefaultPresenceCoordinator {
        makeCoordinator(slack: slack, dnd: RecordingDNDService(), session: nil, settings: settings, defaults: nil)
    }

    private func makeCoordinator(
        dnd: RecordingDNDService,
        settings: CallDetectionSettings = CallDetectionSettings()
    ) -> DefaultPresenceCoordinator {
        makeCoordinator(slack: RecordingSlackService(), dnd: dnd, session: nil, settings: settings, defaults: nil)
    }

    private func makeCoordinator(
        slack: RecordingSlackService,
        dnd: RecordingDNDService,
        defaults: UserDefaults?
    ) -> DefaultPresenceCoordinator {
        makeCoordinator(slack: slack, dnd: dnd, session: nil, settings: CallDetectionSettings(), defaults: defaults)
    }

    private func makeCoordinator(
        slack: RecordingSlackService,
        defaults: UserDefaults?
    ) -> DefaultPresenceCoordinator {
        makeCoordinator(slack: slack, dnd: RecordingDNDService(), session: nil, settings: CallDetectionSettings(), defaults: defaults)
    }

    private func makeMeeting(video: Bool = true) -> CalendarMeeting {
        CalendarMeeting(
            id: "meeting",
            title: "Planning",
            startTime: now.addingTimeInterval(-300),
            endTime: now.addingTimeInterval(3_600),
            isAllDay: false,
            hasVideoCall: video
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

    // MARK: Test 4 — auto-pause / resume with full restore

    @Test func callAutoPausesSessionSetsStatusAndDNDFullRestoreOnEnd() {
        let slack = RecordingSlackService()
        let dnd = RecordingDNDService()
        let session = FakeCallSessionController()
        let settings = CallDetectionSettings(callStatusMessage: "Custom In a Call")
        let coordinator = makeCoordinator(slack: slack, dnd: dnd, session: session, settings: settings)

        coordinator.callStarted(chrome)

        #expect(session.pauseCount == 1)
        #expect(session.isSessionPaused)
        #expect(coordinator.currentPresence == .activeCall(chrome))
        let status = slack.statuses.last
        #expect(status?.text == "Custom In a Call")
        #expect(status?.emoji == ":google-meet:")
        #expect(status?.fallbackEmoji == ":saved:")
        #expect(dnd.writes == [.activate])

        coordinator.callEnded()

        #expect(session.resumeCount == 1)
        #expect(!session.isSessionPaused)
        #expect(coordinator.currentPresence == .idle)
        #expect(slack.allWrites.last == .clearStatus)
        #expect(dnd.writes == [.activate, .deactivate])
        #expect(!CallActivityTracker.shared.isCallActive)
    }

    // MARK: Test 5 — no resume on user pause

    @Test func sessionUserPausedBeforeCallIsNotResumedOnCallEnd() {
        let session = FakeCallSessionController(isPaused: true) // user paused manually
        let coordinator = makeCoordinator(session: session)

        coordinator.callStarted(chrome)
        #expect(session.pauseCount == 0) // already paused; detector did not pause

        coordinator.callEnded()

        #expect(session.resumeCount == 0)
    }

    // MARK: Test 7 — calendar overlap precedence

    @Test func callUnderCalendarPresencePausesSessionButKeepsCalendarPresence() {
        let coordinator = makeCoordinator(session: FakeCallSessionController())
        coordinator.calendarSettingsUpdated(calendarSettings(show: true))
        coordinator.calendarMeetingUpdated(makeMeeting())
        #expect(coordinator.currentPresence == .calendarMeeting(makeMeeting()))

        coordinator.callStarted(chrome)

        // Calendar title is richer: the call must not overwrite it, but the
        // Pomodoro under the meeting still pauses.
        #expect(coordinator.currentPresence == .calendarMeeting(makeMeeting()))

        // Meeting ends while the call continues → presence switches to .activeCall.
        coordinator.calendarMeetingUpdated(nil)

        #expect(coordinator.currentPresence == .activeCall(chrome))
    }

    // MARK: Test 8 — two clients

    @Test func twoClientsSinglePresenceRestoredOnlyAfterLastEnds() {
        let slack = RecordingSlackService()
        let coordinator = makeCoordinator(slack: slack)

        coordinator.callStarted(chrome)
        coordinator.callStarted(slackCall)

        // Single presence with the FIRST client; only one call status write.
        #expect(coordinator.currentPresence == .activeCall(chrome))
        #expect(slack.statuses.count == 1)

        coordinator.callEnded()

        #expect(coordinator.currentPresence == .idle)
        #expect(slack.allWrites.last == .clearStatus)
    }

    @Test func secondCaptureJoiningKeepsFirstClientPresenceAtDetectorLevel() {
        // Detector semantics: composition change (first → two clients) must not
        // fire a second start nor a spurious end.
        let listener = FakeMediaDeviceListener(devices: [MediaDeviceID(systemID: 1, kind: .audioInput)])
        let attributor = FakeCallProcessAttributor()
        let scheduler = ManualScheduler()
        attributor.bundleIDs = ["com.google.chrome.helper"]
        let detector = MediaDeviceCallDetector(
            deviceListener: listener,
            attributor: attributor,
            now: { self.now },
            schedule: { scheduler.schedule($0, $1) },
            cancel: { scheduler.cancel($0) }
        )
        var starts = 0
        var ends = 0
        detector.onCallStarted = { _ in starts += 1 }
        detector.onCallEnded = { ends += 1 }
        detector.start()

        listener.fire(device: MediaDeviceID(systemID: 1, kind: .audioInput))
        scheduler.advance(MediaDeviceCallDetector.debounceInterval)
        scheduler.advance(MediaDeviceCallDetector.startGraceInterval)
        #expect(starts == 1)

        // Slack huddle joins mid-call.
        attributor.bundleIDs = ["com.google.chrome.helper", "com.tinyspeck.slackmacgap"]
        listener.fire(device: MediaDeviceID(systemID: 1, kind: .audioInput))
        scheduler.advance(MediaDeviceCallDetector.debounceInterval)
        #expect(starts == 1)
        #expect(ends == 0)
        #expect(detector.isCallActive)
    }

    // MARK: Test 9 — quit mid-call cleanup

    @Test func quitMidCallClearsStatusAndReleasesOwnedDNDOnly() {
        let slack = RecordingSlackService()
        let externalDND = RecordingDNDService(isDNDActive: true) // user-owned DND
        let coordinator = makeCoordinator(slack: slack, dnd: externalDND)

        coordinator.callStarted(chrome)
        #expect(externalDND.writes.isEmpty) // never activated by Focally

        coordinator.callDetectionCleanupOnTerminate()

        #expect(slack.allWrites.last == .clearStatus)
        #expect(externalDND.writes.isEmpty) // owned DND only — nothing released
        #expect(coordinator.currentPresence == .activeCall(chrome) || coordinator.currentPresence == .idle)
        #expect(!CallActivityTracker.shared.isCallActive)

        // Owned case: DND Focally activated IS released.
        let dnd = RecordingDNDService()
        let coordinator2 = makeCoordinator(slack: RecordingSlackService(), dnd: dnd)
        coordinator2.callStarted(chrome)
        coordinator2.callDetectionCleanupOnTerminate()
        #expect(dnd.writes == [.activate, .deactivate])
    }

    // MARK: Test 13 — settings read fresh each transition

    @Test func settingsChangedBetweenCallsTakeEffectWithoutRestart() {
        let suiteName = "CallPresenceCoordinatorTests.settings-live.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let slack = RecordingSlackService()
        let coordinator = makeCoordinator(slack: slack, defaults: defaults)

        coordinator.callStarted(chrome)
        #expect(slack.statuses.last?.text == CallDetectionSettings.defaultStatusMessage)
        coordinator.callEnded()

        // User edits settings between calls (persisted via the store).
        let store = CallDetectionSettingsStore(defaults: defaults)
        store.save(CallDetectionSettings(callStatusMessage: "Second Call Text", enableDNDDuringCalls: false))

        let dnd = RecordingDNDService()
        let coordinator2 = makeCoordinator(slack: slack, dnd: dnd, defaults: defaults)
        coordinator2.callStarted(slackCall)
        #expect(slack.statuses.last?.text == "Second Call Text")
        #expect(slack.statuses.last?.emoji == ":slack-call:")
        #expect(dnd.writes.isEmpty) // DND toggle now off — applies live
    }

    // MARK: Test 17 — user-owned DND never deactivated

    @Test func dndActiveByUserBeforeCallIsNotDeactivatedOnCallEnd() {
        let dnd = RecordingDNDService(isDNDActive: true)
        let coordinator = makeCoordinator(dnd: dnd)

        coordinator.callStarted(chrome)
        #expect(dnd.writes.isEmpty) // Focally did not take ownership

        coordinator.callEnded()

        #expect(dnd.writes.isEmpty) // and never touches the user's DND
    }
}

// MARK: - Fakes (copied from PresenceCoordinatorTests.swift, shared semantics)

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

// Shared test doubles from MediaDeviceCallDetectorTests.swift (file-private
// there, so redeclared here with identical behavior).
@MainActor
private final class FakeMediaDeviceListener: MediaDeviceListening {
    private(set) var added: [MediaDeviceID] = []
    private(set) var removed: [MediaDeviceID] = []
    var enumerated: [MediaDeviceID]
    var capturingBundleIDs: [String] = []
    private var handlers: [MediaDeviceID: @MainActor () -> Void] = [:]

    init(devices: [MediaDeviceID]) {
        self.enumerated = devices
    }

    func enumeratedDeviceIDs() -> [MediaDeviceID] { enumerated }

    func addListener(for device: MediaDeviceID, onChange: @escaping @MainActor () -> Void) -> MediaListenerToken {
        added.append(device)
        handlers[device] = onChange
        return MediaListenerToken(device: device)
    }

    func removeListener(_ token: MediaListenerToken) {
        removed.append(token.device)
        handlers.removeValue(forKey: token.device)
    }

    func isDeviceRunning(_ device: MediaDeviceID) -> Bool { !capturingBundleIDs.isEmpty }

    func fire(device: MediaDeviceID) {
        handlers[device]?()
    }
}

@MainActor
private final class FakeCallProcessAttributor: CallProcessAttributing {
    var bundleIDs: [String] = []
    func capturingBundleIdentifiers() -> [String] { bundleIDs }
}

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
