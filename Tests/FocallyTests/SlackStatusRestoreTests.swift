import Foundation
import Testing
@testable import Focally

// Lane C (calendar-first-call-detection) — slack-presence-sync 6.1, 6.3, 6.5
// + call-reliability 4.4: save/restore status with check-before-restore,
// endSnooze prohibited as release, 100-char truncation, backup expiration,
// xoxp token validation, clearStatus retry.

/// Request recorder + stub responder for `SlackService`'s test initializer.
/// Thread-safe (the transport closure runs on whatever thread the API client uses).
private final class FakeSlackTransport {
    struct Call {
        let path: String
        let body: String
    }

    private let lock = NSLock()
    private var calls: [Call] = []
    /// Number of leading calls per path that fail (transport error / ok:false).
    var failuresRemainingByPath: [String: Int] = [:]
    /// Fixed users.profile.get response (mutate mid-test for manual changes).
    var currentProfileJSON: [String: Any] = ["ok": true, "profile": ["status_text": "", "status_emoji": "", "status_expiration": 0]]

    private func json(for request: URLRequest) -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        let path = request.url?.path ?? ""
        if path.contains("users.profile.get") {
            var json = currentProfileJSON
            json["ok"] = true
            return json
        }
        let remaining = failuresRemainingByPath[path] ?? 0
        if remaining > 0 {
            failuresRemainingByPath[path] = remaining - 1
            return ["ok": false, "error": "ratelimited"]
        }
        return ["ok": true]
    }

    func perform(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let call = Call(path: request.url?.path ?? "", body: String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")
        lock.lock()
        calls.append(call)
        lock.unlock()
        let json = json(for: request)
        let data = try? JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        completion(data, response, nil)
    }

    func setFailuresRemaining(_ value: Int, path: String) {
        lock.lock()
        defer { lock.unlock() }
        failuresRemainingByPath[path] = value
    }

    func setCurrentProfile(_ json: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }
        currentProfileJSON = json
    }

    func profileSetCalls() -> [Call] {
        lock.lock()
        defer { lock.unlock() }
        return calls.filter { $0.path.contains("users.profile.set") }
    }

    func allCalls() -> [Call] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    /// Decodes the `profile=` JSON payload of a profile.set call.
    func profilePayload(of call: Call) -> [String: String] {
        for pair in call.body.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.first == "profile",
               let raw = parts.last,
               let decoded = String(raw).removingPercentEncoding,
               let data = decoded.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                return json
            }
        }
        return [:]
    }
}

@MainActor
final class SlackStatusRestoreTests {
    private let transport = FakeSlackTransport()
    private let defaults = UserDefaults(suiteName: "SlackStatusRestoreTests")!

    private func makeService(
        now: @escaping () -> Date = Date.init,
        clearStatusRetryDelay: @escaping (TimeInterval) async -> Void = { _ in }
    ) -> SlackService {
        SlackService(
            tokenForTesting: "***",
            enabled: true,
            enabledDefaults: defaults,
            requestPerformer: { [transport] request, completion in
                transport.perform(request, completion: completion)
            },
            now: now,
            clearStatusRetryDelay: clearStatusRetryDelay
        )
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, maxTicks: Int = 300) async -> Bool {
        for _ in 0..<maxTicks {
            if condition() { return true }
            await Task.yield()
        }
        return condition()
    }

    // MARK: 6.5 — truncation & payload

    @Test func statusTextIsTruncatedToOneHundredChars() {
        #expect(SlackService.truncatedStatusText(String(repeating: "a", count: 150)).count == 100)
        #expect(SlackService.truncatedStatusText("short") == "short")
    }

    @Test func setStatusSendsTruncatedTextAndBackupExpiration() async {
        let fixedNow = Date(timeIntervalSince1970: 1_000_000)
        let service = makeService(now: { fixedNow })
        service.saveCurrentStatus() // no snapshot → restore no-ops later, irrelevant here

        await service.setStatusForTest(
            text: String(repeating: "x", count: 120),
            expirationTimestamp: 0 // past → backup expiration expected
        )

        let call = transport.profileSetCalls().last
        #expect(call != nil)
        let payload = transport.profilePayload(of: call!)
        #expect(payload["status_text"]?.count == 100)
        #expect(payload["status_expiration"] == "\(Int(fixedNow.timeIntervalSince1970) + SlackService.backupExpirationMarginSeconds)")
    }

