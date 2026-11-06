import Foundation

/// Lógica de estado de conexión de Slack (TASK-059): `users.profile.set` y `auth.test`,
/// delegando el transporte y el rate limiting por método en `SlackAPIClient`.
///
/// API callback-based para conservar el comportamiento observable y el timing de los
/// callers existentes; `SlackAPIClient.performAsync` está disponible para migraciones
/// async/await futuras.
final class SlackStatusService {
    struct TokenValidationOutcome {
        let httpStatus: Int
        let ok: Bool
        let slackError: String?
    }

    private let client: SlackAPIClient
    private let logger = Logger.slack

    init(client: SlackAPIClient) {
        self.client = client
    }

    /// POST form-urlencoded contra la API de Slack y decodificación del cuerpo JSON.
    /// Clasifica el resultado en `Result<[String: Any], SlackError>`:
    /// - error de transporte → `.network(underlying:)`
    /// - HTTP 429 → `.rateLimited(retryAfter:)` (el gate ya quedó registrado en el client)
    /// - cuerpo no-JSON → `.decoding`
    /// - `ok: true` + 2xx → `.success(json)`
    /// - resto → `.unknown(statusCode:slackError:)`, incluido `.authInvalid` vía clasificación
    func postForm(
        url: URL,
        token: String,
        formFields: [String: String],
        completion: @escaping (Result<[String: Any], SlackError>) -> Void
    ) {
        guard let request = Self.makeSlackRequest(url: url, token: token, formFields: formFields) else {
            completion(.failure(.unknown(statusCode: -1, slackError: "request_build_failed")))
            return
        }

        client.perform(request) { data, response, error in
            if let error {
                completion(.failure(.network(underlying: error)))
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if statusCode == 429 {
                let retryAfter = TimeInterval((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After") ?? "") ?? SlackAPIClient.defaultRetryAfter
                completion(.failure(.rateLimited(retryAfter: retryAfter)))
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.logger.error("Failed to decode Slack response body")
                completion(.failure(.decoding))
                return
            }

            let responseOK = json["ok"] as? Bool ?? false
            if responseOK && (200...299).contains(statusCode) {
                completion(.success(json))
            } else {
                let slackError = json["error"] as? String ?? "Unknown error"
                if slackError == "invalid_auth" {
                    completion(.failure(.authInvalid))
                } else {
                    completion(.failure(.unknown(statusCode: statusCode, slackError: slackError)))
                }
            }
        }
    }

    /// `users.profile.set` — establece el perfil (status text/emoji/expiration).
    func setProfile(
        profile: [String: String],
        token: String,
        completion: @escaping (Result<Void, SlackError>) -> Void
    ) {
        postForm(url: SlackService.profileSetURL, token: token, formFields: [
            "profile": Self.encodedJSONString(for: profile)
        ]) { result in
            completion(result.map { _ in () })
        }
    }

    /// `auth.test` — valida el token contra la API de Slack.
    func validateToken(
        _ token: String,
        completion: @escaping (Result<TokenValidationOutcome, SlackError>) -> Void
    ) {
        postForm(url: SlackService.authTestURL, token: token, formFields: [:]) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let json):
                let ok = json["ok"] as? Bool ?? false
                completion(.success(TokenValidationOutcome(
                    httpStatus: 200,
                    ok: ok,
                    slackError: ok ? nil : json["error"] as? String ?? "Unknown error"
                )))
            }
        }
    }

    // MARK: - Request building

    static func makeSlackRequest(url: URL, token: String, formFields: [String: String]) -> URLRequest? {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = percentEncodedBody(from: formFields)
        return request
    }

    static func encodedJSONString(for object: [String: String]) -> String {
        guard let jsonData = try? JSONEncoder().encode(object),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    static func percentEncodedBody(from formFields: [String: String]) -> Data? {
        guard !formFields.isEmpty else { return Data() }
        let body = formFields
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .joined(separator: "&")
        return body.data(using: .utf8)
    }

    static func percentEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?"))) ?? value
    }
}
