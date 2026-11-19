import Foundation
import os

/// Static, non-redactable call-presence diagnostic codes. Logged through
/// `Logger.callPresenceEvent(_:)` so `log stream` with
/// `subsystem == "app.focally.mac" AND category == "CallDetection"` shows
/// the code unredacted. Codes are deliberately opaque: no bundle IDs,
/// meeting/event details, status text, URLs, or tokens. Effects without a
/// synchronous result API are logged as `requested`, never `applied`.
enum CallPresenceEvent: String, Equatable, CaseIterable {
    case callStarted = "call.started"
    case callEnded = "call.ended"
    case noticeStarted = "notice.started"
    case noticeEnded = "notice.ended"
    case skippedNoticeMode = "skipped:notice_mode"
    case slackSkippedNotConnected = "slack.skipped:not_connected"
    case slackStatusRequested = "slack.status:requested"
    case dndActivateRequested = "dnd.activate:requested"
    case sessionPauseRequested = "session.pause:requested"
    case sessionResumeRequested = "session.resume:requested"
}

/// Wrapper de OSLog para logging estructurado
/// Basado en docs/architecture/ARCHITECTURE.md y docs/exec-plans/active/PLAN-004_OBSERVABILITY.md
final class Logger {

    // MARK: - Shared Instances

    /// Logger para la app general
    static let app = Logger(subsystem: "app.focally.mac", category: "App")

    /// Logger para Calendar Service
    static let calendar = Logger(subsystem: "app.focally.mac", category: "Calendar")

    /// Logger para Timer Service
    static let timer = Logger(subsystem: "app.focally.mac", category: "Timer")

    /// Logger para Slack Service
    static let slack = Logger(subsystem: "app.focally.mac", category: "Slack")

    /// Logger para DND Service
    static let dnd = Logger(subsystem: "app.focally.mac", category: "DND")

    /// Logger para detección de llamadas (TASK-057)
    static let callDetection = Logger(subsystem: "app.focally.mac", category: "CallDetection")

    /// Logger para Analytics
    static let analytics = Logger(subsystem: "app.focally.mac", category: "Analytics")

    /// Logger para UI
    static let uiLogger = Logger(subsystem: "app.focally.mac", category: "UI")

    /// Logger para Update Checker
    static let update = Logger(subsystem: "app.focally.mac", category: "Update")

    /// Logger para Tasks y Reminders
    static let tasks = Logger(subsystem: "app.focally.mac", category: "Tasks")

    // MARK: - Properties

    private let osLogger: os.Logger

    private init(subsystem: String, category: String) {
        self.osLogger = os.Logger(subsystem: subsystem, category: category)
    }

    // MARK: - Instance Methods

    /// Log debug level
    func debug(_ message: String) {
        osLogger.debug("\(message)")
    }

    /// Log info level
    func info(_ message: String) {
        osLogger.info("\(message)")
    }

    /// Log warning level
    func warning(_ message: String) {
        osLogger.warning("\(message)")
    }

    /// Log error level
    func error(_ message: String) {
        osLogger.error("\(message)")
    }

    /// Log fault level (critical error)
    func fault(_ message: String) {
        osLogger.fault("\(message)")
    }

    // MARK: - Call presence diagnostic events

    /// Logs one call-presence event code (see `CallPresenceEvent`). Every
    /// branch uses a compile-time literal format string, so os_log never
    /// redacts it as `<private>` (dynamic string interpolation would be).
    func callPresenceEvent(_ event: CallPresenceEvent) {
        switch event {
        case .callStarted: osLogger.info("call.started")
        case .callEnded: osLogger.info("call.ended")
        case .noticeStarted: osLogger.info("notice.started")
        case .noticeEnded: osLogger.info("notice.ended")
        case .skippedNoticeMode: osLogger.info("skipped:notice_mode")
        case .slackSkippedNotConnected: osLogger.info("slack.skipped:not_connected")
        case .slackStatusRequested: osLogger.info("slack.status:requested")
        case .dndActivateRequested: osLogger.info("dnd.activate:requested")
        case .sessionPauseRequested: osLogger.info("session.pause:requested")
        case .sessionResumeRequested: osLogger.info("session.resume:requested")
        }
    }

    // MARK: - Convenience Methods

    /// Log debug level
    static func debug(
        _ message: String,
        logger: Logger = .app
    ) {
        logger.debug(message)
    }

    /// Log info level
    static func info(
        _ message: String,
        logger: Logger = .app
    ) {
        logger.info(message)
    }

    /// Log warning level
    static func warning(
        _ message: String,
        logger: Logger = .app
    ) {
        logger.warning(message)
    }

    /// Log error level
    static func error(
        _ message: String,
        logger: Logger = .app
    ) {
        logger.error(message)
    }

    /// Log fault level (critical error)
    static func fault(
        _ message: String,
        logger: Logger = .app
    ) {
        logger.fault(message)
    }
}
