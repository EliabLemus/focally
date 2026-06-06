import Foundation
import Combine
import os.log

class SlackService: ObservableObject {
    static let defaultStatusEmoji = ":hourglass_flowing_sand:"
    static let statusEmojiDefaultsKey = "slackStatusEmoji"
    static let emojiListURL = URL(string: "https://slack.com/api/emoji.list")!

    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "slackEnabled")
            if isEnabled && token != nil {
                refreshEmojiCatalogIfPossible()
            }
        }
    }
    @Published var isConnected: Bool = false
    @Published var connectionError: String?
    @Published var lastStatusText: String?
    @Published var workspaceEmojiCodes: [String] = []
    @Published var lastActionMessage: String?

    private let keychainKey = "slack-token"
    private let logger = Logger.slack
    private let profileSetURL = URL(string: "https://slack.com/api/users.profile.set")!
    private let authTestURL = URL(string: "https://slack.com/api/auth.test")!
    private let endDndURL = URL(string: "https://slack.com/api/dnd.endSnooze")!
    private let dndSetSnoozeURL = URL(string: "https://slack.com/api/dnd.setSnooze")!

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
        let rawValue: String = UserDefaults.standard.string(forKey: Self.statusEmojiDefaultsKey) ?? Self.defaultStatusEmoji
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultStatusEmoji : trimmed
    }

    func disableSlackDND() {
        let maskedToken = maskedToken(token)
        logger.info("disableSlackDND called. isEnabled=\(self.isEnabled), token=\(maskedToken)")
        guard isEnabled else {
            logger.info("Skipping disableSlackDND because Slack integration is disabled")
            return
        }
        guard let token else {
            logger.error("Skipping disableSlackDND because no Slack token is configured")
            connectionError = "No Slack token configured"
            isConnected = false
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
                    let errorType = SlackService.categorizeNetworkError(error)
                    self?.connectionError = errorType
                    self?.lastActionMessage = "Slack DND request failed"
                    self?.logger.error("Slack disableSlackDND request failed: \(error.localizedDescription), categorized as: \(errorType)")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard let json = self?.decodeSlackResponseBody(data) else {
                    self?.connectionError = "Invalid response from Slack"
                    self?.lastActionMessage = "Slack DND request failed"
                    self?.isConnected = false
                    return
                }

                let responseOK: Bool = json["ok"] as? Bool ?? false
                if responseOK && (200...299).contains(statusCode) {
                    self?.connectionError = nil
                    self?.lastActionMessage = "Slack DND disabled"
                } else {
                    let errorMsg: String = json["error"] as? String ?? "Unknown error"
                    let userFriendlyError = SlackService.userFriendlyError(for: statusCode, slackError: errorMsg)
                    self?.connectionError = userFriendlyError
                    self?.lastActionMessage = "Slack DND request failed"
                    self?.isConnected = false
                    self?.logger.error("Slack disableSlackDND failed. httpStatus=\(statusCode), error=\(errorMsg), userMessage=\(userFriendlyError)")
                }
            }
        }
    }

    func setSlackFocusStatus(text: String = "In focus", emoji: String = "🎯", expirationTimestamp: Int? = nil) {
        let maskedToken = maskedToken(token)
        logger.info(
            "setSlackFocusStatus called. isEnabled=\(self.isEnabled), " +
                "token=\(maskedToken), text=\(text), " +
                "emoji=\(emoji), workspaceEmojisLoaded=\(self.workspaceEmojiCodes.count)"
        )
        guard isEnabled else {
            logger.info("Skipping setSlackFocusStatus because Slack integration is disabled")
            return
        }
        guard let token else {
            logger.error("Skipping setSlackFocusStatus because no Slack token is configured")
            connectionError = "No Slack token configured"
            isConnected = false
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
                    let errorType = SlackService.categorizeNetworkError(error)
                    self?.connectionError = errorType
                    self?.lastActionMessage = "Slack status request failed"
                    self?.isConnected = false
                    self?.logger.error("Slack setSlackFocusStatus request failed: \(error.localizedDescription), categorized as: \(errorType)")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard let json = self?.decodeSlackResponseBody(data) else {
                    self?.connectionError = "Invalid response from Slack"
                    self?.lastActionMessage = "Slack status request failed"
                    self?.isConnected = false
                    return
                }

                let responseOK: Bool = json["ok"] as? Bool ?? false
                if responseOK && (200...299).contains(statusCode) {
                    self?.isConnected = true
                    self?.connectionError = nil
                    self?.lastStatusText = text
                    self?.lastActionMessage = "Slack focus status updated"
                } else {
                    let errorMsg: String = json["error"] as? String ?? "Unknown error"
                    let userFriendlyError = SlackService.userFriendlyError(for: statusCode, slackError: errorMsg)
                    self?.connectionError = userFriendlyError
                    self?.lastActionMessage = "Slack status request failed"
                    self?.isConnected = false
                    self?.logger.error("Slack setSlackFocusStatus failed. httpStatus=\(statusCode), error=\(errorMsg), userMessage=\(userFriendlyError)")
                }
            }
        }
    }

    func setStatus(text: String, expirationTimestamp: Int, taskEmoji: String? = nil, fallbackEmoji: String? = nil) {
        let maskedToken = maskedToken(token)
        logger.info("setStatus called. isEnabled=\(self.isEnabled), token=\(maskedToken), text=\(text), taskEmoji=\(taskEmoji ?? "nil"), fallbackEmoji=\(fallbackEmoji ?? "nil"), expirationTimestamp=\(expirationTimestamp)")
        guard isEnabled else {
            logger.info("Skipping setStatus because Slack integration is disabled")
            return
        }
        guard let token else {
            logger.error("Skipping setStatus because no Slack token is configured")
            connectionError = "No Slack token configured"
            isConnected = false
            return
        }
        let statusEmoji = normalizedStatusEmoji(in: text, taskEmoji: taskEmoji, fallbackEmoji: fallbackEmoji)

        // Registrar uso del emoji (async para evitar conflicto con @MainActor)
        Task { @MainActor in
            EmojiUsageTracker.shared.recordUsage(statusEmoji)
        }

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
                    let errorType = SlackService.categorizeNetworkError(error)
                    self?.connectionError = errorType
                    self?.isConnected = false
                    self?.logger.error("Slack setStatus request failed: \(error.localizedDescription), categorized as: \(errorType)")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                self?.logger.info("Slack setStatus HTTP status code: \(statusCode)")

                guard let json = self?.decodeSlackResponseBody(data) else {
                    self?.connectionError = "Invalid response from Slack"
                    self?.isConnected = false
                    return
                }

                let responseOK: Bool = json["ok"] as? Bool ?? false
                if responseOK && (200...299).contains(statusCode) {
                    self?.isConnected = true
                    self?.connectionError = nil
                    self?.lastStatusText = text
                    self?.logger.info("Slack status set successfully: \(statusEmoji) \(text)")
                } else {
                    let errorMsg: String = json["error"] as? String ?? "Unknown error"
                    let userFriendlyError = SlackService.userFriendlyError(for: statusCode, slackError: errorMsg)
                    self?.connectionError = userFriendlyError
                    self?.isConnected = false
                    self?.logger.error("Slack setStatus failed. httpStatus=\(statusCode), error=\(errorMsg), userMessage=\(userFriendlyError)")
                }
            }
        }
    }

    func clearStatus() {
        let maskedToken = maskedToken(token)
        logger.info("clearStatus called. isEnabled=\(self.isEnabled), token=\(maskedToken)")
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
                    self?.logger.error("Slack clearStatus request failed: \(error.localizedDescription)")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                self?.logger.info("Slack clearStatus HTTP status code: \(statusCode)")

                guard let json = self?.decodeSlackResponseBody(data) else {
                    return
                }

                let responseOK: Bool = json["ok"] as? Bool ?? false
                if responseOK {
                    self?.lastStatusText = nil
                    self?.logger.info("Slack status cleared")
                } else {
                    let errorMsg: String = json["error"] as? String ?? "Unknown error"
                    self?.logger.error("Slack clearStatus failed. httpStatus=\(statusCode), error=\(errorMsg)")
                }
            }
        }
    }

    func testConnection() {
        logger.info("testConnection called. isEnabled=\(self.isEnabled), token=\(self.maskedToken(self.token))")
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
        if let savedToken = token, !savedToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Don't auto-test, just mark as potentially connected
            self.isConnected = true
            // Auto-enable if disabled but token exists
            if !self.isEnabled {
                logger.info("Auto-enabling Slack: token exists but was disabled")
                self.isEnabled = true
            }
            // Delay emoji catalog refresh to avoid blocking init
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.refreshEmojiCatalogIfPossible()
            }
        }
    }

    func refreshEmojiCatalogIfPossible() {
        guard let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.info("Skipping emoji catalog refresh: no token available")
            workspaceEmojiCodes = []
            return
        }

        logger.info("Refreshing Slack emoji catalog (enabled=\(self.isEnabled), token length=\(token.count))...")

        guard let request = makeSlackRequest(url: Self.emojiListURL, token: token, formFields: [:]) else {
            logger.error("Failed to prepare Slack emoji.list request")
            DispatchQueue.main.async {
                self.connectionError = "Failed to prepare emoji catalog request"
            }
            return
        }

        performSlackRequest(request) { [weak self] data, _, error in
            guard let self else { return }

            if let error {
                let errorType = SlackService.categorizeNetworkError(error)
                self.logger.error("Slack emoji.list request failed: \(error.localizedDescription), categorized as: \(errorType)")
                DispatchQueue.main.async {
                    self.connectionError = errorType
                }
                return
            }

            guard let json = self.decodeSlackResponseBody(data) else {
                self.logger.error("Slack emoji.list failed to decode response")
                DispatchQueue.main.async {
                    self.connectionError = "Emoji catalog: failed to decode response"
                }
                return
            }

            guard let responseOK = json["ok"] as? Bool, responseOK else {
                let errorDetail: String = json["error"] as? String ?? "Unknown error"
                let statusCode = 200 // Assuming 200 since we got a response
                let userFriendlyError = SlackService.userFriendlyError(for: statusCode, slackError: errorDetail)
                self.logger.error("Slack emoji.list returned not ok: \(errorDetail), userMessage: \(userFriendlyError)")
                DispatchQueue.main.async {
                    self.connectionError = userFriendlyError
                }
                return
            }

            guard let emojiMap = json["emoji"] as? [String: String] else {
                self.logger.error("Slack emoji.list missing emoji field")
                DispatchQueue.main.async {
                    self.connectionError = "Emoji catalog response missing emoji field"
                }
                return
            }

            let codes = emojiMap.keys
                .map { ":\($0):" }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

            DispatchQueue.main.async {
                self.workspaceEmojiCodes = codes
                self.connectionError = nil
                self.logger.info("Loaded \(codes.count) Slack workspace emojis successfully")
            }
        }
    }

    /// Valida si un emoji existe en el workspace de Slack
    /// - Parameter emoji: Emoji unicode o shortcode a validar
    /// - Returns: true si es válido, false si no
    func validateEmoji(_ emoji: String) -> Bool {
        return EmojiValidator.isValidForSlack(emoji, workspaceEmojis: workspaceEmojiCodes)
    }

    /// Pausa las notificaciones de Slack por X minutos (DND de Slack)
    /// - Parameter minutes: Duración en minutos para pausar notificaciones
    func setSlackDNDSnooze(minutes: Int) {
        guard self.isEnabled else {
            logger.warning("Skipping setSlackDNDSnooze: Slack is disabled (isEnabled=\(self.isEnabled))")
            return
        }
        
        guard let token = self.token, !token.isEmpty else {
            logger.warning("Skipping setSlackDNDSnooze: No token available")
            connectionError = "No Slack token configured"
            isConnected = false
            return
        }

        let numMinutes = max(1, minutes)
        logger.info("Setting Slack DND snooze for \(numMinutes) minutes (token length: \(token.count))")

        guard let request = makeSlackRequest(url: dndSetSnoozeURL, token: token, formFields: [
            "num_minutes": "\(numMinutes)"
        ]) else {
            connectionError = "Failed to prepare Slack DND snooze request"
            isConnected = false
            return
        }

        performSlackRequest(request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    let errorType = SlackService.categorizeNetworkError(error)
                    self?.connectionError = errorType
                    self?.lastActionMessage = "Slack DND snooze failed"
                    self?.isConnected = false
                    self?.logger.error("Slack setSlackDNDSnooze request failed: \(error.localizedDescription), categorized as: \(errorType)")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard let json = self?.decodeSlackResponseBody(data) else {
                    self?.connectionError = "Invalid response from Slack"
                    self?.lastActionMessage = "Slack DND snooze failed"
                    self?.isConnected = false
                    return
                }

                let responseOK: Bool = json["ok"] as? Bool ?? false
                if responseOK && (200...299).contains(statusCode) {
                    self?.connectionError = nil
                    self?.lastActionMessage = "Slack notifications paused"
                    self?.logger.info("Slack DND snooze set successfully for \(numMinutes) minutes")
                } else {
                    let errorMsg: String = json["error"] as? String ?? "Unknown error"
                    let userFriendlyError = SlackService.userFriendlyError(for: statusCode, slackError: errorMsg)
                    self?.connectionError = userFriendlyError
                    self?.lastActionMessage = "Slack DND snooze failed: \(userFriendlyError)"
                    self?.isConnected = false
                    self?.logger.error("Slack setSlackDNDSnooze failed. httpStatus=\(statusCode), error=\(errorMsg), userMessage=\(userFriendlyError)")
                }
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

        logger.info("validateToken called. token=\(self.maskedToken(token))")

        guard let request = makeSlackRequest(url: authTestURL, token: token, formFields: [:]) else {
            connectionError = "Failed to prepare Slack auth.test request"
            isConnected = false
            return
        }

        performSlackRequest(request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    let errorType = SlackService.categorizeNetworkError(error)
                    self?.connectionError = errorType
                    self?.isConnected = false
                    self?.logger.error("Slack auth.test request failed: \(error.localizedDescription), categorized as: \(errorType)")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                self?.logger.info("Slack auth.test HTTP status code: \(statusCode)")

                guard let json = self?.decodeSlackResponseBody(data) else {
                    self?.connectionError = "Invalid response from Slack"
                    self?.isConnected = false
                    return
                }

                let responseOK: Bool = json["ok"] as? Bool ?? false
                if responseOK && (200...299).contains(statusCode) {
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
                    let errorMsg: String = json["error"] as? String ?? "Unknown error"
                    let userFriendlyError = SlackService.userFriendlyError(for: statusCode, slackError: errorMsg)
                    self?.connectionError = userFriendlyError
                    self?.isConnected = false
                    self?.logger.error("Slack auth.test failed. httpStatus=\(statusCode), error=\(errorMsg), userMessage=\(userFriendlyError)")
                }
            }
        }
    }

    private func normalizedStatusEmoji(in text: String, taskEmoji: String?, fallbackEmoji: String?) -> String {
        if let inlineEmoji = firstEmoji(in: text) {
            return normalizeEmojiForSlack(inlineEmoji)
        }

        let taskValue: String = taskEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !taskValue.isEmpty {
            return normalizeEmojiForSlack(taskValue)
        }

        let fallbackValue: String = fallbackEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fallbackValue.isEmpty {
            return normalizeEmojiForSlack(fallbackValue)
        }

        return normalizeEmojiForSlack(savedStatusEmoji())
    }

    private func normalizeEmojiForSlack(_ emoji: String) -> String {
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return savedStatusEmoji() }
        if EmojiValidator.isSlackShortcode(trimmed) {
            return trimmed
        }
        if let shortcode = EmojiValidator.convertUnicodeToShortcode(trimmed, workspaceEmojis: workspaceEmojiCodes) {
            return shortcode
        }
        return trimmed
    }

    private func firstEmoji(in text: String) -> String? {
        if let shortcode = firstSlackEmojiCode(in: text) {
            return shortcode
        }

        for character in text where isEmoji(character) {
            return String(character)
        }

        return nil
    }

    private func firstSlackEmojiCode(in text: String) -> String? {
        let pattern: String = #":[a-z0-9_+\-]+:"#
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
        logger.info("Slack request URL: \(request.url?.absoluteString ?? "nil")")
        logger.info("Slack request headers: \(self.maskedHeaders(for: request))")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.info("Slack request body: \(bodyString)")
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody: String = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            self?.logger.info("Slack response status: \(statusCode)")
            self?.logger.info("Slack response body: \(responseBody)")
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

    // MARK: - Error Helpers

    /// Categoriza errores de red en mensajes amigables
    private static func categorizeNetworkError(_ error: Error) -> String {
        let nsError = error as NSError

        // Network unavailable
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNotConnectedToInternet {
            return "No internet connection"
        }

        // Timeout
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
            return "Network request timed out"
        }

        // Connection refused
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCannotConnectToHost {
            return "Cannot connect to Slack server"
        }

        // DNS lookup failed
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCannotFindHost {
            return "Cannot find Slack server"
        }

        // Generic network error
        if nsError.domain == NSURLErrorDomain {
            return "Network error: \(error.localizedDescription)"
        }

        return error.localizedDescription
    }

    /// Convierte errores de Slack en mensajes amigables para el usuario
    private static func userFriendlyError(for statusCode: Int, slackError: String) -> String {
        // HTTP 401: Invalid token
        if statusCode == 401 || slackError == "invalid_auth" {
            return "Invalid Slack token. Please check your token and try again."
        }

        // HTTP 403: Forbidden
        if statusCode == 403 || slackError == "not_authed" {
            return "Access denied. Your token may not have the required permissions."
        }

        // HTTP 429: Rate limited
        if statusCode == 429 || slackError == "rate_limited" {
            return "Too many requests. Please wait a moment and try again."
        }

        // Permission errors
        if slackError == "missing_scope" {
            return "Your token is missing required permissions."
        }

        // Account errors
        if slackError == "account_inactive" {
            return "Your Slack account is inactive."
        }

        if slackError == "token_revoked" {
            return "Your Slack token has been revoked."
        }

        if slackError == "org_login_required" {
            return "Your Slack workspace requires login."
        }

        // Generic errors
        return "Slack API error: \(slackError)"
    }
}

