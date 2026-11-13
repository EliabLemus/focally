import Foundation
import Testing

@testable import Focally

// TASK-058: per-client Slack emoji overrides — pure resolution, store
// round-trip, and coordinator wiring (override emoji reaches setStatus).

@MainActor
private final class OverrideRecordingSlackService: PresenceSlackServicing {
    struct Status: Equatable {
        let text: String
        let expiration: Int
        let emoji: String?
        let fallbackEmoji: String?
    }

    var isEnabled = true
    var workspaceEmojiCodes: [String] = []
    private(set) var statuses: [Status] = []

    func savedStatusEmoji() -> String { ":saved:" }

    func setStatus(text: String, expirationTimestamp: Int, taskEmoji: String?, fallbackEmoji: String?) {
        statuses.append(Status(text: text, expiration: expirationTimestamp, emoji: taskEmoji, fallbackEmoji: fallbackEmoji))
    }

    func clearStatus() {}
    func requestSlackDNDSnooze(minutes: Int) -> Bool { false }
    func disableSlackDND() {}
}

@MainActor
private final class OverrideRecordingDNDService: PresenceDNDServicing {
    private(set) var isDNDActive: Bool = false
    private(set) var writes: [String] = []

    func activateDND() {
        writes.append("activate")
        isDNDActive = true
    }

    func deactivateDND() {
        writes.append("deactivate")
        isDNDActive = false
    }
}

@MainActor
private final class OverrideFakeSessionController: CallFocusSessionControlling {
    var hasActiveSession = false
    var isSessionPaused = false
    func pauseSession() { isSessionPaused = true }
    func resumeSession() { isSessionPaused = false }
}

@MainActor
struct CallClientOverrideTests {
    private let now = Date()
    private let arc = "company.thebrowser.something"

    // MARK: - Pure resolution

    @Test("Arc resolves to :google-meet: by default")
    func arcDefaultEmoji() {
        let client = CallClientCatalog.client(for: arc)
        #expect(client.emoji == ":google-meet:")
        #expect(client.displayName == "Arc")
    }

    @Test("Override replaces only the emoji")
    func overrideAppliesEmojiOnly() {
        let overrides = ["company.thebrowser": ":video-camera:"]
        let client = CallClientCatalog.client(for: arc, emojiOverrides: overrides, unknownEmoji: nil)
        #expect(client.emoji == ":video-camera:")
        #expect(client.bundlePrefix == "company.thebrowser")
        #expect(client.displayName == "Arc")
    }

    @Test("Matching and displayName stay intact with overrides present")
    func matchingUnaffected() {
        let overrides = ["com.tinyspeck.slackmacgap": ":headphones:"]
        let client = CallClientCatalog.client(
            for: "com.tinyspeck.slackmacgap.helper",
            emojiOverrides: overrides,
            unknownEmoji: nil
        )
        #expect(client.displayName == "Slack Call")
        #expect(client.emoji == ":headphones:")
    }

    @Test("Unknown client uses the dedicated unknown override")
    func unknownOverride() {
        let client = CallClientCatalog.client(
            for: "com.unknown.vendor",
            emojiOverrides: [:],
            unknownEmoji: ":telephone-receiver:"
        )
        #expect(client.emoji == ":telephone-receiver:")
        #expect(client.bundlePrefix == CallClientCatalog.unknownClient.bundlePrefix)
    }

    @Test("Empty overrides behave exactly like v0.11.1")
    func noOverrideMatchesBaseline() {
        for bundleID in CallClientCatalog.defaultClients.map(\.bundlePrefix) {
            let baseline = CallClientCatalog.client(for: bundleID)
            let withEmpty = CallClientCatalog.client(for: bundleID, emojiOverrides: [:], unknownEmoji: nil)
            #expect(baseline == withEmpty)
        }
    }

    @Test("Empty-string override is treated as no override")
    func emptyStringOverrideIgnored() {
        let client = CallClientCatalog.client(
            for: "com.google.chrome",
            emojiOverrides: ["com.google.chrome": ""],
            unknownEmoji: ""
        )
        #expect(client.emoji == ":google-meet:")
    }

    // MARK: - Store round-trip

    @Test("Store persists and reloads emoji overrides")
    func storeRoundTrip() throws {
        let suite = "call-emoji-override-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = CallDetectionSettingsStore(defaults: defaults)
        var settings = store.currentSettings()
        settings.callClientEmojiOverrides = ["company.thebrowser": ":google-meet:"]
        settings.unknownCallClientEmoji = ":phone:"
        store.save(settings)

        let reloaded = CallDetectionSettingsStore(defaults: defaults).currentSettings()
        #expect(reloaded.callClientEmojiOverrides == ["company.thebrowser": ":google-meet:"])
        #expect(reloaded.unknownCallClientEmoji == ":phone:")

        // Clearing removes the persisted keys.
        settings.callClientEmojiOverrides = [:]
        settings.unknownCallClientEmoji = nil
        store.save(settings)
        let cleared = CallDetectionSettingsStore(defaults: defaults).currentSettings()
        #expect(cleared.callClientEmojiOverrides.isEmpty)
        #expect(cleared.unknownCallClientEmoji == nil)
    }

    // MARK: - Coordinator wiring

    @Test("Coordinator resolves the override emoji into setStatus")
    func coordinatorAppliesOverride() {
        let slack = OverrideRecordingSlackService()
        slack.workspaceEmojiCodes = [":video-camera:", ":google-meet:"]
        let dnd = OverrideRecordingDNDService()
        let coordinator = DefaultPresenceCoordinator(
            slackService: slack,
            dndService: dnd,
            now: { self.now },
            sessionController: OverrideFakeSessionController(),
            callSettingsProvider: {
                CallDetectionSettings(
                    callClientEmojiOverrides: ["company.thebrowser": ":video-camera:"],
                    uncorroboratedBrowserCapture: .call
                )
            }
        )

        coordinator.callStarted(CallClient(bundlePrefix: "company.thebrowser", displayName: "Arc", emoji: ":google-meet:"))

        #expect(slack.statuses.count == 1)
        #expect(slack.statuses.first?.emoji == ":video-camera:")
    }

    @Test("Coordinator without overrides keeps the catalog emoji")
    func coordinatorWithoutOverrides() {
        let slack = OverrideRecordingSlackService()
        let dnd = OverrideRecordingDNDService()
        let coordinator = DefaultPresenceCoordinator(
            slackService: slack,
            dndService: dnd,
            now: { self.now },
            sessionController: OverrideFakeSessionController(),
            callSettingsProvider: { CallDetectionSettings(uncorroboratedBrowserCapture: .call) }
        )

        coordinator.callStarted(CallClientCatalog.client(for: arc))

        #expect(slack.statuses.first?.emoji == ":google-meet:")
    }

    @Test("Unknown-client override reaches setStatus for unknown bundles")
    func coordinatorUnknownOverride() {
        let slack = OverrideRecordingSlackService()
        let dnd = OverrideRecordingDNDService()
        let coordinator = DefaultPresenceCoordinator(
            slackService: slack,
            dndService: dnd,
            now: { self.now },
            sessionController: OverrideFakeSessionController(),
            callSettingsProvider: {
                CallDetectionSettings(unknownCallClientEmoji: ":crystal-ball:", uncorroboratedBrowserCapture: .call)
            }
        )

        coordinator.callStarted(CallClientCatalog.client(for: "com.something.unheard.of"))

        #expect(slack.statuses.first?.emoji == ":crystal-ball:")
    }
}
