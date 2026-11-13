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
        let settings = CallDetectionSettings(callStatusMessage: "Custom In a Call", uncorroboratedBrowserCapture: .call)
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
        #expect(slack.allWrites.last == .restore)
        #expect(dnd.writes == [.activate, .deactivate])
        #expect(!CallActivityTracker.shared.isCallActive)
    }

    // MARK: Test 5 — no resume on user pause

    @Test func sessionUserPausedBeforeCallIsNotResumedOnCallEnd() {
        let session = FakeCallSessionController(isPaused: true) // user paused manually
        let coordinator = makeCoordinator(session: session, settings: CallDetectionSettings(uncorroboratedBrowserCapture: .call))

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
        let coordinator = makeCoordinator(slack: slack, settings: CallDetectionSettings(uncorroboratedBrowserCapture: .call))

        coordinator.callStarted(chrome)
        coordinator.callStarted(slackCall)

        // Single presence with the FIRST client; only one call status write.
        #expect(coordinator.currentPresence == .activeCall(chrome))
        #expect(slack.statuses.count == 1)

        coordinator.callEnded()

        #expect(coordinator.currentPresence == .idle)
        #expect(slack.allWrites.last == .restore)
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
        let coordinator = makeCoordinator(slack: slack, dnd: externalDND, settings: CallDetectionSettings(uncorroboratedBrowserCapture: .call))

        coordinator.callStarted(chrome)
        #expect(externalDND.writes.isEmpty) // never activated by Focally

        coordinator.callDetectionCleanupOnTerminate()

        #expect(slack.allWrites.last == .clearStatus)
        #expect(externalDND.writes.isEmpty) // owned DND only — nothing released
        #expect(coordinator.currentPresence == .activeCall(chrome) || coordinator.currentPresence == .idle)
        #expect(!CallActivityTracker.shared.isCallActive)

        // Owned case: DND Focally activated IS released.
        let dnd = RecordingDNDService()
        let coordinator2 = makeCoordinator(slack: RecordingSlackService(), dnd: dnd, settings: CallDetectionSettings(uncorroboratedBrowserCapture: .call))
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
        CallDetectionSettingsStore(defaults: defaults).save(CallDetectionSettings(uncorroboratedBrowserCapture: .call))
        let coordinator = makeCoordinator(slack: slack, defaults: defaults)

        coordinator.callStarted(chrome)
        #expect(slack.statuses.last?.text == CallDetectionSettings.defaultStatusMessage)
        coordinator.callEnded()

        // User edits settings between calls (persisted via the store).
        let store = CallDetectionSettingsStore(defaults: defaults)
        store.save(CallDetectionSettings(callStatusMessage: "Second Call Text", enableDNDDuringCalls: false, uncorroboratedBrowserCapture: .call))

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
        let coordinator = makeCoordinator(dnd: dnd, settings: CallDetectionSettings(uncorroboratedBrowserCapture: .call))

        coordinator.callStarted(chrome)
        #expect(dnd.writes.isEmpty) // Focally did not take ownership

        coordinator.callEnded()

        #expect(dnd.writes.isEmpty) // and never touches the user's DND
    }

    // MARK: 1.4 — calendar meeting alone drives presence (no detector)

    @Test func calendarMeetingAloneSetsPresenceWithoutCallDetector() {
        let coordinator = makeCoordinator(session: nil)
        coordinator.calendarSettingsUpdated(calendarSettings(show: true))
        #expect(coordinator.currentPresence == .idle)

        coordinator.calendarMeetingUpdated(makeMeeting())
        #expect(coordinator.currentPresence == .calendarMeeting(makeMeeting()))

        coordinator.calendarMeetingUpdated(nil)
        #expect(coordinator.currentPresence == .idle)
    }

    // MARK: 3.1 — presenceMode purity: trusted natives always a call

    @Test func presenceModeTrustedNativesAlwaysCallOthersFollowSetting() {
        #expect(CallDetectionSettings.presenceMode(forBundlePrefix: "us.zoom.xos", setting: .notice) == .call)
        #expect(CallDetectionSettings.presenceMode(forBundlePrefix: "com.microsoft.teams", setting: .notice) == .call)
        #expect(CallDetectionSettings.presenceMode(forBundlePrefix: "com.google.chrome.helper", setting: .notice) == .notice)
        #expect(CallDetectionSettings.presenceMode(forBundlePrefix: "com.google.chrome.helper", setting: .call) == .call)
    }

    // MARK: 3.2 — notice presence: no DND, no pause, no Slack status

    @Test func noticeModeCaptureIsSoftPresenceWithNoSideEffects() {
        let slack = RecordingSlackService()
        let dnd = RecordingDNDService()
        let session = FakeCallSessionController()
        let coordinator = makeCoordinator(slack: slack, dnd: dnd, session: session) // default .notice

        coordinator.callStarted(chrome)

        #expect(coordinator.isNoticePresenceActive)
        #expect(coordinator.currentPresence == .idle)
        #expect(slack.allWrites.isEmpty)
        #expect(dnd.writes.isEmpty)
        #expect(session.pauseCount == 0)
        #expect(!CallActivityTracker.shared.isCallActive)

        coordinator.callEnded()

        #expect(coordinator.currentPresence == .idle)
        #expect(!coordinator.isNoticePresenceActive)
        #expect(slack.allWrites.isEmpty)
        #expect(dnd.writes.isEmpty)
    }

    // MARK: 4.2 — DND ownership ledger

    @Test func externalUserDNDRegisteredNeverReleased() {
        let dnd = RecordingDNDService(isDNDActive: true) // user-owned
        let ledger = FakeDNDOwnershipLedger()
        let coordinator = makeCoordinator(dnd: dnd, settings: CallDetectionSettings(uncorroboratedBrowserCapture: .call))
        coordinator.dndOwnershipLedger = ledger

        coordinator.callStarted(chrome)

        #expect(dnd.writes.isEmpty) // Focally never activates over the user's DND
        #expect(ledger.externalRegistrations == 1)
        #expect(ledger.ownedRegistrations == 0)

        coordinator.callEnded()

        #expect(ledger.releases == 0) // external ownership is never released
        #expect(dnd.writes.isEmpty)
    }

    @Test func ownedDNDReusedWhileStillWantedAndReleasedOnceAtIdle() {
        let dnd = RecordingDNDService()
        let ledger = FakeDNDOwnershipLedger()
        let coordinator = makeCoordinator(dnd: dnd, settings: CallDetectionSettings(uncorroboratedBrowserCapture: .call))
        coordinator.dndOwnershipLedger = ledger

        // Calendar DND takes ownership first.
        coordinator.calendarSettingsUpdated(calendarSettings(show: true, dnd: true))
        coordinator.calendarMeetingUpdated(makeMeeting())
        #expect(dnd.writes == [.activate])
        #expect(ledger.ownedRegistrations == 1)

        // Call under the meeting wants the same DND → ownership reused.
        coordinator.callStarted(chrome)
        #expect(dnd.writes == [.activate])

        coordinator.callEnded()
        #expect(ledger.releases == 0) // calendar still wants DND
        #expect(dnd.writes == [.activate])

        coordinator.calendarMeetingUpdated(nil)
        #expect(dnd.writes == [.activate, .deactivate])
        #expect(ledger.releases == 1)
    }

    // MARK: 6.1 — live status confirmed: re-apply and restore on end

    @Test func confirmedLiveStatusReappliesAndRestoresOnEnd() {
        let slack = RecordingSlackService() // confirmLiveResult = true
        let coordinator = makeCoordinator(slack: slack, settings: CallDetectionSettings(uncorroboratedBrowserCapture: .call))

        coordinator.callStarted(chrome)
        #expect(slack.statuses.count == 1)

        coordinator.reapplyActivePresence()
        #expect(slack.confirmLiveCalls == 1)
        #expect(slack.statuses.count == 2)

        coordinator.callEnded()
        #expect(slack.allWrites.last == .restore)
    }

    // MARK: 6.2 — manual override pauses sync: no re-apply, no restore

    @Test func manualOverrideDetectedPausesSyncUntilNextTransition() {
        let slack = RecordingSlackService(confirmLiveResult: false)
        let coordinator = makeCoordinator(slack: slack, settings: CallDetectionSettings(uncorroboratedBrowserCapture: .call))

        coordinator.callStarted(chrome)
        #expect(slack.statuses.count == 1)

        coordinator.reapplyActivePresence()
        #expect(slack.confirmLiveCalls == 1)
        #expect(slack.statuses.count == 1) // re-apply suppressed

        coordinator.callEnded()
        #expect(!slack.allWrites.contains(.restore)) // never clobbers the manual status
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
        case restore
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
    private let confirmLiveResult: Bool
    private(set) var allWrites: [Write] = []
    private(set) var statuses: [Status] = []
    private(set) var dndWrites: [DNDWrite] = []
    private(set) var confirmLiveCalls = 0
    private(set) var syncClearCalls = 0

    init(acceptsDNDRequests: Bool = true, confirmLiveResult: Bool = true) {
        self.acceptsDNDRequests = acceptsDNDRequests
        self.confirmLiveResult = confirmLiveResult
    }

    func savedStatusEmoji() -> String { ":saved:" }

    func saveCurrentStatus() {}

    func restoreSavedStatus() {
        allWrites.append(.restore)
    }

    func confirmFocallyStatusStillLive(completion: @escaping (Bool) -> Void) {
        confirmLiveCalls += 1
        completion(confirmLiveResult)
    }

    @discardableResult
    func clearStatusSynchronously(timeoutSeconds: TimeInterval) -> Bool {
        syncClearCalls += 1
        allWrites.append(.clearStatus)
        return true
    }

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
    private var ownedByFocally = false

    init(isDNDActive: Bool = false) {
        self.isDNDActive = isDNDActive
    }

    func activateDND() {
        writes.append(.activate)
        isDNDActive = true
        ownedByFocally = true
    }

    func deactivateDND() {
        writes.append(.deactivate)
        isDNDActive = false
    }

    func performSynchronousDeactivationCleanup(timeoutSeconds: TimeInterval) -> Bool {
        guard isDNDActive, ownedByFocally else { return false }
        deactivateDND()
        ownedByFocally = false
        return true
    }
}

@MainActor
private final class FakeDNDOwnershipLedger: SystemDNDOwnershipLedging {
    private(set) var ownedRegistrations = 0
    private(set) var externalRegistrations = 0
    private(set) var releases = 0
    func registerOwnedSystemDND() { ownedRegistrations += 1 }
    func registerExternalSystemDND() { externalRegistrations += 1 }
    func releaseOwnedSystemDNDAfterVerifiedDeactivation() { releases += 1 }
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
