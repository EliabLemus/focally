import Foundation
import Combine
import os.log

class SlackService: ObservableObject {
    static let defaultStatusEmoji = ":hourglass_flowing_sand:"
    static let statusEmojiDefaultsKey = "slackStatusEmoji"
    static let emojiListURL = URL(string: "https://slack.com/api/emoji.list")!

    @Published var isEnabled = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "slackEnabled")
        }
    }
    @Published var isConnected = false
    @Published var connectionError: String?
    @Published var lastStatusText: String?
    @Published var workspaceEmojiCodes: [String] = []
    @Published var lastActionMessage: String?

    private let keychainKey = "slack-token"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "SlackService")
    private let profileSetURL = URL(string: "https://slack.com/api/users.profile.set")!
    private let authTestURL = URL(string: "https://slack.com/api/auth.test")!
    private let endDndURL = URL(string: "https://slack.com/api/dnd.endDnd")!

    var token: String? {
        get { KeychainHelper.load(key: keychainKey) }
        set {
            if let value = newValue {
                KeychainHelper.save(key: keychainKey, value: value)
            } else {
                KeychainHelper.delete(key: keychainKey)
            }
        }
    }

    // MARK: - Public API

    func savedStatusEmoji() -> String {
        let rawValue = UserDefaults.standard.string(forKey: Self.statusEmojiDefaultsKey) ?? Self.defaultStatusEmoji
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultStatusEmoji : trimmed
    }

    func disableSlackDND() {
        let maskedToken = maskedToken(token)
        logger.info("disableSlackDND called. isEnabled=\(self.isEnabled, privacy: .public), token=\(maskedToken, privacy: .public)")
        guard isEnabled else {
            logger.info("Skipping disableSlackDND because Slack integration is disabled")
            return
        }
        guard let token else {
            logger.error("Skipping disableSlackDND because no Slack token is configured")
            return
        }

        guard let request = makeSlackRequest(url: endDndURL, token: token, formFields: [:]) else {
            connectionError = "Failed to prepare Slack DND request"
            isConnected = false
            return
        }

        performSlackRequest(request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.connectionError = error.localizedDescription
                    self?.lastActionMessage = "Slack DND request failed"
                    self?.logger.error("Slack disableSlackDND request failed: \(error.localizedDescription, privacy: .public)")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard let json = self?.decodeSlackResponseBody(data) else {
                    self?.connectionError = "Invalid response from Slack"
                    self?.lastActionMessage = "Slack DND request failed"
                    self?.isConnected = false
                    return
                }

                let ok = json["ok"] as? Bool ?? false
                if ok && (200...299).contains(statusCode) {
                    self?.connectionError = nil
                    self?.lastActionMessage = "Slack DND disabled"
                } else {
                    let errorMsg = json["error"] as? String ?? "Unknown error"
                    self?.connectionError = errorMsg
                    self?.lastActionMessage = "Slack DND request failed"
                    self?.isConnected = false
                    self?.logger.error("Slack disableSlackDND failed. httpStatus=\(statusCode, privacy: .public), error=\(errorMsg, privacy: .public)")
                }
            }
        }
    }

    func setSlackFocusStatus(text: String = "In focus", emoji: String = "🎯", expirationTimestamp: Int? = nil) {
        let maskedToken = maskedToken(token)
        logger.info("setSlackFocusStatus called. isEnabled=\(self.isEnabled, privacy: .public), token=\(maskedToken, privacy: .public), text=\(text, privacy: .public), emoji=\(emoji, privacy: .public)")
        guard isEnabled else {
            logger.info("Skipping setSlackFocusStatus because Slack integration is disabled")
            return
        }
        guard let token else {
            logger.error("Skipping setSlackFocusStatus because no Slack token is configured")
            return
        }

        var profile: [String: String] = [
            "status_text": text,
            "status_emoji": emoji
        ]
        if let expirationTimestamp {
            profile["status_expiration"] = "\(expirationTimestamp)"
        }

        guard let request = makeSlackRequest(url: profileSetURL, token: token, formFields: [
            "profile": encodedJSONString(for: profile)
        ]) else {
            connectionError = "Failed to prepare Slack status request"
            isConnected = false
            return
        }

        performSlackRequest(request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.connectionError = error.localizedDescription
                    self?.lastActionMessage = "Slack status request failed"
                    self?.isConnected = false
                    self?.logger.error("Slack setSlackFocusStatus request failed: \(error.localizedDescription, privacy: .public)")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard let json = self?.decodeSlackResponseBody(data) else {
                    self?.connectionError = "Invalid response from Slack"
                    self?.lastActionMessage = "Slack status request failed"
                    self?.isConnected = false
                    return
                }

                let ok = json["ok"] as? Bool ?? false
                if ok && (200...299).contains(statusCode) {
                    self?.isConnected = true
                    self?.connectionError = nil
                    self?.lastStatusText = text
                    self?.lastActionMessage = "Slack focus status updated"
                } else {
                    let errorMsg = json["error"] as? String ?? "Unknown error"
                    self?.connectionError = errorMsg
                    self?.lastActionMessage = "Slack status request failed"
                    self?.isConnected = false
                    self?.logger.error("Slack setSlackFocusStatus failed. httpStatus=\(statusCode, privacy: .public), error=\(errorMsg, privacy: .public)")
                }
            }
        }
    }

    func setStatus(text: String, expirationTimestamp: Int, taskEmoji: String? = nil, fallbackEmoji: String? = nil) {
        let maskedToken = maskedToken(token)
        logger.info("setStatus called. isEnabled=\(self.isEnabled, privacy: .public), token=\(maskedToken, privacy: .public), text=\(text, privacy: .public), taskEmoji=\(taskEmoji ?? "nil"), fallbackEmoji=\(fallbackEmoji ?? "nil"), expirationTimestamp=\(expirationTimestamp, privacy: .public)")
        guard isEnabled else {
            logger.info("Skipping setStatus because Slack integration is disabled")
            return
        }
        guard let token else {
            logger.error("Skipping setStatus because no Slack token is configured")
            return
        }
        let statusEmoji = normalizedStatusEmoji(in: text, taskEmoji: taskEmoji, fallbackEmoji: fallbackEmoji)

        let profile: [String: String] = [
            "status_text": text,
            "status_emoji": statusEmoji,
            "status_expiration": "\(expirationTimestamp)"
        ]

        guard let request = makeSlackRequest(url: profileSetURL, token: token, formFields: [
            "profile": encodedJSONString(for: profile)
        ]) else {
            connectionError = "Failed to prepare Slack status request"
            isConnected = false
            return
        }

        performSlackRequest(request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.connectionError = error.localizedDescription
                    self?.isConnected = false
                    self?.logger.error("Slack setStatus request failed: \(error.localizedDescription, privacy: .public)")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                self?.logger.info("Slack setStatus HTTP status code: \(statusCode, privacy: .public)")

                guard let json = self?.decodeSlackResponseBody(data) else {
                    self?.connectionError = "Invalid response from Slack"
                    self?.isConnected = false
                    return
                }

                let ok = json["ok"] as? Bool ?? false
                if ok && (200...299).contains(statusCode) {
                    self?.isConnected = true
                    self?.connectionError = nil
                    self?.lastStatusText = text
                    self?.logger.info("Slack status set successfully: \(statusEmoji, privacy: .public) \(text, privacy: .public)")
                } else {
                    let errorMsg = json["error"] as? String ?? "Unknown error"
                    self?.connectionError = errorMsg
                    self?.isConnected = false
                    self?.logger.error("Slack setStatus failed. httpStatus=\(statusCode, privacy: .public), error=\(errorMsg, privacy: .public)")
                }
            }
        }
    }

    func clearStatus() {
        let maskedToken = maskedToken(token)
        logger.info("clearStatus called. isEnabled=\(self.isEnabled, privacy: .public), token=\(maskedToken, privacy: .public)")
        guard isEnabled else {
            logger.info("Skipping clearStatus because Slack integration is disabled")
            return
        }
        guard let token else {
            logger.error("Skipping clearStatus because no Slack token is configured")
            return
        }

        let profile: [String: String] = [
            "status_text": "",
            "status_emoji": ""
        ]

        guard let request = makeSlackRequest(url: profileSetURL, token: token, formFields: [
            "profile": encodedJSONString(for: profile)
        ]) else {
            logger.error("Failed to prepare Slack clearStatus request")
            return
        }

        performSlackRequest(request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.logger.error("Slack clearStatus request failed: \(error.localizedDescription, privacy: .public)")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                self?.logger.info("Slack clearStatus HTTP status code: \(statusCode, privacy: .public)")

                guard let json = self?.decodeSlackResponseBody(data) else {
                    return
                }

                let ok = json["ok"] as? Bool ?? false
                if ok {
                    self?.lastStatusText = nil
                    self?.logger.info("Slack status cleared")
                } else {
                    let errorMsg = json["error"] as? String ?? "Unknown error"
                    self?.logger.error("Slack clearStatus failed. httpStatus=\(statusCode, privacy: .public), error=\(errorMsg, privacy: .public)")
                }
            }
        }
    }

    func testConnection() {
        logger.info("testConnection called. isEnabled=\(self.isEnabled, privacy: .public), token=\(self.maskedToken(self.token), privacy: .public)")
        guard token != nil else {
            connectionError = "No token configured"
            isConnected = false
            logger.error("Slack testConnection failed because no token is configured")
            return
        }

        validateToken()
    }

    // MARK: - Init

    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "slackEnabled")
        // Try to load saved token
        if token != nil {
            // Don't auto-test, just mark as potentially connected
            self.isConnected = true
            refreshEmojiCatalogIfPossible()
        }
    }

    func refreshEmojiCatalogIfPossible() {
        guard let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            workspaceEmojiCodes = []
            return
        }

        guard let request = makeSlackRequest(url: Self.emojiListURL, token: token, formFields: [:]) else {
            return
        }

        performSlackRequest(request) { [weak self] data, _, error in
            guard let self else { return }

            if let error {
                self.logger.error("Slack emoji.list request failed: \(error.localizedDescription, privacy: .public)")
                return
            }

            guard let json = self.decodeSlackResponseBody(data),
                  let ok = json["ok"] as? Bool,
                  ok,
                  let emojiMap = json["emoji"] as? [String: String] else {
                return
            }

            let codes = emojiMap.keys
                .map { ":\($0):" }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

            DispatchQueue.main.async {
                self.workspaceEmojiCodes = codes
            }
        }
    }

    func validateToken() {
        guard let token else {
            connectionError = "No token configured"
            isConnected = false
            logger.error("validateToken called without a token")
            return
        }

        logger.info("validateToken called. token=\(self.maskedToken(token), privacy: .public)")

        guard let request = makeSlackRequest(url: authTestURL, token: token, formFields: [:]) else {
            connectionError = "Failed to prepare Slack auth.test request"
            isConnected = false
            return
        }

        performSlackRequest(request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.connectionError = error.localizedDescription
                    self?.isConnected = false
                    self?.logger.error("Slack auth.test request failed: \(error.localizedDescription, privacy: .public)")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                self?.logger.info("Slack auth.test HTTP status code: \(statusCode, privacy: .public)")

                guard let json = self?.decodeSlackResponseBody(data) else {
                    self?.connectionError = "Invalid response from Slack"
                    self?.isConnected = false
                    return
                }

                let ok = json["ok"] as? Bool ?? false
                if ok && (200...299).contains(statusCode) {
                    if token.hasPrefix("xoxp-") {
                        self?.isConnected = true
                        self?.connectionError = nil
                        self?.refreshEmojiCatalogIfPossible()
                        self?.logger.info("Slack auth.test succeeded for a user token")
                    } else {
                        self?.isConnected = false
                        self?.connectionError = "Slack status updates require a user token (xoxp-) with users.profile:write"
                        self?.logger.error("Slack auth.test succeeded but token type is not a user token")
                    }
                } else {
                    let errorMsg = json["error"] as? String ?? "Unknown error"
                    self?.connectionError = errorMsg
                    self?.isConnected = false
                    self?.logger.error("Slack auth.test failed. httpStatus=\(statusCode, privacy: .public), error=\(errorMsg, privacy: .public)")
                }
            }
        }
    }

    private func normalizedStatusEmoji(in text: String, taskEmoji: String?, fallbackEmoji: String?) -> String {
        if let inlineEmoji = firstEmoji(in: text) {
            return inlineEmoji
        }

        let taskValue = taskEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !taskValue.isEmpty {
            return taskValue
        }

        let fallbackValue = fallbackEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fallbackValue.isEmpty {
            return fallbackValue
        }

        return savedStatusEmoji()
    }

    private func firstEmoji(in text: String) -> String? {
        if let shortcode = firstSlackEmojiCode(in: text) {
            return shortcode
        }

        for character in text {
            if isEmoji(character) {
                return String(character)
            }
        }

        return nil
    }

    private func firstSlackEmojiCode(in text: String) -> String? {
        let pattern = #":\:[a-z0-9_+\-]+:\:"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let matchRange = Range(match.range, in: text) else {
            return nil
        }

        return String(text[matchRange])
    }

    private func isEmoji(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation || scalar.properties.isEmoji
        }
    }

    private func makeSlackRequest(url: URL, token: String, formFields: [String: String]) -> URLRequest? {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = percentEncodedBody(from: formFields)
        return request
    }

    private func performSlackRequest(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        logger.info("Slack request URL: \(request.url?.absoluteString ?? "nil", privacy: .public)")
        logger.info("Slack request headers: \(self.maskedHeaders(for: request), privacy: .public)")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.info("Slack request body: \(bodyString, privacy: .public)")
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            self?.logger.info("Slack response status: \(statusCode, privacy: .public)")
            self?.logger.info("Slack response body: \(responseBody, privacy: .public)")
            completion(data, response, error)
        }.resume()
    }

    private func decodeSlackResponseBody(_ data: Data?) -> [String: Any]? {
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("Failed to decode Slack response body")
            return nil
        }
        return json
    }

    private func encodedJSONString(for object: [String: String]) -> String {
        guard let jsonData = try? JSONEncoder().encode(object),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    private func percentEncodedBody(from formFields: [String: String]) -> Data? {
        guard !formFields.isEmpty else { return Data() }
        let body = formFields
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .joined(separator: "&")
        return body.data(using: .utf8)
    }

    private func percentEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?"))) ?? value
    }

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
