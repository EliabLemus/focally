import Foundation

enum PresenceState: Equatable {
    case idle
    case calendarMeeting(CalendarMeeting)
    case manualFocus(FocusMode)
    case activeCall(CallClient)
}

/// Seam for the session pause/resume ownership of the call detector.
@MainActor
protocol CallFocusSessionControlling: AnyObject {
    var hasActiveSession: Bool { get }
    var isSessionPaused: Bool { get }
    func pauseSession()
    func resumeSession()
}

extension FocusTimerService: CallFocusSessionControlling {
    var hasActiveSession: Bool { hasSession }
    var isSessionPaused: Bool { isPaused }
}

/// Shared, testable flag for "a call is active right now" — consulted by
/// NotificationService for Layer 4 self-notification suppression.
@MainActor
final class CallActivityTracker {
    static let shared = CallActivityTracker()
    var isCallActive = false
}

@MainActor
protocol PresenceCoordinating: AnyObject {
    var currentPresence: PresenceState { get }
    var isManualFocusActive: Bool { get }
    var currentCalendarMeeting: CalendarMeeting? { get }
    var isSystemDNDActive: Bool { get }
    var ownsSystemDND: Bool { get }
    var wantsSystemDND: Bool { get }
    func refreshSystemDNDStatus() -> Bool

    func manualFocusStarted(mode: FocusMode, systemDNDEnabled: Bool)
    func manualFocusEnded()
    func calendarMeetingUpdated(_ meeting: CalendarMeeting?)
    func calendarSettingsUpdated(_ settings: SlackCalendarSettings)
    func reapplyActivePresence()
    func callStarted(_ client: CallClient)
    func callEnded()
    func callDetectionCleanupOnTerminate()
}

extension PresenceCoordinating {
    var ownsSystemDND: Bool { false }
    var wantsSystemDND: Bool { false }
    func refreshSystemDNDStatus() -> Bool { isSystemDNDActive }

    func manualFocusStarted(mode: FocusMode) {
        manualFocusStarted(mode: mode, systemDNDEnabled: true)
    }

    func reapplyActivePresence() {}

    func callStarted(_ client: CallClient) {}
    func callEnded() {}
    func callDetectionCleanupOnTerminate() {}
}

@MainActor
protocol PresenceSlackServicing: AnyObject {
    var isEnabled: Bool { get }
    func savedStatusEmoji() -> String
    func setStatus(text: String, expirationTimestamp: Int, taskEmoji: String?, fallbackEmoji: String?)
    func clearStatus()
    @discardableResult
    func requestSlackDNDSnooze(minutes: Int) -> Bool
    func disableSlackDND()
}

@MainActor
protocol PresenceDNDServicing: AnyObject {
    var isDNDActive: Bool { get }
    @discardableResult func refreshDNDStatus() -> Bool
    func activateDND()
    func deactivateDND()
}

extension PresenceDNDServicing {
    @discardableResult
    func refreshDNDStatus() -> Bool { isDNDActive }
}

extension SlackService: PresenceSlackServicing {
    func requestSlackDNDSnooze(minutes: Int) -> Bool {
        guard isEnabled, let token, !token.isEmpty else { return false }

        // SlackService's existing API reports request-preparation failures through
        // connectionError. A sentinel distinguishes a new synchronous failure from
        // an error left behind by an earlier request.
        let previousError = connectionError
        let preparationSentinel = "presence-dnd-preparation-\(UUID().uuidString)"
        connectionError = preparationSentinel
        setSlackDNDSnooze(minutes: minutes)
        guard connectionError == preparationSentinel else { return false }
        connectionError = previousError
        return true
    }
}
extension DNDService: PresenceDNDServicing {}

@MainActor
final class DefaultPresenceCoordinator: PresenceCoordinating {
    private enum SlackDNDSource: Equatable {
        case manual(UUID)
        case calendar(String)
    }

    private struct SlackDNDRequest: Equatable {
        let source: SlackDNDSource
        let minutes: Int
    }

    static let shared = DefaultPresenceCoordinator(
        slackService: SlackService.shared,
        dndService: DNDService.shared
    )

