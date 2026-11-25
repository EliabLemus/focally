import Foundation
import Observation

/// In-app, privacy-safe diagnostics for the call-presence lifecycle
/// (audit-call-presence-lifecycle): records every static `CallPresenceEvent`
/// code with a timestamp so recent call-detection activity is readable in
/// Calls settings — no `log stream` terminal required.
///
/// In memory only: never written to UserDefaults or disk, empty after quit.
/// Stores ONLY the opaque static event codes and their dates — no bundle IDs,
/// meeting/event titles, Slack status text, URLs, tokens, or OSLog contents.
@MainActor
@Observable
final class CallPresenceDiagnostics {
    /// One recorded event: the static diagnostic code plus when it happened.
    struct Entry: Identifiable {
        let code: CallPresenceEvent
        let date: Date
        let id = UUID()
    }

    static let shared = CallPresenceDiagnostics()

    /// Bounded recent history, oldest first.
    private(set) var entries: [Entry] = []

    /// ponytail: fixed 50-entry bound covers a full call's event burst;
    /// make configurable if real debugging ever hits the ceiling.
    private let capacity: Int
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init, capacity: Int = 50) {
        self.now = now
        self.capacity = max(1, capacity)
    }

    /// Event codes, oldest first — convenience for assertions.
    var recentCodes: [CallPresenceEvent] { entries.map(\.code) }

    /// Records one event; drops the oldest entries beyond the bound.
    func record(_ code: CallPresenceEvent) {
        entries.append(Entry(code: code, date: now()))
        let overflow = entries.count - capacity
        if overflow > 0 { entries.removeFirst(overflow) }
    }

    /// Manual clear from the diagnostics UI.
    func clear() {
        entries.removeAll()
    }
}