// MARK: - Emoji Validator

/// Valida y convierte emojis entre formatos (unicode ↔ Slack shortcode)
public struct EmojiValidator {
    /// Valida si un emoji es válido para Slack
    /// - Parameter emoji: String con emoji unicode o :shortcode:
    /// - Returns: true si es válido, false si no
    public static func isValidForSlack(_ emoji: String, workspaceEmojis: [String]) -> Bool {
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Si es shortcode, verificar si existe en workspace
        if isSlackShortcode(trimmed) {
            return workspaceEmojis.contains(trimmed)
        }

        // Si es unicode, siempre válido para UI (Slack mostrará ? si no existe)
        return true
    }

    /// Intenta convertir un emoji unicode a shortcode del workspace
    /// - Parameters:
    ///   - emoji: Emoji unicode
    ///   - workspaceEmojis: Lista de shortcodes del workspace
    /// - Returns: Shortcode si encuentra match cercano, nil si no
    public static func convertUnicodeToShortcode(_ emoji: String, workspaceEmojis: [String]) -> String? {
        // Primero: match exacto por nombre del emoji (si tuviéramos metadata)
        // Por ahora: heurística simple basada en categorías comunes

        let emojiMap: [String: String] = [
            "🧠": ":brain:",
            "💻": ":computer:",
            "📝": ":memo:",
            "📚": ":books:",
            "🎯": ":dart:",
            "⚡️": ":zap:",
            "☕️": ":coffee:",
            "🍅": ":tomato:"
        ]

        // Buscar match exacto en map
        if let shortcode = emojiMap[emoji], workspaceEmojis.contains(shortcode) {
            return shortcode
        }

        // Buscar en workspace por similitud de nombre
        // (esto requeriría metadata de Slack API que incluye nombres)
        // Por ahora, intentamos match directo si el shortcode tiene formato :emoji:
        let potentialShortcode: String = ":\(emojiName(emoji)):"
        if workspaceEmojis.contains(potentialShortcode) {
            return potentialShortcode
        }

        return nil
    }

