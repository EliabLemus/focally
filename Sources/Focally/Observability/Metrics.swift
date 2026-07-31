import Foundation
import os

/// Wrapper de OSSignpost para métricas
/// Basado en docs/architecture/ARCHITECTURE.md y docs/exec-plans/active/PLAN-004_OBSERVABILITY.md
final class Metrics {

    // MARK: - Signpost Log (TEMPORALMENTE DESHABILITADO PARA macOS 14+)

    /*
    // OSSignpostLog no está disponible como tipo público en macOS 14+
    // Se puede usar OSLog con signposts, pero requiere migración

    /// Signpost log para la app general
    static let app = OSSignpostLog(subsystem: "app.focally.mac", category: "App")

    /// Signpost log para Calendar Service
    static let calendar = OSSignpostLog(subsystem: "app.focally.mac", category: "Calendar")

    /// Signpost log para Timer Service
    static let timer = OSSignpostLog(subsystem: "app.focally.mac", category: "Timer")

    /// Signpost log para Slack Service
    static let slack = OSSignpostLog(subsystem: "app.focally.mac", category: "Slack")

    /// Signpost log para DND Service
    static let dnd = OSSignpostLog(subsystem: "app.focally.mac", category: "DND")

    /// Signpost log para Analytics
    static let analytics = OSSignpostLog(subsystem: "app.focally.mac", category: "Analytics")

    // MARK: - Instance Methods

    func beginEvent(_ name: StaticString, id: OSSignpostID, _ message: StaticString = "", _ args: CVarArg...) {
        app.beginInterval(name, id: id, message, args)
    }

    func endEvent(_ name: StaticString, id: OSSignpostID, _ message: StaticString = "", _ args: CVarArg...) {
        app.endInterval(name, id: id, message, args)
    }

    func event(_ name: StaticString, _ message: StaticString = "", _ args: CVarArg...) {
        app.emitEvent(name, message, args)
    }

    func event(_ name: StaticString, metadata: os_signpost_metadata_t) {
        app.emitEvent(name, metadata: metadata)
    }

    // MARK: - Convenience Methods

    static func beginTimer(
        _ name: StaticString,
        logger: OSSignpostLog = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> OSSignpostID {
        let signpostID = OSSignpostID(log: logger)
        logger.beginInterval(name, id: signpostID, file: file, function: function, line: line)
        return signpostID
    }

    static func endTimer(
        _ name: StaticString,
        id: OSSignpostID,
        logger: OSSignpostLog = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        logger.endInterval(name, id: id, file: file, function: function, line: line)
    }

    static func measure<T>(
        _ name: StaticString,
        logger: OSSignpostLog = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        block: () throws -> T
    ) rethrows -> T {
        let signpostID = OSSignpostID(log: logger)
        logger.beginInterval(name, id: signpostID, file: file, function: function, line: line)
        defer {
            logger.endInterval(name, id: signpostID, file: file, function: function, line: line)
        }
        return try block()
    }

    static func event(
        _ name: StaticString,
        _ message: StaticString = "",
        logger: OSSignpostLog = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        logger.emitEvent(name, message, file: file, function: function, line: line)
    }

    static func event(
        _ name: StaticString,
        metadata: os_signpost_metadata_t,
        logger: OSSignpostLog = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        logger.emitEvent(name, metadata: metadata, file: file, function: function, line: line)
    }
    */

    // MARK: - TODO: Migrar a OSLog con signposts para macOS 14+

    static func placeholder() {
        // Placeholder para evitar errores de compilación
        // TODO: Migrar a OSLog con signposts cuando sea necesario
    }
}
