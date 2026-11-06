import Foundation
import Testing
@testable import Focally

// MARK: - URLProtocol mock

/// Mock de transporte para `SlackAPIClient` a nivel URLSession (URLProtocol).
final class MockSlackURLProtocol: URLProtocol {
    struct Stub {
        let statusCode: Int
        let headers: [String: String]
        let json: [String: Any]
        let error: Error?
    }

    static private let lock = NSLock()
    static private var stubsByPath: [String: Stub] = [:]
    static private var countsByPath: [String: Int] = [:]

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        stubsByPath = [:]
        countsByPath = [:]
    }

    static func stub(path: String, statusCode: Int, headers: [String: String] = [:], json: [String: Any] = ["ok": true], error: Error? = nil) {
        lock.lock()
        defer { lock.unlock() }
        stubsByPath[path] = Stub(statusCode: statusCode, headers: headers, json: json, error: error)
    }

    static func requestCount(path: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return countsByPath[path] ?? 0
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockSlackURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        Self.lock.lock()
        Self.countsByPath[path, default: 0] += 1
        let stub = Self.stubsByPath[path]
        Self.lock.unlock()

        if let error = stub?.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let body = try? JSONSerialization.data(withJSONObject: stub?.json ?? ["ok": true])
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub?.statusCode ?? 200,
            httpVersion: "HTTP/1.1",
            headerFields: stub?.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Tests

@Suite("SlackAPIClient", .serialized)
struct SlackAPIClientTests {
    private let emojiListURL = URL(string: "https://slack.com/api/emoji.list")!
    private let authTestURL = URL(string: "https://slack.com/api/auth.test")!

    private func makeClient(now: @escaping () -> Date = Date.init, sleep: @escaping (TimeInterval) async throws -> Void = { _ in }) -> SlackAPIClient {
        SlackAPIClient(
            session: MockSlackURLProtocol.makeSession(),
            now: now,
            sleep: sleep // no esperamos el Retry-After real en tests
        )
    }

    /// Helper: `client.perform` envuelto en async.
    private func perform(_ client: SlackAPIClient, _ request: URLRequest) async -> (Data?, URLResponse?, Error?) {
        await withCheckedContinuation { continuation in
            client.perform(request) { data, response, error in
                continuation.resume(returning: (data, response, error))
            }
        }
    }

    @Test func rateLimitedAsyncRetriesOnceAfterDeadlineAndSucceeds() async throws {
        MockSlackURLProtocol.reset()
        MockSlackURLProtocol.stub(path: "/api/emoji.list", statusCode: 429, headers: ["Retry-After": "2"], json: ["ok": false, "error": "ratelimited"])

        // Reloj fake: el sleeper AVANZA el reloj, simulando que el Retry-After
        // expira de verdad (sin esto el gate sigue bloqueado y el reintento
        // sale por el short-circuit sin request).
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let client = makeClient(now: { fakeNow }, sleep: { interval in
            fakeNow = fakeNow.addingTimeInterval(max(0.01, interval))
        })

        // performAsync: request inicial (429) + 1 reintento tras el deadline →
        // exactamente 2 requests, y .rateLimited propagado (ambos intentos ven 429).
        do {
            _ = try await client.performAsync(URLRequest(url: emojiListURL))
            Issue.record("expected rateLimited error")
        } catch let error as SlackError {
            guard case .rateLimited = error else {
                Issue.record("unexpected error: \(error)")
                return
            }
        }
        #expect(MockSlackURLProtocol.requestCount(path: "/api/emoji.list") == 2)
    }

    @Test func invalidAuthMapsToAuthInvalid() async throws {
        MockSlackURLProtocol.reset()
        MockSlackURLProtocol.stub(path: "/api/auth.test", statusCode: 200, json: ["ok": false, "error": "invalid_auth"])
        let client = makeClient()
        let service = SlackStatusService(client: client)

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<[String: Any], SlackError>, Never>) in
            service.postForm(url: authTestURL, token: "«redacted:xox…»", formFields: [:]) { continuation.resume(returning: $0) }
        }
        guard case .failure(let error) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        guard case .authInvalid = error else {
            Issue.record("Expected .authInvalid, got \(error)")
            return
        }
    }

    @Test func transportTimeoutMapsToNetwork() async throws {
        MockSlackURLProtocol.reset()
        MockSlackURLProtocol.stub(path: "/api/emoji.list", statusCode: 0, error: URLError(.timedOut))
        let client = makeClient()

        do {
            _ = try await client.performAsync(URLRequest(url: emojiListURL))
            Issue.record("Expected throw")
        } catch let error as SlackError {
            guard case .network(let underlying) = error else {
                Issue.record("Expected .network, got \(error)")
                return
            }
            #expect((underlying as? URLError)?.code == .timedOut)
            #expect(error.displayMessage == "Network request timed out")
        }
    }

    @Test func methodGateIsIsolatedPerMethod() async throws {
        MockSlackURLProtocol.reset()
        MockSlackURLProtocol.stub(path: "/api/emoji.list", statusCode: 429, headers: ["Retry-After": "60"], json: ["ok": false, "error": "ratelimited"])
        MockSlackURLProtocol.stub(path: "/api/auth.test", statusCode: 200, json: ["ok": true])
        var now = Date(timeIntervalSince1970: 2_000_000_000)
        let client = makeClient(now: { now })

        // Gateway perform con 429: registra el gate para emoji.list (sin auto-retry).
        let first = await perform(client, URLRequest(url: emojiListURL))
        let firstStatus = (first.1 as? HTTPURLResponse)?.statusCode ?? -1
        #expect(firstStatus == 429)

        #expect(client.isBlocked(method: "/api/emoji.list"))
        #expect(!client.isBlocked(method: "/api/auth.test"))

        // Un request gateway subsecuente a emoji.list NO sale a la red: error .rateLimited.
        let blocked = await perform(client, URLRequest(url: emojiListURL))
        guard case .rateLimited = (blocked.2 as? SlackError) ?? .decoding else {
            Issue.record("Expected .rateLimited from gate, got \(String(describing: blocked.2))")
            return
        }

        // auth.test NO se ve afectado por el bloqueo de emoji.list.
        let authResponse = try await client.performAsync(URLRequest(url: authTestURL))
        #expect(authResponse.http.statusCode == 200)
        #expect(MockSlackURLProtocol.requestCount(path: "/api/emoji.list") == 1)
        #expect(MockSlackURLProtocol.requestCount(path: "/api/auth.test") == 1)

        // Al expirar el deadline, el método vuelve a estar disponible.
        now = now.addingTimeInterval(61)
        #expect(!client.isBlocked(method: "/api/emoji.list"))
    }
}
