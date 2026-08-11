import Foundation
import Testing
@testable import Focally

@MainActor
@Suite("Slack operation state", .serialized)
struct SlackOperationStateTests {
    @Test func connectionTestTransitionsFromWorkingToSuccess() async throws {
        let transport = RecordingSlackTransport()
        let service = SlackService(
            tokenForTesting: "xoxp-test-only-not-a-real-slack-token",
            requestPerformer: transport.perform
        )

        #expect(service.connectionTestState == .idle)

        service.testConnection()

        #expect(service.connectionTestState == .working)
        #expect(transport.requestCount == 1)

        transport.complete(json: ["ok": true], statusCode: 200)
        await Task.yield()

        #expect(service.connectionTestState == .success("Connected ✓"))
        #expect(service.isConnected)
    }

    @Test func connectionTestTransitionsFromWorkingToFailedForSlackAPIError() async throws {
        let transport = RecordingSlackTransport()
        let service = SlackService(
            tokenForTesting: "xoxp-test-only-not-a-real-slack-token",
            requestPerformer: transport.perform
        )

        service.testConnection()

        #expect(service.connectionTestState == .working)
        #expect(transport.requestCount == 1)

        transport.complete(json: ["ok": false, "error": "invalid_auth"], statusCode: 200)
        await Task.yield()

        #expect(service.connectionTestState == .failed("Invalid Slack token. Please check your token and try again."))
        #expect(!service.isConnected)
    }

    @Test func connectionTestRetryClearsFailureAndCanSucceed() async throws {
        let transport = RecordingSlackTransport()
        let service = SlackService(
            tokenForTesting: "xoxp-test-only-not-a-real-slack-token",
            requestPerformer: transport.perform
        )

        service.testConnection()
        transport.complete(json: ["ok": false, "error": "invalid_auth"], statusCode: 200)
        await Task.yield()

        #expect(service.connectionTestState == .failed("Invalid Slack token. Please check your token and try again."))

        service.testConnection()

        #expect(service.connectionTestState == .working)
        #expect(transport.requestCount == 2)

        transport.complete(json: ["ok": true], statusCode: 200)
        await Task.yield()

        #expect(service.connectionTestState == .success("Connected ✓"))
        #expect(service.isConnected)
    }

    @Test func connectionTestIgnoresDuplicateInvocationWhileWorking() {
        let transport = RecordingSlackTransport()
        let service = SlackService(
            tokenForTesting: "xoxp-test-only-not-a-real-slack-token",
            requestPerformer: transport.perform
        )

        service.testConnection()
        #expect(service.connectionTestState == .working)

        service.testConnection()

        #expect(service.connectionTestState == .working)
        #expect(transport.requestCount(path: "/api/auth.test") == 1)
        #expect(transport.pendingRequestCount(path: "/api/auth.test") == 1)
    }

    @Test func testInitializerDoesNotPersistEnabledToStandardDefaults() {
        let suiteName = "SlackOperationStateTests.initializer.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let sentinel = true
        defaults.set(sentinel, forKey: "slackEnabled")

        let service = SlackService(
            tokenForTesting: "xoxp-test-only-not-a-real-slack-token",
            enabled: !sentinel,
            enabledDefaults: defaults,
            requestPerformer: RecordingSlackTransport().perform
        )

        #expect(service.isEnabled == !sentinel)
        #expect(defaults.object(forKey: "slackEnabled") as? Bool == sentinel)

        service.isEnabled = sentinel
        service.isEnabled = !sentinel

        #expect(defaults.object(forKey: "slackEnabled") as? Bool == !sentinel)
    }

    @Test func connectionTestWithExplicitNilTokenTransitionsThroughWorkingToFailedWithoutRequest() {
        let transport = RecordingSlackTransport()
        let service = SlackService(
            tokenForTesting: nil,
            requestPerformer: transport.perform
        )

        service.testConnection()

        #expect(service.connectionTestState == .failed("No token configured"))
        #expect(!service.isConnected)
        #expect(transport.requestCount == 0)
    }

    @Test func focusStatusTestCompletesOnlyFromStatusResponse() async throws {
        let transport = RecordingSlackTransport()
        let slackService = SlackService(
            tokenForTesting: "xoxp-test-only-not-a-real-slack-token",
            enabled: true,
            requestPerformer: transport.perform
        )
        let suiteName = "SlackOperationStateTests.focus-status-test"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = FocusIntegrationService(
            presenceCoordinator: InertPresenceCoordinator(),
            slackService: slackService,
            defaults: defaults,
            shortcutBackup: { _ in }
        )
        var completionCount = 0
        var completionResult: (Bool, String)?

        #expect(service.slackTestState == .idle)

        service.runSlackTest { success, message in
            completionCount += 1
            completionResult = (success, message)
        }

        #expect(service.slackTestState == .working)
        #expect(completionCount == 0)

        service.runSlackTest { _, _ in
            completionCount += 1
        }

        #expect(service.slackTestState == .working)
        #expect(transport.requestCount(path: "/api/users.profile.set") == 1)
        #expect(transport.pendingRequestCount(path: "/api/users.profile.set") == 1)

        transport.complete(
            path: "/api/dnd.endSnooze",
            json: ["ok": true],
            statusCode: 200
        )
        await Task.yield()

        #expect(service.slackTestState == .working)
        #expect(completionCount == 0)

        try await Task.sleep(for: .milliseconds(300))

        #expect(service.slackTestState == .working)
        #expect(completionCount == 0)

        transport.complete(
            path: "/api/users.profile.set",
            json: ["ok": true],
            statusCode: 200
        )
        await Task.yield()

        #expect(service.slackTestState == .success("Slack focus status updated"))
        #expect(completionCount == 1)
        #expect(completionResult?.0 == true)
        #expect(completionResult?.1 == "Slack focus status updated")

        try await Task.sleep(for: .milliseconds(300))

        #expect(completionCount == 1)
    }