    @Test func setStatusKeepsFutureExpiration() async {
        let fixedNow = Date(timeIntervalSince1970: 1_000_000)
        let service = makeService(now: { fixedNow })

        await service.setStatusForTest(text: "In a call", expirationTimestamp: 2_000_000)

        let payload = transport.profilePayload(of: transport.profileSetCalls().last!)
        #expect(payload["status_expiration"] == "2000000")
    }

    @Test func onlyUserTokensAreValid() {
        #expect(SlackService.isValidUserToken("xoxp-123"))
        #expect(!SlackService.isValidUserToken("xoxb-bot"))
        #expect(!SlackService.isValidUserToken("xoxs-"))
    }

    // MARK: 6.1 — save & restore

    @Test func manualStatusIsSavedAndRestoredAfterCall() async {
        let service = makeService()
        // User's own "Lunch" status before the call.
        transport.setCurrentProfile(["ok": true, "profile": [
            "status_text": "Lunch", "status_emoji": ":hamburger:", "status_expiration": 1_700_000_000
        ]])
        let saved = await saveAndWait(service)
        #expect(saved?.statusText == "Lunch")

        // Focally sets its call status.
        await service.setStatusForTest(text: "In a call", expirationTimestamp: 2_000_000)
        #expect(service.focallySetStatus?.statusText == "In a call")
        // The live profile now holds Focally's status (what setStatus actually sent).
        let focallyPayload = transport.profilePayload(of: transport.profileSetCalls().last!)
        transport.setCurrentProfile(["ok": true, "profile": focallyPayload])

        // Call ends: live profile still holds Focally's status → restore.
        let restored = await restoreAndWait(service)
        #expect(restored)
        let payload = transport.profilePayload(of: transport.profileSetCalls().last!)
        #expect(payload["status_text"] == "Lunch")
        #expect(payload["status_emoji"] == ":hamburger:")
        #expect(payload["status_expiration"] == "1700000000")
    }

    @Test func manualMidCallChangeIsNeverOverwritten() async {
        let service = makeService()
        transport.setCurrentProfile(["ok": true, "profile": [
            "status_text": "Lunch", "status_emoji": ":hamburger:", "status_expiration": 0
        ]])
        _ = await saveAndWait(service)

        await service.setStatusForTest(text: "In a call", expirationTimestamp: 2_000_000)

        // User manually changed their status mid-call.
        transport.setCurrentProfile(["ok": true, "profile": [
            "status_text": "Busy", "status_emoji": ":coffee:", "status_expiration": 0
        ]])

        let restored = await restoreAndWait(service)
        #expect(!restored)
        // No restore write happened after the manual change.
        #expect(transport.allCalls().last?.path.contains("users.profile.set") == false)
    }

    @Test func restoreWithoutSnapshotFails() async {
        let service = makeService()
        #expect(await restoreAndWait(service) == false)
    }

    // MARK: 6.3 — endSnooze prohibited as release

    @Test func disableSlackDNDDoesNotCallEndSnooze() async {
        let service = makeService()
        service.disableSlackDND()
        await waitUntil { false } // drain ticks
        #expect(transport.allCalls().isEmpty) // no network request at all
    }

    // MARK: 4.4 — clearStatus retry

    @Test func clearStatusRetriesOnceOnFailure() async {
        let service = makeService(clearStatusRetryDelay: { _ in }) // no real backoff sleep in tests
        transport.setFailuresRemaining(1, path: "/api/users.profile.set")

        service.clearStatus()
        let retried = await waitUntil { [transport] in
            transport.profileSetCalls().count >= 2
        }
        #expect(retried)
        #expect(transport.profileSetCalls().count == SlackService.clearStatusMaxAttempts)
        // The retry payload clears the status.
        let payload = transport.profilePayload(of: transport.profileSetCalls()[1])
        #expect(payload["status_text"] == "")
    }

    // MARK: helpers

    private func saveAndWait(_ service: SlackService) async -> SlackService.SlackStatusSnapshot? {
        await withCheckedContinuation { continuation in
            service.saveCurrentStatus { snapshot in
                continuation.resume(returning: snapshot)
            }
        }
    }

    private func restoreAndWait(_ service: SlackService) async -> Bool {
        await withCheckedContinuation { continuation in
            service.restoreSavedStatus { restored in
                continuation.resume(returning: restored)
            }
        }
    }
}

/// Test-only bridge: `setStatus`'s completion is optional but async tests want
/// to await it. Avoids duplicating the call in every test.
extension SlackService {
    @MainActor
    func setStatusForTest(text: String, expirationTimestamp: Int) async {
        await withCheckedContinuation { continuation in
            setStatus(text: text, expirationTimestamp: expirationTimestamp) { _ in
                continuation.resume()
            }
        }
    }
}