    /// Intenta convertir un shortcode de Slack a emoji unicode
    /// - Parameters:
    ///   - shortcode: Shortcode de Slack (ej. :brain:)
    ///   - workspaceEmojis: Lista de shortcodes del workspace (para validación)
    /// - Returns: Emoji unicode si es conocido, nil si no
    public static func convertShortcodeToUnicode(_ shortcode: String, workspaceEmojis: [String]) -> String? {
        // Validar formato de shortcode
        guard isSlackShortcode(shortcode) else { return nil }

        // Map inverso de shortcodes conocidos a unicode
        let shortcodeMap: [String: String] = [
            // Standard Slack emojis (official names)
            ":brain:": "🧠",
            ":computer:": "💻",
            ":memo:": "📝",
            ":books:": "📚",
            ":dart:": "🎯",
            ":zap:": "⚡",
            ":tomato:": "🍅",
            ":hourglass_flowing_sand:": "⏳",
            ":star:": "⭐",
            ":fire:": "🔥",
            ":rocket:": "🚀",
            ":check:": "✅",
            ":white_check_mark:": "✅",
            ":heavy_check_mark:": "✅",
            ":x:": "❌",
            ":heavy_multiplication_x:": "❌",

            // Focally custom shortcodes (from FocusStatusOption.common)
            ":deep_work:": "🧠",
            ":coding:": "💻",
            ":writing:": "📝",
            ":reading:": "📚",
            ":priority:": "🎯",
            ":sprint:": "⚡️",
            ":quiet:": "🔕",
            ":coffee:": "☕️",
            ":pomodoro:": "🍅"
        ]

        // Buscar match exacto en map
        if let emoji = shortcodeMap[shortcode] {
            return emoji
        }

        // Intentar extraer el nombre y buscar en un map extendido
        let name = shortcode.dropFirst().dropLast().lowercased()
        let commonEmojis: [String: String] = [
            "smile": "😊",
            "thumbsup": "👍",
            "thumbs_up": "👍",
            "heart": "❤️",
            "plus": "➕",
            "warning": "⚠️",
            "information_source": "ℹ️"
        ]

        if let emoji = commonEmojis[name] {
            return emoji
        }

        // Si el shortcode está en el workspace pero no lo conocemos, devolver nil
        // (la UI mostrará el shortcode como fallback)
        return nil
    }

