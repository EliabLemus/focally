import Foundation
import os.signpost

/// Wrapper de OSSignpost para métricas
/// Basado en docs/architecture/ARCHITECTURE.md y docs/exec-plans/active/PLAN-004_OBSERVABILITY.md
final class Metrics {

    // MARK: - Signpost Log

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

    // MARK: - Counter

    /// Incrementar un counter
    static func increment(
        _ name: StaticString,
        by amount: Int = 1,
        metadata: [String: String]? = nil,
        signpostLog: OSSignpostLog = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        let signpostID = OSSignpostID(log: signpostLog)
        if let metadata = metadata {
            os_signpost(
                .event,
                signpostLog,
                signpostID,
                name,
                "\(name) += \(amount)",
                os_signpost_metadata(metadata)
            )
        } else {
            os_signpost(
                .event,
                signpostLog,
                signpostID,
                name,
                "\(name) += \(amount)"
            )
        }
    }

    // MARK: - Gauge

    /// Setear un gauge (valor instantáneo)
    static func gauge(
        _ name: StaticString,
        value: Double,
        metadata: [String: String]? = nil,
        signpostLog: OSSignpostLog = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        let signpostID = OSSignpostID(log: signpostLog)
        if let metadata = metadata {
            os_signpost(
                .event,
                signpostLog,
                signpostID,
                name,
                "\(name) = \(value)",
                os_signpost_metadata(metadata)
            )
        } else {
            os_signpost(
                .event,
                signpostLog,
                signpostID,
                name,
                "\(name) = \(value)"
            )
        }
    }

    // MARK: - Histogram

    /// Registrar un valor en un histograma
    static func histogram(
        _ name: StaticString,
        value: Double,
        metadata: [String: String]? = nil,
        signpostLog: OSSignpostLog = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        let signpostID = OSSignpostID(log: signpostLog)
        if let metadata = metadata {
            os_signpost(
                .event,
                signpostLog,
                signpostID,
                name,
                "\(name)[\(value)]",
                os_signpost_metadata(metadata)
            )
        } else {
            os_signpost(
                .event,
                signpostLog,
                signpostID,
                name,
                "\(name)[\(value)]"
            )
        }
    }

    // MARK: - Duration

    /// Medir duración de un bloque de código
    static func measure<T>(
        _ name: StaticString,
        metadata: [String: String]? = nil,
        signpostLog: OSSignpostLog = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        block: () throws -> T
    ) rethrows -> T {
        let signpostID = OSSignpostID(log: signpostLog)

        os_signpost(
            .begin,
            signpostLog,
            signpostID,
            name,
            "\(name) started"
        )

        let start = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(start)

        let durationMs = duration * 1000

        if let metadata = metadata {
            os_signpost(
                .end,
                signpostLog,
                signpostID,
                name,
                "\(name) completed",
                os_signpost_metadata(metadata.merging(["duration_ms": String(format: "%.2f", durationMs)]) { _, new in new })
            )
        } else {
            os_signpost(
                .end,
                signpostLog,
                signpostID,
                name,
                "\(name) completed",
                os_signpost_metadata(["duration_ms": String(format: "%.2f", durationMs)])
            )
        }

        return result
    }

    // MARK: - Event

    /// Registrar un evento
    static func event(
        _ name: StaticString,
        metadata: [String: String]? = nil,
        signpostLog: OSSignpostLog = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        let signpostID = OSSignpostID(log: signpostLog)
        if let metadata = metadata {
            os_signpost(
                .event,
                signpostLog,
                signpostID,
                name,
                "\(String(describing: name))",
                os_signpost_metadata(metadata)
            )
        } else {
            os_signpost(
                .event,
                signpostLog,
                signpostID,
                name,
                "\(String(describing: name))"
            )
        }
    }

    // MARK: - Helper

    /// Convertir metadata dictionary a os_signpost_metadata_t
    private static func os_signpost_metadata(_ metadata: [String: String]) -> os_signpost_metadata_t {
        var pointer: os_signpost_metadata_t?
        metadata.forEach { key, value in
            os_signpost_metadata_t_add(&pointer, key, value)
        }
        return pointer!
    }
}

// MARK: - Metrics Extension for Convenience

extension Metrics {
    /// Track evento de sesión iniciada
    static func trackSessionStarted(duration: Int, taskName: String) {
        increment("sessions_started")
        gauge("current_session_duration", value: Double(duration), metadata: ["task_name": taskName])
        event("session_started", metadata: ["task_name": taskName, "duration_seconds": "\(duration)"])
    }

    /// Track evento de sesión terminada
    static func trackSessionCompleted(duration: Int, taskName: String) {
        increment("sessions_completed")
        gauge("current_session_duration", value: 0)
        event("session_completed", metadata: ["task_name": taskName, "duration_seconds": "\(duration)"])
    }

    /// Track evento de sync de calendario
    static func trackCalendarSync(eventCount: Int, durationMs: Double) {
        increment("calendar_syncs")
        histogram("calendar_sync_duration_ms", value: durationMs)
        gauge("calendar_event_count", value: Double(eventCount))
        event("calendar_sync", metadata: ["event_count": "\(eventCount)", "duration_ms": String(format: "%.2f", durationMs)])
    }

    /// Track evento de error
    static func trackError(error: Error, service: String) {
        increment("errors", metadata: ["service": service, "error_type": String(describing: type(of: error))])
        event("error", metadata: ["service": service, "error": error.localizedDescription])
    }
}