    private let slackService: PresenceSlackServicing
    private let dndService: PresenceDNDServicing
    private let now: () -> Date
    private let scheduleDNDReconciliation: (@escaping @MainActor () -> Void) -> Void
    private var manualMode: FocusMode?
    private var manualSystemDNDEnabled = true
    private var rememberedMeeting: CalendarMeeting?
    private var calendarSettings = SlackCalendarSettings()
    private(set) var activeCallClients: [CallClient] = []
    private var callStartedUnderCalendarPresence = false
    private var callPausedSessionByCallDetection = false
    private let sessionController: (any CallFocusSessionControlling)?
    private let callSettingsProvider: () -> CallDetectionSettings
    private(set) var ownsSystemDND = false
    private(set) var wantsSystemDND = false
    private var ownedSlackDNDRequest: SlackDNDRequest?

    private(set) var currentPresence: PresenceState = .idle
    var isManualFocusActive: Bool { manualMode != nil }
    var currentCalendarMeeting: CalendarMeeting? { rememberedMeeting }
    var isSystemDNDActive: Bool { dndService.isDNDActive }
    func refreshSystemDNDStatus() -> Bool { dndService.refreshDNDStatus() }

    init(
        slackService: PresenceSlackServicing,
        dndService: PresenceDNDServicing,
        now: @escaping () -> Date = Date.init,
        scheduleDNDReconciliation: @escaping (@escaping @MainActor () -> Void) -> Void = { action in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { action() }
        },
        sessionController: (any CallFocusSessionControlling)? = nil,
        callSettingsProvider: @escaping () -> CallDetectionSettings = { CallDetectionSettingsStore().currentSettings() }
    ) {
        self.slackService = slackService
        self.dndService = dndService
        self.now = now
        self.scheduleDNDReconciliation = scheduleDNDReconciliation
        self.sessionController = sessionController
        self.callSettingsProvider = callSettingsProvider
    }

    func manualFocusStarted(mode: FocusMode, systemDNDEnabled: Bool) {
        manualMode = mode.sanitized()
        manualSystemDNDEnabled = systemDNDEnabled
        applyWinningPresence()
    }

    func manualFocusEnded() {
        manualMode = nil
        applyWinningPresence()
    }

    func calendarMeetingUpdated(_ meeting: CalendarMeeting?) {
        rememberedMeeting = meeting
        guard manualMode == nil else { return }
        applyWinningPresence()
    }

    func calendarSettingsUpdated(_ settings: SlackCalendarSettings) {
        calendarSettings = settings
        guard manualMode == nil else { return }
        applyWinningPresence()
    }

    func reapplyActivePresence() {
        guard manualMode != nil || rememberedMeeting != nil || !activeCallClients.isEmpty else { return }
        applyWinningPresence()
    }

    // MARK: Call detection presence

    func callStarted(_ client: CallClient) {
        guard !activeCallClients.contains(where: { $0.bundlePrefix == client.bundlePrefix }) else { return }
        let isFirstCapture = activeCallClients.isEmpty
        activeCallClients.append(client)
        // Calendar presence already showing when the call starts is richer
        // (title); the call must not overwrite it, but still pauses the session.
        callStartedUnderCalendarPresence = isFirstCapture && manualMode == nil && rememberedMeeting != nil
        guard isFirstCapture else { return }

        let settings = callSettingsProvider()
        if settings.pauseFocusDuringCalls, sessionController?.hasActiveSession == true {
            // A session the USER paused manually must never be resumed by us.
            callPausedSessionByCallDetection = !(sessionController?.isSessionPaused ?? false)
            sessionController?.pauseSession()
        }
        CallActivityTracker.shared.isCallActive = true
        applyWinningPresence()
    }

    func callEnded() {
        guard !activeCallClients.isEmpty else { return }
        activeCallClients = []
        callStartedUnderCalendarPresence = false
        CallActivityTracker.shared.isCallActive = false
        let hadOwnedPause = callPausedSessionByCallDetection
        callPausedSessionByCallDetection = false
        // Only resume a session the detector paused; if the session ended while
        // the call was active there is nothing to resume.
        if hadOwnedPause, let sessionController,
           sessionController.hasActiveSession, sessionController.isSessionPaused {
            sessionController.resumeSession()
        }
        applyWinningPresence()
    }

    func callDetectionCleanupOnTerminate() {
        guard !activeCallClients.isEmpty else { return }
        activeCallClients = []
        callStartedUnderCalendarPresence = false
        callPausedSessionByCallDetection = false
        CallActivityTracker.shared.isCallActive = false
        slackService.clearStatus()
        releaseOwnedDND()
    }