    /// Verifica si un string es un shortcode de Slack
    public static func isSlackShortcode(_ value: String) -> Bool {
        value.hasPrefix(":") && value.hasSuffix(":") && value.count > 2
    }

    /// Extrae el nombre base de un emoji unicode (simplificado)
    private static func emojiName(_ emoji: String) -> String {
        // Map simplificado de emojis comunes a nombres
        let names: [String: String] = [
            "🧠": "brain",
            "💻": "computer",
            "📝": "pencil",
            "📚": "books",
            "🎯": "dart",
            "⚡": "zap",
            "☕": "coffee",
            "🍅": "tomato"
        ]
        return names[emoji] ?? "simple_smile"
    }
}

// MARK: - Emoji Usage Tracker

/// Rastrea el uso de emojis para mostrar sugerencias de recientes
@MainActor
public final class EmojiUsageTracker: ObservableObject {
    public static let shared = EmojiUsageTracker()

    private static let maxRecentCount = 12
    private static let usageKey = "emojiUsageHistory"

    @Published private(set) public var recentEmojis: [String] = []

    private let defaults = UserDefaults.standard

    private init() {
        loadRecentEmojis()
    }

    /// Registra el uso de un emoji
    public func recordUsage(_ emoji: String) {
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Mover al inicio si ya existe, o agregar al inicio
        recentEmojis.removeAll { $0 == trimmed }
        recentEmojis.insert(trimmed, at: 0)

        // Limitar tamaño
        if recentEmojis.count > Self.maxRecentCount {
            recentEmojis = Array(recentEmojis.prefix(Self.maxRecentCount))
        }

        saveRecentEmojis()
    }

    /// Obtiene los emojis recientes, filtrando por workspace si está disponible
    public func getRecentEmojis(forWorkspace workspaceEmojis: [String]? = nil) -> [String] {
        guard let workspaceEmojis = workspaceEmojis else {
            return recentEmojis
        }

        // Filtrar para mostrar solo emojis válidos en el workspace
        return recentEmojis.filter { emoji in
            if EmojiValidator.isSlackShortcode(emoji) {
                return workspaceEmojis.contains(emoji)
            }
            return true
        }
    }

    private func loadRecentEmojis() {
        if let data = defaults.data(forKey: Self.usageKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            recentEmojis = decoded
        }
    }

    private func saveRecentEmojis() {
        if let encoded = try? JSONEncoder().encode(recentEmojis) {
            defaults.set(encoded, forKey: Self.usageKey)
        }
    }
}