    @Test func setStatusReportsEmojiUsageThroughInjectedRecorder() {
        let transport = RecordingSlackTransport()
        var recordedEmojis: [String] = []
        let service = SlackService(
            tokenForTesting: "xoxp-test-only-not-a-real-slack-token",
            enabled: true,
            requestPerformer: transport.perform,
            emojiUsageRecorder: { recordedEmojis.append($0) }
        )

        service.setStatus(
            text: "Deep work",
            expirationTimestamp: 1_800,
            taskEmoji: "🎯",
            fallbackEmoji: ":hourglass_flowing_sand:"
        )

        #expect(recordedEmojis == [":dart:"])
        #expect(transport.requestCount(path: "/api/users.profile.set") == 1)
    }

    @Test func operationErrorsLocalizeStaticMessagesAndPreserveDynamicDetails() {
        let exactCases = [
            ("Slack integration is disabled", "slack_error_integration_disabled"),
            ("No Slack token configured", "slack_error_no_token"),
            ("No token configured", "slack_error_no_token"),
            ("Failed to prepare Slack status request", "slack_error_prepare_status_request"),
            ("Failed to prepare Slack auth.test request", "slack_error_prepare_connection_request"),
            ("Invalid response from Slack", "slack_error_invalid_response"),
            ("No internet connection", "slack_error_no_internet"),
            ("Network request timed out", "slack_error_network_timeout"),
            ("Cannot connect to Slack server", "slack_error_cannot_connect"),
            ("Cannot find Slack server", "slack_error_cannot_find_server"),
            ("Invalid Slack token. Please check your token and try again.", "slack_error_invalid_token"),
            ("Access denied. Your token may not have the required permissions.", "slack_error_access_denied"),
            ("Too many requests. Please wait a moment and try again.", "slack_error_rate_limited"),
            ("Your token is missing required permissions.", "slack_error_missing_permissions"),
            ("Your Slack account is inactive.", "slack_error_account_inactive"),
            ("Your Slack token has been revoked.", "slack_error_token_revoked"),
            ("Your Slack workspace requires login.", "slack_error_workspace_login"),
            (
                "Slack status updates require a user token (xoxp-) with users.profile:write",
                "slack_error_user_token_required"
            )
        ]

        for (message, expectedKey) in exactCases {
            #expect(SlackService.localizedOperationError(
                message,
                localizedString: { "localized:\($0)" }
            ) == "localized:\(expectedKey)")
        }

        let translations = [
            "slack_error_integration_disabled": "Integración desactivada",
            "slack_error_network_format": "Error de red: %@",
            "slack_error_api_format": "Error de API de Slack: %@"
        ]
        let localize: (String) -> String = { translations[$0, default: $0] }

        #expect(SlackService.localizedOperationError(
            "Slack integration is disabled",
            localizedString: localize
        ) == "Integración desactivada")
        #expect(SlackService.localizedOperationError(
            "Network error: conexión restablecida por el peer",
            localizedString: localize
        ) == "Error de red: conexión restablecida por el peer")
        #expect(SlackService.localizedOperationError(
            "Slack API error: custom_workspace_error",
            localizedString: localize
        ) == "Error de API de Slack: custom_workspace_error")
    }
}

private final class RecordingSlackTransport {
    typealias Completion = (Data?, URLResponse?, Error?) -> Void

    private struct PendingRequest {
        let request: URLRequest
        let completion: Completion
    }

    private var completions: [PendingRequest] = []
    private var recordedRequests: [URLRequest] = []
    private(set) var requestCount = 0

    func perform(_ request: URLRequest, completion: @escaping Completion) {
        requestCount += 1
        recordedRequests.append(request)
        completions.append(PendingRequest(request: request, completion: completion))
    }

    func requestCount(path: String) -> Int {
        recordedRequests.count { $0.url?.path == path }
    }

    func pendingRequestCount(path: String) -> Int {
        completions.count { $0.request.url?.path == path }
    }

    func complete(json: [String: Any], statusCode: Int) {
        let completion = completions.removeFirst().completion
        complete(completion: completion, json: json, statusCode: statusCode)
    }

    func complete(path: String, json: [String: Any], statusCode: Int) {
        let index = completions.firstIndex { $0.request.url?.path == path }!
        let completion = completions.remove(at: index).completion
        complete(completion: completion, json: json, statusCode: statusCode)
    }

    private func complete(completion: Completion, json: [String: Any], statusCode: Int) {
        let data = try! JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(
            url: URL(string: "https://slack.test/api")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )
        completion(data, response, nil)
    }
}

@MainActor
private final class InertPresenceCoordinator: PresenceCoordinating {
    var currentPresence: PresenceState = .idle
    var isManualFocusActive = false
    var currentCalendarMeeting: CalendarMeeting?
    var isSystemDNDActive = false

    func manualFocusStarted(mode: FocusMode, systemDNDEnabled: Bool) {}
    func manualFocusEnded() {}
    func calendarMeetingUpdated(_ meeting: CalendarMeeting?) {}
    func calendarSettingsUpdated(_ settings: SlackCalendarSettings) {}
}