    /// While a call is active the call presence wins — except when the call
    /// started under an already-showing calendar meeting (calendar keeps the
    /// presence until the meeting ends).
    private var winningCallClient: CallClient? {
        guard let client = activeCallClients.first else { return nil }
        if callStartedUnderCalendarPresence, rememberedMeeting != nil { return nil }
        return client
    }

    private func applyWinningPresence() {
        if let client = winningCallClient {
            currentPresence = .activeCall(client)
            applyActiveCall(client)
        } else if let manualMode {
            currentPresence = .manualFocus(manualMode)
            applyManualFocus(manualMode)
        } else if let rememberedMeeting {
            currentPresence = .calendarMeeting(rememberedMeeting)
            applyCalendarMeeting(rememberedMeeting)
        } else {
            currentPresence = .idle
            applyIdle()
        }
    }

    private func applyActiveCall(_ client: CallClient) {
        let settings = callSettingsProvider()
        if settings.callStatusEnabled, slackService.isEnabled {
            let expiration = Int(now().addingTimeInterval(4 * 3600).timeIntervalSince1970)
            slackService.setStatus(
                text: settings.sanitizedStatusMessage,
                expirationTimestamp: expiration,
                taskEmoji: client.emoji,
                fallbackEmoji: slackService.savedStatusEmoji()
            )
        }
        applySystemDND(shouldActivate: settings.enableDNDDuringCalls)
    }

    private func applyIdle() {
        slackService.clearStatus()
        releaseOwnedDND()
    }

    private func applyManualFocus(_ mode: FocusMode) {
        if slackService.isEnabled {
            let expiration = Int(now().addingTimeInterval(TimeInterval(mode.sanitizedDurationMinutes * 60)).timeIntervalSince1970)
            slackService.setStatus(
                text: mode.statusText,
                expirationTimestamp: expiration,
                taskEmoji: mode.emoji,
                fallbackEmoji: slackService.savedStatusEmoji()
            )
        }
        applySystemDND(shouldActivate: manualSystemDNDEnabled && mode.enableMacOSDND)
        applySlackDND(
            request: mode.enableSlackDND
                ? SlackDNDRequest(source: .manual(mode.id), minutes: mode.sanitizedDurationMinutes)
                : nil
        )
    }

    private func applyCalendarMeeting(_ meeting: CalendarMeeting) {
        if calendarSettings.showCalendarInSlack {
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
        } else {
            slackService.clearStatus()
        }

        let shouldActivateDND = calendarSettings.activateDNDForVideoCalls && meeting.hasVideoCall
        let remainingMinutes = max(1, Int(ceil(meeting.endTime.timeIntervalSince(now()) / 60)))
        applySystemDND(shouldActivate: shouldActivateDND)
        applySlackDND(
            request: shouldActivateDND
                ? SlackDNDRequest(source: .calendar(meeting.id), minutes: remainingMinutes)
                : nil
        )
    }

    private func applySystemDND(shouldActivate: Bool) {
        wantsSystemDND = shouldActivate
        if shouldActivate {
            guard !ownsSystemDND, !dndService.isDNDActive else { return }
            dndService.activateDND()
            ownsSystemDND = true
        } else if ownsSystemDND {
            if dndService.isDNDActive {
                dndService.deactivateDND()
                ownsSystemDND = false
            } else {
                dndService.deactivateDND()
                scheduleDNDReconciliation { [weak self] in
                    self?.reconcilePendingSystemDNDRelease()
                }
            }
        }
    }

    private func reconcilePendingSystemDNDRelease() {
        guard ownsSystemDND, !wantsSystemDND else { return }
        dndService.deactivateDND()
        ownsSystemDND = false
    }

    private func applySlackDND(request: SlackDNDRequest?) {
        if let request {
            guard request != ownedSlackDNDRequest else { return }
            if slackService.requestSlackDNDSnooze(minutes: request.minutes) {
                ownedSlackDNDRequest = request
            }
        } else if ownedSlackDNDRequest != nil {
            slackService.disableSlackDND()
            ownedSlackDNDRequest = nil
        }
    }

    private func releaseOwnedDND() {
        applySystemDND(shouldActivate: false)
        applySlackDND(request: nil)
    }
}
