import Foundation
import os.log

/// Cliente HTTP de la API de Slack con rate limiting **por método** (TASK-059).
///
/// - Respeta 429 + header `Retry-After` en TODAS las rutas: cuando un método recibe 429,
///   queda bloqueado hasta el deadline y las llamadas subsecuentes a ese mismo método
///   no salen a la red hasta que expire (las demás rutas no se ven afectadas).
/// - La ruta async (`performAsync`) hace un único reintento automático tras el deadline.
/// - La gateway callback (`perform`) conserva la semántica de `performSlackRequest`
///   (una sola llamada al completion, sin reintento automático); los callers que ya
///   implementan su propia puerta (p. ej. el refresh del catálogo de emojis) no cambian.
final class SlackAPIClient {
    typealias Transport = (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> Void

    struct SlackAPIResponse {
        let http: HTTPURLResponse
        let data: Data
        let json: [String: Any]
    }

    static let defaultRetryAfter: TimeInterval = 60

    private let transport: Transport
    private let logger = Logger.slack
    private let now: () -> Date
    /// Dormidero inyectable para que los tests no esperen el Retry-After real.
    private let sleep: (TimeInterval) async throws -> Void
    private let lock = NSLock()
    private var blockedUntilByMethod: [String: Date] = [:]

    // MARK: - Init

    init(
        session: URLSession = .shared,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (TimeInterval) async throws -> Void = { interval in
            try await Task.sleep(nanoseconds: UInt64(max(0, interval) * 1_000_000_000))
        }
    ) {
        self.transport = { request, completion in
            session.dataTask(with: request) { data, response, error in
                completion(data, response, error)
            }.resume()
        }
        self.now = now
        self.sleep = sleep
    }

    /// Inyección de transporte para tests (mismo contrato que `SlackService.RequestPerformer`).
    init(
        transport: @escaping Transport,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (TimeInterval) async throws -> Void = { interval in
            try await Task.sleep(nanoseconds: UInt64(max(0, interval) * 1_000_000_000))
        }
    ) {
        self.transport = transport
        self.now = now
        self.sleep = sleep
    }

    convenience init(requestPerformer: @escaping Transport, now: @escaping () -> Date = Date.init) {
        self.init(transport: requestPerformer, now: now)
    }

    // MARK: - Rate limiting por método

    /// Clave de método para el gate: la ruta de la API (p. ej. "/api/emoji.list").
    static func methodKey(for url: URL?) -> String {
        guard let url else { return "unknown" }
        return url.path.isEmpty ? url.absoluteString : url.path
    }

    /// Deadline de bloqueo vigente para un método, si lo hay.
    func blockedUntil(method: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return blockedUntilByMethod[method]
    }

    func isBlocked(method: String) -> Bool {
        guard let blockedUntil = blockedUntil(method: method) else { return false }
        return blockedUntil > now()
    }

    /// Registra el deadline tras un 429 con `Retry-After`.
    func recordRateLimit(method: String, retryAfter: TimeInterval) {
        let deadline = now().addingTimeInterval(max(1, retryAfter))
        lock.lock()
        blockedUntilByMethod[method] = deadline
        lock.unlock()
        logger.warning("Slack method \(method) rate limited; honoring Retry-After=\(retryAfter) seconds")
    }

    /// Limpia todos los bloqueos (p. ej. al cambiar de token).
    func clearRateLimits() {
        lock.lock()
        blockedUntilByMethod.removeAll()
        lock.unlock()
    }

    // MARK: - Gateway callback (compatible con los callers existentes)

    /// Gateway callback: logging + gate por método. Exactamente una llamada al completion.
    func perform(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        logger.info("Slack request URL: \(request.url?.absoluteString ?? "nil")")
        logger.info("Slack request headers: \(self.maskedHeaders(for: request))")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.info("Slack request body: \(bodyString)")
        }

        let method = Self.methodKey(for: request.url)
        if let blockedUntil = blockedUntil(method: method), blockedUntil > now() {
            let retryAfter = blockedUntil.timeIntervalSince(now())
            logger.info("Slack request to \(method) skipped: blocked until Retry-After deadline")
            completion(nil, nil, SlackError.rateLimited(retryAfter: retryAfter))
            return
        }

        transport(request) { [weak self] data, response, error in
            guard let self else {
                completion(data, response, error)
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody: String = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            self.logger.info("Slack response status: \(statusCode)")
            self.logger.info("Slack response body: \(responseBody)")

            if statusCode == 429 {
                let retryAfter = TimeInterval((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After") ?? "") ?? Self.defaultRetryAfter
                self.recordRateLimit(method: method, retryAfter: retryAfter)
            }
            completion(data, response, error)
        }
    }

    // MARK: - Transporte async con reintento único tras el deadline

    /// Transporte async: respeta el gate por método y reintenta UNA vez tras el
    /// deadline de `Retry-After` si la respuesta es 429. Lanza `SlackError`.
    func performAsync(_ request: URLRequest) async throws -> SlackAPIResponse {
        let method = Self.methodKey(for: request.url)
        var attemptedRetry = false

        while true {
            if let blockedUntil = blockedUntil(method: method), blockedUntil > now() {
                let wait = max(0.01, blockedUntil.timeIntervalSince(now()))
                logger.info("Slack async request to \(method) waiting \(wait)s for Retry-After deadline")
                try await sleep(wait)
            }

            do {
                return try await performOnce(request, method: method)
            } catch let error as SlackError {
                guard case .rateLimited(let retryAfter) = error, !attemptedRetry else { throw error }
                attemptedRetry = true
                logger.warning("Slack async request to \(method) rate limited; single retry after \(retryAfter) seconds")
                try await sleep(max(0.01, retryAfter))
            }
        }
    }

    private func performOnce(_ request: URLRequest, method: String) async throws -> SlackAPIResponse {
        try await withCheckedThrowingContinuation { continuation in
            perform(request) { data, response, error in
                if let error {
                    continuation.resume(throwing: SlackError.from(error))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    continuation.resume(throwing: SlackError.decoding)
                    return
                }
                if http.statusCode == 429 {
                    let retryAfter = TimeInterval(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? Self.defaultRetryAfter
                    continuation.resume(throwing: SlackError.rateLimited(retryAfter: retryAfter))
                    return
                }
                guard let data,
                      let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                    continuation.resume(throwing: SlackError.decoding)
                    return
                }
                continuation.resume(returning: SlackAPIResponse(http: http, data: data, json: json))
            }
        }
    }

    // MARK: - Logging helpers

    private func maskedHeaders(for request: URLRequest) -> String {
        var headers = request.allHTTPHeaderFields ?? [:]
        if let authorization = headers["Authorization"] {
            headers["Authorization"] = "Bearer \(maskedToken(String(authorization.dropFirst("Bearer ".count))))"
        }
        return headers
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
    }

    private func maskedToken(_ token: String?) -> String {
        guard let token, !token.isEmpty else { return "nil" }
        if token.count <= 8 {
            return String(repeating: "*", count: token.count)
        }
        let prefix = token.prefix(4)
        let suffix = token.suffix(4)
        return "\(prefix)…\(suffix)"
    }
}
