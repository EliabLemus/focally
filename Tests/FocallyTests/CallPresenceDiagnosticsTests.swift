import Foundation
import Testing

@testable import Focally

// audit-call-presence-lifecycle: in-app diagnostics — bounded retention,
// insertion order, and coordinator wiring. The store is in memory only and
// records opaque static codes (privacy contract in CallPresenceDiagnostics).

@MainActor
final class CallPresenceDiagnosticsTests {

    @Test func recordKeepsInsertionOrderWithTimestamps() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        var current = t0
        let diagnostics = CallPresenceDiagnostics(now: { current })

        diagnostics.record(.callStarted)
        current = t0.addingTimeInterval(30)
        diagnostics.record(.slackStatusRequested)

        #expect(diagnostics.recentCodes == [.callStarted, .slackStatusRequested])
        #expect(diagnostics.entries.map(\.date) == [t0, t0.addingTimeInterval(30)])
    }

    @Test func retentionIsBoundedAndDropsOldestFirst() {
        let capacity = 3
        let diagnostics = CallPresenceDiagnostics(now: { Date() }, capacity: capacity)
        let recorded = Array(CallPresenceEvent.allCases.prefix(6))
        for code in recorded {
            diagnostics.record(code)
        }

        #expect(diagnostics.entries.count == capacity)
        // Oldest dropped first; the newest `capacity` events survive in order.
        #expect(diagnostics.recentCodes == Array(recorded.suffix(capacity)))
    }

    @Test func manyEventsBeyondBoundNeverGrowUnbounded() {
        let diagnostics = CallPresenceDiagnostics(now: { Date() }, capacity: 4)
        for _ in 0..<250 {
            diagnostics.record(.callStarted)
        }
        #expect(diagnostics.entries.count == 4)
        #expect(diagnostics.recentCodes == Array(repeating: .callStarted, count: 4))
    }

    @Test func clearEmptiesHistory() {
        let diagnostics = CallPresenceDiagnostics()
        diagnostics.record(.callStarted)
        #expect(!diagnostics.entries.isEmpty)

        diagnostics.clear()
        #expect(diagnostics.entries.isEmpty)
        #expect(diagnostics.recentCodes.isEmpty)
    }

    @Test func entriesCarryOnlyStaticCodesAndDates() throws {
        let diagnostics = CallPresenceDiagnostics()
        diagnostics.record(.noticeStarted)
        // The privacy contract: an entry exposes exactly a CallPresenceEvent
        // (compile-time opaque code) and a Date — nothing else to leak.
        let entry = try #require(diagnostics.entries.first)
        #expect(CallPresenceEvent(rawValue: entry.code.rawValue) == .noticeStarted)
        #expect(diagnostics.entries.allSatisfy { CallPresenceEvent.allCases.contains($0.code) })
    }

    // MARK: coordinator wiring — production events reach the store while
    // OSLog and the test sink keep their existing behavior.

    @Test func coordinatorRecordsEveryEmittedEventPreservingSink() {
        let diagnostics = CallPresenceDiagnostics()
        var sink: [CallPresenceEvent] = []
        let coordinator = DefaultPresenceCoordinator(
            slackService: StubSlackService(),
            dndService: StubDNDService(),
            callSettingsProvider: { CallDetectionSettings() }, // default .notice
            diagnostics: diagnostics
        )
        coordinator.callPresenceEventSink = { sink.append($0) }

        let chrome = CallClient(bundlePrefix: "com.google.chrome", displayName: "Chrome", emoji: ":google-meet:")
        coordinator.callStarted(chrome)
        coordinator.callEnded()

        let expected: [CallPresenceEvent] = [.noticeStarted, .skippedNoticeMode, .noticeEnded]
        #expect(diagnostics.recentCodes == expected)
        #expect(sink == expected) // test sink still mirrors every event
    }

    @Test func coordinatorRecordsFullCallEventSequence() {
        let diagnostics = CallPresenceDiagnostics()
        let coordinator = DefaultPresenceCoordinator(
            slackService: StubSlackService(),
            dndService: StubDNDService(),
            callSettingsProvider: { CallDetectionSettings(uncorroboratedBrowserCapture: .call) },
            diagnostics: diagnostics
        )

        let chrome = CallClient(bundlePrefix: "com.google.chrome", displayName: "Chrome", emoji: ":google-meet:")
        coordinator.callStarted(chrome)
        coordinator.callEnded()

        #expect(diagnostics.recentCodes.contains(.callStarted))
        #expect(diagnostics.recentCodes.contains(.callEnded))
        #expect(diagnostics.recentCodes.first == .callStarted)
        #expect(diagnostics.recentCodes.last == .callEnded) // no session attached → no resume event
    }
}

// MARK: - Minimal fakes (protocol-extension defaults cover the rest)

@MainActor
private final class StubSlackService: PresenceSlackServicing {
    var isEnabled = false
    func savedStatusEmoji() -> String { "" }
    func setStatus(text: String, expirationTimestamp: Int, taskEmoji: String?, fallbackEmoji: String?) {}
    func clearStatus() {}
    func requestSlackDNDSnooze(minutes: Int) -> Bool { false }
    func disableSlackDND() {}
}

@MainActor
private final class StubDNDService: PresenceDNDServicing {
    var isDNDActive = false
    func activateDND() {}
    func deactivateDND() {}
}
