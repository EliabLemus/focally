import Foundation
import os

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

    /// Logger para Analytics
    static let analytics = Logger(subsystem: "app.focally.mac", category: "Analytics")

    /// Logger para UI
    static let uiLogger = Logger(subsystem: "app.focally.mac", category: "UI")

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
