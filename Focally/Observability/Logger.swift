import Foundation
import OSLog

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
    static let ui = Logger(subsystem: "app.focally.mac", category: "UI")

    // MARK: - Convenience Methods

    /// Log debug level
    static func debug(
        _ message: StaticString,
        _ args: CVarArg...,
        logger: Logger = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        logger.debug(message, args, file: file, function: function, line: line)
    }

    /// Log info level
    static func info(
        _ message: StaticString,
        metadata: [String: String]? = nil,
        _ args: CVarArg...,
        logger: Logger = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        if let metadata = metadata {
            logger.info(message, metadata: metadata, args, file: file, function: function, line: line)
        } else {
            logger.info(message, args, file: file, function: function, line: line)
        }
    }

    /// Log warning level
    static func warning(
        _ message: StaticString,
        metadata: [String: String]? = nil,
        _ args: CVarArg...,
        logger: Logger = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        if let metadata = metadata {
            logger.warning(message, metadata: metadata, args, file: file, function: function, line: line)
        } else {
            logger.warning(message, args, file: file, function: function, line: line)
        }
    }

    /// Log error level
    static func error(
        _ message: StaticString,
        metadata: [String: String]? = nil,
        _ args: CVarArg...,
        logger: Logger = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        if let metadata = metadata {
            logger.error(message, metadata: metadata, args, file: file, function: function, line: line)
        } else {
            logger.error(message, args, file: file, function: function, line: line)
        }
    }

    /// Log fault level (critical error)
    static func fault(
        _ message: StaticString,
        metadata: [String: String]? = nil,
        _ args: CVarArg...,
        logger: Logger = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        if let metadata = metadata {
            logger.fault(message, metadata: metadata, args, file: file, function: function, line: line)
        } else {
            logger.fault(message, args, file: file, function: function, line: line)
        }
    }
}

// MARK: - Logger Extension for Convenience

extension Logger {
    /// Log con metadata estructurada
    func log(
        level: OSLogType,
        _ message: StaticString,
        metadata: [String: Any]? = nil,
        _ args: CVarArg...,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        let stringMetadata = metadata?.mapValues { "\($0)" }
        switch level {
        case .debug:
            debug(message, metadata: stringMetadata, args, file: file, function: function, line: line)
        case .info:
            info(message, metadata: stringMetadata, args, file: file, function: function, line: line)
        case .default:
            warning(message, metadata: stringMetadata, args, file: file, function: function, line: line)
        case .error:
            error(message, metadata: stringMetadata, args, file: file, function: function, line: line)
        case .fault:
            fault(message, metadata: stringMetadata, args, file: file, function: function, line: line)
        @unknown default:
            info(message, metadata: stringMetadata, args, file: file, function: function, line: line)
        }
    }
}