import Foundation
import Observation
import os.log

@Observable
class SlackService {
    static let defaultStatusEmoji = ":hourglass_flowing_sand:"
    static let statusEmojiDefaultsKey = "slackStatusEmoji"
    static let emojiListURL = URL(string: "https://slack.com/api/emoji.list")!

    var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "slackEnabled")
            if isEnabled && token != nil {
                refreshEmojiCatalogIfPossible()
            }
        }
    }
    var isConnected: Bool = false
    var connectionError: String?
    var lastStatusText: String?
    var workspaceEmojiCodes: [String] = []
    var workspaceEmojiImageURLs: [String: String] = [:]
    var lastActionMessage: String?

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
            workspaceEmojiImageURLs = [:]
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
            let imageURLs = Self.workspaceEmojiImageURLs(from: emojiMap)

            DispatchQueue.main.async {
                self.workspaceEmojiCodes = codes
                self.workspaceEmojiImageURLs = imageURLs
                self.connectionError = nil
                self.logger.info("Loaded \(codes.count) Slack workspace emojis successfully (\(imageURLs.count) image URLs)")
            }
        }
    }

    static func workspaceEmojiImageURLs(from emojiMap: [String: String]) -> [String: String] {
        func resolvedURLString(for emojiName: String, visited: Set<String>) -> String? {
            guard !visited.contains(emojiName), let rawValue = emojiMap[emojiName] else {
                return nil
            }

            if rawValue.hasPrefix("alias:") {
                let aliasedName = String(rawValue.dropFirst("alias:".count))
                return resolvedURLString(for: aliasedName, visited: visited.union([emojiName]))
            }

            guard URL(string: rawValue)?.scheme?.lowercased() == "https" else {
                return nil
            }

            return rawValue
        }

        return emojiMap.reduce(into: [:]) { partialResult, entry in
            guard let urlString = resolvedURLString(for: entry.key, visited: []) else { return }
            partialResult[":\(entry.key):"] = urlString
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
    /// Mapa estático de shortcodes de Slack → emoji unicode (~400 entries).
    /// Usado por convertShortcodeToUnicode y searchShortcodes.
    /// Mapa completo de shortcodes de Slack → emoji unicode (~1900 entries).
    /// Fuente: github/gemoji db/emoji.json (Slack-compatible aliases).
    /// Usado por convertShortcodeToUnicode y searchShortcodes.
    public static let standardShortcodeMap: [String: String] = [
        ":+1:": "👍",
        ":-1:": "👎",
        ":100:": "💯",
        ":1234:": "🔢",
        ":1st_place_medal:": "🥇",
        ":2nd_place_medal:": "🥈",
        ":3rd_place_medal:": "🥉",
        ":8ball:": "🎱",
        ":a:": "🅰️",
        ":ab:": "🆎",
        ":abacus:": "🧮",
        ":abc:": "🔤",
        ":abcd:": "🔡",
        ":accept:": "🉑",
        ":accordion:": "🪗",
        ":adhesive_bandage:": "🩹",
        ":adult:": "🧑",
        ":aerial_tramway:": "🚡",
        ":afghanistan:": "🇦🇫",
        ":airplane:": "✈️",
        ":aland_islands:": "🇦🇽",
        ":alarm_clock:": "⏰",
        ":albania:": "🇦🇱",
        ":alembic:": "⚗️",
        ":algeria:": "🇩🇿",
        ":alien:": "👽",
        ":ambulance:": "🚑",
        ":american_samoa:": "🇦🇸",
        ":amphora:": "🏺",
        ":anatomical_heart:": "🫀",
        ":anchor:": "⚓",
        ":andorra:": "🇦🇩",
        ":angel:": "👼",
        ":anger:": "💢",
        ":angola:": "🇦🇴",
        ":angry:": "😠",
        ":anguilla:": "🇦🇮",
        ":anguished:": "😧",
        ":ant:": "🐜",
        ":antarctica:": "🇦🇶",
        ":antigua_barbuda:": "🇦🇬",
        ":apple:": "🍎",
        ":aquarius:": "♒",
        ":argentina:": "🇦🇷",
        ":aries:": "♈",
        ":armenia:": "🇦🇲",
        ":arrow_backward:": "◀️",
        ":arrow_double_down:": "⏬",
        ":arrow_double_up:": "⏫",
        ":arrow_down:": "⬇️",
        ":arrow_down_small:": "🔽",
        ":arrow_forward:": "▶️",
        ":arrow_heading_down:": "⤵️",
        ":arrow_heading_up:": "⤴️",
        ":arrow_left:": "⬅️",
        ":arrow_lower_left:": "↙️",
        ":arrow_lower_right:": "↘️",
        ":arrow_right:": "➡️",
        ":arrow_right_hook:": "↪️",
        ":arrow_up:": "⬆️",
        ":arrow_up_down:": "↕️",
        ":arrow_up_small:": "🔼",
        ":arrow_upper_left:": "↖️",
        ":arrow_upper_right:": "↗️",
        ":arrows_clockwise:": "🔃",
        ":arrows_counterclockwise:": "🔄",
        ":art:": "🎨",
        ":articulated_lorry:": "🚛",
        ":artificial_satellite:": "🛰️",
        ":artist:": "🧑‍🎨",
        ":aruba:": "🇦🇼",
        ":ascension_island:": "🇦🇨",
        ":asterisk:": "*️⃣",
        ":astonished:": "😲",
        ":astronaut:": "🧑‍🚀",
        ":athletic_shoe:": "👟",
        ":atm:": "🏧",
        ":atom_symbol:": "⚛️",
        ":australia:": "🇦🇺",
        ":austria:": "🇦🇹",
        ":auto_rickshaw:": "🛺",
        ":avocado:": "🥑",
        ":axe:": "🪓",
        ":azerbaijan:": "🇦🇿",
        ":b:": "🅱️",
        ":baby:": "👶",
        ":baby_bottle:": "🍼",
        ":baby_chick:": "🐤",
        ":baby_symbol:": "🚼",
        ":back:": "🔙",
        ":bacon:": "🥓",
        ":badger:": "🦡",
        ":badminton:": "🏸",
        ":bagel:": "🥯",
        ":baggage_claim:": "🛄",
        ":baguette_bread:": "🥖",
        ":bahamas:": "🇧🇸",
        ":bahrain:": "🇧🇭",
        ":balance_scale:": "⚖️",
        ":bald_man:": "👨‍🦲",
        ":bald_woman:": "👩‍🦲",
        ":ballet_shoes:": "🩰",
        ":balloon:": "🎈",
        ":ballot_box:": "🗳️",
        ":ballot_box_with_check:": "☑️",
        ":bamboo:": "🎍",
        ":banana:": "🍌",
        ":bangbang:": "‼️",
        ":bangladesh:": "🇧🇩",
        ":banjo:": "🪕",
        ":bank:": "🏦",
        ":bar_chart:": "📊",
        ":barbados:": "🇧🇧",
        ":barber:": "💈",
        ":baseball:": "⚾",
        ":basket:": "🧺",
        ":basketball:": "🏀",
        ":basketball_man:": "⛹️‍♂️",
        ":basketball_woman:": "⛹️‍♀️",
        ":bat:": "🦇",
        ":bath:": "🛀",
        ":bathtub:": "🛁",
        ":battery:": "🔋",
        ":beach_umbrella:": "🏖️",
        ":beans:": "🫘",
        ":bear:": "🐻",
        ":bearded_person:": "🧔",
        ":beaver:": "🦫",
        ":bed:": "🛏️",
        ":bee:": "🐝",
        ":beer:": "🍺",
        ":beers:": "🍻",
        ":beetle:": "🪲",
        ":beginner:": "🔰",
        ":belarus:": "🇧🇾",
        ":belgium:": "🇧🇪",
        ":belize:": "🇧🇿",
        ":bell:": "🔔",
        ":bell_pepper:": "🫑",
        ":bellhop_bell:": "🛎️",
        ":benin:": "🇧🇯",
        ":bento:": "🍱",
        ":bermuda:": "🇧🇲",
        ":beverage_box:": "🧃",
        ":bhutan:": "🇧🇹",
        ":bicyclist:": "🚴",
        ":bike:": "🚲",
        ":biking_man:": "🚴‍♂️",
        ":biking_woman:": "🚴‍♀️",
        ":bikini:": "👙",
        ":billed_cap:": "🧢",
        ":biohazard:": "☣️",
        ":bird:": "🐦",
        ":birthday:": "🎂",
        ":bison:": "🦬",
        ":biting_lip:": "🫦",
        ":black_bird:": "🐦‍⬛",
        ":black_cat:": "🐈‍⬛",
        ":black_circle:": "⚫",
        ":black_flag:": "🏴",
        ":black_heart:": "🖤",
        ":black_joker:": "🃏",
        ":black_large_square:": "⬛",
        ":black_medium_small_square:": "◾",
        ":black_medium_square:": "◼️",
        ":black_nib:": "✒️",
        ":black_small_square:": "▪️",
        ":black_square_button:": "🔲",
        ":blond_haired_man:": "👱‍♂️",
        ":blond_haired_person:": "👱",
        ":blond_haired_woman:": "👱‍♀️",
        ":blonde_woman:": "👱‍♀️",
        ":blossom:": "🌼",
        ":blowfish:": "🐡",
        ":blue_book:": "📘",
        ":blue_car:": "🚙",
        ":blue_heart:": "💙",
        ":blue_square:": "🟦",
        ":blueberries:": "🫐",
        ":blush:": "😊",
        ":boar:": "🐗",
        ":boat:": "⛵",
        ":bolivia:": "🇧🇴",
        ":bomb:": "💣",
        ":bone:": "🦴",
        ":book:": "📖",
        ":bookmark:": "🔖",
        ":bookmark_tabs:": "📑",
        ":books:": "📚",
        ":boom:": "💥",
        ":boomerang:": "🪃",
        ":boot:": "👢",
        ":bosnia_herzegovina:": "🇧🇦",
        ":botswana:": "🇧🇼",
        ":bouncing_ball_man:": "⛹️‍♂️",
        ":bouncing_ball_person:": "⛹️",
        ":bouncing_ball_woman:": "⛹️‍♀️",
        ":bouquet:": "💐",
        ":bouvet_island:": "🇧🇻",
        ":bow:": "🙇",
        ":bow_and_arrow:": "🏹",
        ":bowing_man:": "🙇‍♂️",
        ":bowing_woman:": "🙇‍♀️",
        ":bowl_with_spoon:": "🥣",
        ":bowling:": "🎳",
        ":boxing_glove:": "🥊",
        ":boy:": "👦",
        ":brain:": "🧠",
        ":brazil:": "🇧🇷",
        ":bread:": "🍞",
        ":breast_feeding:": "🤱",
        ":bricks:": "🧱",
        ":bride_with_veil:": "👰‍♀️",
        ":bridge_at_night:": "🌉",
        ":briefcase:": "💼",
        ":british_indian_ocean_territory:": "🇮🇴",
        ":british_virgin_islands:": "🇻🇬",
        ":broccoli:": "🥦",
        ":broken_heart:": "💔",
        ":broom:": "🧹",
        ":brown_circle:": "🟤",
        ":brown_heart:": "🤎",
        ":brown_square:": "🟫",
        ":brunei:": "🇧🇳",
        ":bubble_tea:": "🧋",
        ":bubbles:": "🫧",
        ":bucket:": "🪣",
        ":bug:": "🐛",
        ":building_construction:": "🏗️",
        ":bulb:": "💡",
        ":bulgaria:": "🇧🇬",
        ":bullettrain_front:": "🚅",
        ":bullettrain_side:": "🚄",
        ":burkina_faso:": "🇧🇫",
        ":burrito:": "🌯",
        ":burundi:": "🇧🇮",
        ":bus:": "🚌",
        ":business_suit_levitating:": "🕴️",
        ":busstop:": "🚏",
        ":bust_in_silhouette:": "👤",
        ":busts_in_silhouette:": "👥",
        ":butter:": "🧈",
        ":butterfly:": "🦋",
        ":cactus:": "🌵",
        ":cake:": "🍰",
        ":calendar:": "📆",
        ":call_me_hand:": "🤙",
        ":calling:": "📲",
        ":cambodia:": "🇰🇭",
        ":camel:": "🐫",
        ":camera:": "📷",
        ":camera_flash:": "📸",
        ":cameroon:": "🇨🇲",
        ":camping:": "🏕️",
        ":canada:": "🇨🇦",
        ":canary_islands:": "🇮🇨",
        ":cancer:": "♋",
        ":candle:": "🕯️",
        ":candy:": "🍬",
        ":canned_food:": "🥫",
        ":canoe:": "🛶",
        ":cape_verde:": "🇨🇻",
        ":capital_abcd:": "🔠",
        ":capricorn:": "♑",
        ":car:": "🚗",
        ":card_file_box:": "🗃️",
        ":card_index:": "📇",
        ":card_index_dividers:": "🗂️",
        ":caribbean_netherlands:": "🇧🇶",
        ":carousel_horse:": "🎠",
        ":carpentry_saw:": "🪚",
        ":carrot:": "🥕",
        ":cartwheeling:": "🤸",
        ":cat2:": "🐈",
        ":cat:": "🐱",
        ":cayman_islands:": "🇰🇾",
        ":cd:": "💿",
        ":central_african_republic:": "🇨🇫",
        ":ceuta_melilla:": "🇪🇦",
        ":chad:": "🇹🇩",
        ":chains:": "⛓️",
        ":chair:": "🪑",
        ":champagne:": "🍾",
        ":chart:": "💹",
        ":chart_with_downwards_trend:": "📉",
        ":chart_with_upwards_trend:": "📈",
        ":checkered_flag:": "🏁",
        ":cheese:": "🧀",
        ":cherries:": "🍒",
        ":cherry_blossom:": "🌸",
        ":chess_pawn:": "♟️",
        ":chestnut:": "🌰",
        ":chicken:": "🐔",
        ":child:": "🧒",
        ":children_crossing:": "🚸",
        ":chile:": "🇨🇱",
        ":chipmunk:": "🐿️",
        ":chocolate_bar:": "🍫",
        ":chopsticks:": "🥢",
        ":christmas_island:": "🇨🇽",
        ":christmas_tree:": "🎄",
        ":church:": "⛪",
        ":cinema:": "🎦",
        ":circus_tent:": "🎪",
        ":city_sunrise:": "🌇",
        ":city_sunset:": "🌆",
        ":cityscape:": "🏙️",
        ":cl:": "🆑",
        ":clamp:": "🗜️",
        ":clap:": "👏",
        ":clapper:": "🎬",
        ":classical_building:": "🏛️",
        ":climbing:": "🧗",
        ":climbing_man:": "🧗‍♂️",
        ":climbing_woman:": "🧗‍♀️",
        ":clinking_glasses:": "🥂",
        ":clipboard:": "📋",
        ":clipperton_island:": "🇨🇵",
        ":clock1030:": "🕥",
        ":clock10:": "🕙",
        ":clock1130:": "🕦",
        ":clock11:": "🕚",
        ":clock1230:": "🕧",
        ":clock12:": "🕛",
        ":clock130:": "🕜",
        ":clock1:": "🕐",
        ":clock230:": "🕝",
        ":clock2:": "🕑",
        ":clock330:": "🕞",
        ":clock3:": "🕒",
        ":clock430:": "🕟",
        ":clock4:": "🕓",
        ":clock530:": "🕠",
        ":clock5:": "🕔",
        ":clock630:": "🕡",
        ":clock6:": "🕕",
        ":clock730:": "🕢",
        ":clock7:": "🕖",
        ":clock830:": "🕣",
        ":clock8:": "🕗",
        ":clock930:": "🕤",
        ":clock9:": "🕘",
        ":closed_book:": "📕",
        ":closed_lock_with_key:": "🔐",
        ":closed_umbrella:": "🌂",
        ":cloud:": "☁️",
        ":cloud_with_lightning:": "🌩️",
        ":cloud_with_lightning_and_rain:": "⛈️",
        ":cloud_with_rain:": "🌧️",
        ":cloud_with_snow:": "🌨️",
        ":clown_face:": "🤡",
        ":clubs:": "♣️",
        ":cn:": "🇨🇳",
        ":coat:": "🧥",
        ":cockroach:": "🪳",
        ":cocktail:": "🍸",
        ":coconut:": "🥥",
        ":cocos_islands:": "🇨🇨",
        ":coffee:": "☕",
        ":coffin:": "⚰️",
        ":coin:": "🪙",
        ":cold_face:": "🥶",
        ":cold_sweat:": "😰",
        ":collision:": "💥",
        ":colombia:": "🇨🇴",
        ":comet:": "☄️",
        ":comoros:": "🇰🇲",
        ":compass:": "🧭",
        ":computer:": "💻",
        ":computer_mouse:": "🖱️",
        ":confetti_ball:": "🎊",
        ":confounded:": "😖",
        ":confused:": "😕",
        ":congo_brazzaville:": "🇨🇬",
        ":congo_kinshasa:": "🇨🇩",
        ":congratulations:": "㊗️",
        ":construction:": "🚧",
        ":construction_worker:": "👷",
        ":construction_worker_man:": "👷‍♂️",
        ":construction_worker_woman:": "👷‍♀️",
        ":control_knobs:": "🎛️",
        ":convenience_store:": "🏪",
        ":cook:": "🧑‍🍳",
        ":cook_islands:": "🇨🇰",
        ":cookie:": "🍪",
        ":cool:": "🆒",
        ":cop:": "👮",
        ":copyright:": "©️",
        ":coral:": "🪸",
        ":corn:": "🌽",
        ":costa_rica:": "🇨🇷",
        ":cote_divoire:": "🇨🇮",
        ":couch_and_lamp:": "🛋️",
        ":couple:": "👫",
        ":couple_with_heart:": "💑",
        ":couple_with_heart_man_man:": "👨‍❤️‍👨",
        ":couple_with_heart_woman_man:": "👩‍❤️‍👨",
        ":couple_with_heart_woman_woman:": "👩‍❤️‍👩",
        ":couplekiss:": "💏",
        ":couplekiss_man_man:": "👨‍❤️‍💋‍👨",
        ":couplekiss_man_woman:": "👩‍❤️‍💋‍👨",
        ":couplekiss_woman_woman:": "👩‍❤️‍💋‍👩",
        ":cow2:": "🐄",
        ":cow:": "🐮",
        ":cowboy_hat_face:": "🤠",
        ":crab:": "🦀",
        ":crayon:": "🖍️",
        ":credit_card:": "💳",
        ":crescent_moon:": "🌙",
        ":cricket:": "🦗",
        ":cricket_game:": "🏏",
        ":croatia:": "🇭🇷",
        ":crocodile:": "🐊",
        ":croissant:": "🥐",
        ":crossed_fingers:": "🤞",
        ":crossed_flags:": "🎌",
        ":crossed_swords:": "⚔️",
        ":crown:": "👑",
        ":crutch:": "🩼",
        ":cry:": "😢",
        ":crying_cat_face:": "😿",
        ":crystal_ball:": "🔮",
        ":cuba:": "🇨🇺",
        ":cucumber:": "🥒",
        ":cup_with_straw:": "🥤",
        ":cupcake:": "🧁",
        ":cupid:": "💘",
        ":curacao:": "🇨🇼",
        ":curling_stone:": "🥌",
        ":curly_haired_man:": "👨‍🦱",
        ":curly_haired_woman:": "👩‍🦱",
        ":curly_loop:": "➰",
        ":currency_exchange:": "💱",
        ":curry:": "🍛",
        ":cursing_face:": "🤬",
        ":custard:": "🍮",
        ":customs:": "🛃",
        ":cut_of_meat:": "🥩",
        ":cyclone:": "🌀",
        ":cyprus:": "🇨🇾",
        ":czech_republic:": "🇨🇿",
        ":dagger:": "🗡️",
        ":dancer:": "💃",
        ":dancers:": "👯",
        ":dancing_men:": "👯‍♂️",
        ":dancing_women:": "👯‍♀️",
        ":dango:": "🍡",
        ":dark_sunglasses:": "🕶️",
        ":dart:": "🎯",
        ":dash:": "💨",
        ":date:": "📅",
        ":de:": "🇩🇪",
        ":deaf_man:": "🧏‍♂️",
        ":deaf_person:": "🧏",
        ":deaf_woman:": "🧏‍♀️",
        ":deciduous_tree:": "🌳",
        ":deer:": "🦌",
        ":denmark:": "🇩🇰",
        ":department_store:": "🏬",
        ":derelict_house:": "🏚️",
        ":desert:": "🏜️",
        ":desert_island:": "🏝️",
        ":desktop_computer:": "🖥️",
        ":detective:": "🕵️",
        ":diamond_shape_with_a_dot_inside:": "💠",
        ":diamonds:": "♦️",
        ":diego_garcia:": "🇩🇬",
        ":disappointed:": "😞",
        ":disappointed_relieved:": "😥",
        ":disguised_face:": "🥸",
        ":diving_mask:": "🤿",
        ":diya_lamp:": "🪔",
        ":dizzy:": "💫",
        ":dizzy_face:": "😵",
        ":djibouti:": "🇩🇯",
        ":dna:": "🧬",
        ":do_not_litter:": "🚯",
        ":dodo:": "🦤",
        ":dog2:": "🐕",
        ":dog:": "🐶",
        ":dollar:": "💵",
        ":dolls:": "🎎",
        ":dolphin:": "🐬",
        ":dominica:": "🇩🇲",
        ":dominican_republic:": "🇩🇴",
        ":donkey:": "🫏",
        ":door:": "🚪",
        ":dotted_line_face:": "🫥",
        ":doughnut:": "🍩",
        ":dove:": "🕊️",
        ":dragon:": "🐉",
        ":dragon_face:": "🐲",
        ":dress:": "👗",
        ":dromedary_camel:": "🐪",
        ":drooling_face:": "🤤",
        ":drop_of_blood:": "🩸",
        ":droplet:": "💧",
        ":drum:": "🥁",
        ":duck:": "🦆",
        ":dumpling:": "🥟",
        ":dvd:": "📀",
        ":e-mail:": "📧",
        ":eagle:": "🦅",
        ":ear:": "👂",
        ":ear_of_rice:": "🌾",
        ":ear_with_hearing_aid:": "🦻",
        ":earth_africa:": "🌍",
        ":earth_americas:": "🌎",
        ":earth_asia:": "🌏",
        ":ecuador:": "🇪🇨",
        ":egg:": "🥚",
        ":eggplant:": "🍆",
        ":egypt:": "🇪🇬",
        ":eight:": "8️⃣",
        ":eight_pointed_black_star:": "✴️",
        ":eight_spoked_asterisk:": "✳️",
        ":eject_button:": "⏏️",
        ":el_salvador:": "🇸🇻",
        ":electric_plug:": "🔌",
        ":elephant:": "🐘",
        ":elevator:": "🛗",
        ":elf:": "🧝",
        ":elf_man:": "🧝‍♂️",
        ":elf_woman:": "🧝‍♀️",
        ":email:": "📧",
        ":empty_nest:": "🪹",
        ":end:": "🔚",
        ":england:": "🏴󠁧󠁢󠁥󠁮󠁧󠁿",
        ":envelope:": "✉️",
        ":envelope_with_arrow:": "📩",
        ":equatorial_guinea:": "🇬🇶",
        ":eritrea:": "🇪🇷",
        ":es:": "🇪🇸",
        ":estonia:": "🇪🇪",
        ":ethiopia:": "🇪🇹",
        ":eu:": "🇪🇺",
        ":euro:": "💶",
        ":european_castle:": "🏰",
        ":european_post_office:": "🏤",
        ":european_union:": "🇪🇺",
        ":evergreen_tree:": "🌲",
        ":exclamation:": "❗",
        ":exploding_head:": "🤯",
        ":expressionless:": "😑",
        ":eye:": "👁️",
        ":eye_speech_bubble:": "👁️‍🗨️",
        ":eyeglasses:": "👓",
        ":eyes:": "👀",
        ":face_exhaling:": "😮‍💨",
        ":face_holding_back_tears:": "🥹",
        ":face_in_clouds:": "😶‍🌫️",
        ":face_with_diagonal_mouth:": "🫤",
        ":face_with_head_bandage:": "🤕",
        ":face_with_open_eyes_and_hand_over_mouth:": "🫢",
        ":face_with_peeking_eye:": "🫣",
        ":face_with_spiral_eyes:": "😵‍💫",
        ":face_with_thermometer:": "🤒",
        ":facepalm:": "🤦",
        ":facepunch:": "👊",
        ":factory:": "🏭",
        ":factory_worker:": "🧑‍🏭",
        ":fairy:": "🧚",
        ":fairy_man:": "🧚‍♂️",
        ":fairy_woman:": "🧚‍♀️",
        ":falafel:": "🧆",
        ":falkland_islands:": "🇫🇰",
        ":fallen_leaf:": "🍂",
        ":family:": "👪",
        ":family_man_boy:": "👨‍👦",
        ":family_man_boy_boy:": "👨‍👦‍👦",
        ":family_man_girl:": "👨‍👧",
        ":family_man_girl_boy:": "👨‍👧‍👦",
        ":family_man_girl_girl:": "👨‍👧‍👧",
        ":family_man_man_boy:": "👨‍👨‍👦",
        ":family_man_man_boy_boy:": "👨‍👨‍👦‍👦",
        ":family_man_man_girl:": "👨‍👨‍👧",
        ":family_man_man_girl_boy:": "👨‍👨‍👧‍👦",
        ":family_man_man_girl_girl:": "👨‍👨‍👧‍👧",
        ":family_man_woman_boy:": "👨‍👩‍👦",
        ":family_man_woman_boy_boy:": "👨‍👩‍👦‍👦",
        ":family_man_woman_girl:": "👨‍👩‍👧",
        ":family_man_woman_girl_boy:": "👨‍👩‍👧‍👦",
        ":family_man_woman_girl_girl:": "👨‍👩‍👧‍👧",
        ":family_woman_boy:": "👩‍👦",
        ":family_woman_boy_boy:": "👩‍👦‍👦",
        ":family_woman_girl:": "👩‍👧",
        ":family_woman_girl_boy:": "👩‍👧‍👦",
        ":family_woman_girl_girl:": "👩‍👧‍👧",
        ":family_woman_woman_boy:": "👩‍👩‍👦",
        ":family_woman_woman_boy_boy:": "👩‍👩‍👦‍👦",
        ":family_woman_woman_girl:": "👩‍👩‍👧",
        ":family_woman_woman_girl_boy:": "👩‍👩‍👧‍👦",
        ":family_woman_woman_girl_girl:": "👩‍👩‍👧‍👧",
        ":farmer:": "🧑‍🌾",
        ":faroe_islands:": "🇫🇴",
        ":fast_forward:": "⏩",
        ":fax:": "📠",
        ":fearful:": "😨",
        ":feather:": "🪶",
        ":feet:": "🐾",
        ":female_detective:": "🕵️‍♀️",
        ":female_sign:": "♀️",
        ":ferris_wheel:": "🎡",
        ":ferry:": "⛴️",
        ":field_hockey:": "🏑",
        ":fiji:": "🇫🇯",
        ":file_cabinet:": "🗄️",
        ":file_folder:": "📁",
        ":film_projector:": "📽️",
        ":film_strip:": "🎞️",
        ":finland:": "🇫🇮",
        ":fire:": "🔥",
        ":fire_engine:": "🚒",
        ":fire_extinguisher:": "🧯",
        ":firecracker:": "🧨",
        ":firefighter:": "🧑‍🚒",
        ":fireworks:": "🎆",
        ":first_quarter_moon:": "🌓",
        ":first_quarter_moon_with_face:": "🌛",
        ":fish:": "🐟",
        ":fish_cake:": "🍥",
        ":fishing_pole_and_fish:": "🎣",
        ":fist:": "✊",
        ":fist_left:": "🤛",
        ":fist_oncoming:": "👊",
        ":fist_raised:": "✊",
        ":fist_right:": "🤜",
        ":five:": "5️⃣",
        ":flags:": "🎏",
        ":flamingo:": "🦩",
        ":flashlight:": "🔦",
        ":flat_shoe:": "🥿",
        ":flatbread:": "🫓",
        ":fleur_de_lis:": "⚜️",
        ":flight_arrival:": "🛬",
        ":flight_departure:": "🛫",
        ":flipper:": "🐬",
        ":floppy_disk:": "💾",
        ":flower_playing_cards:": "🎴",
        ":flushed:": "😳",
        ":flute:": "🪈",
        ":fly:": "🪰",
        ":flying_disc:": "🥏",
        ":flying_saucer:": "🛸",
        ":fog:": "🌫️",
        ":foggy:": "🌁",
        ":folding_hand_fan:": "🪭",
        ":fondue:": "🫕",
        ":foot:": "🦶",
        ":football:": "🏈",
        ":footprints:": "👣",
        ":fork_and_knife:": "🍴",
        ":fortune_cookie:": "🥠",
        ":fountain:": "⛲",
        ":fountain_pen:": "🖋️",
        ":four:": "4️⃣",
        ":four_leaf_clover:": "🍀",
        ":fox_face:": "🦊",
        ":fr:": "🇫🇷",
        ":framed_picture:": "🖼️",
        ":free:": "🆓",
        ":french_guiana:": "🇬🇫",
        ":french_polynesia:": "🇵🇫",
        ":french_southern_territories:": "🇹🇫",
        ":fried_egg:": "🍳",
        ":fried_shrimp:": "🍤",
        ":fries:": "🍟",
        ":frog:": "🐸",
        ":frowning:": "😦",
        ":frowning_face:": "☹️",
        ":frowning_man:": "🙍‍♂️",
        ":frowning_person:": "🙍",
        ":frowning_woman:": "🙍‍♀️",
        ":fu:": "🖕",
        ":fuelpump:": "⛽",
        ":full_moon:": "🌕",
        ":full_moon_with_face:": "🌝",
        ":funeral_urn:": "⚱️",
        ":gabon:": "🇬🇦",
        ":gambia:": "🇬🇲",
        ":game_die:": "🎲",
        ":garlic:": "🧄",
        ":gb:": "🇬🇧",
        ":gear:": "⚙️",
        ":gem:": "💎",
        ":gemini:": "♊",
        ":genie:": "🧞",
        ":genie_man:": "🧞‍♂️",
        ":genie_woman:": "🧞‍♀️",
        ":georgia:": "🇬🇪",
        ":ghana:": "🇬🇭",
        ":ghost:": "👻",
        ":gibraltar:": "🇬🇮",
        ":gift:": "🎁",
        ":gift_heart:": "💝",
        ":ginger_root:": "🫚",
        ":giraffe:": "🦒",
        ":girl:": "👧",
        ":globe_with_meridians:": "🌐",
        ":gloves:": "🧤",
        ":goal_net:": "🥅",
        ":goat:": "🐐",
        ":goggles:": "🥽",
        ":golf:": "⛳",
        ":golfing:": "🏌️",
        ":golfing_man:": "🏌️‍♂️",
        ":golfing_woman:": "🏌️‍♀️",
        ":goose:": "🪿",
        ":gorilla:": "🦍",
        ":grapes:": "🍇",
        ":greece:": "🇬🇷",
        ":green_apple:": "🍏",
        ":green_book:": "📗",
        ":green_circle:": "🟢",
        ":green_heart:": "💚",
        ":green_salad:": "🥗",
        ":green_square:": "🟩",
        ":greenland:": "🇬🇱",
        ":grenada:": "🇬🇩",
        ":grey_exclamation:": "❕",
        ":grey_heart:": "🩶",
        ":grey_question:": "❔",
        ":grimacing:": "😬",
        ":grin:": "😁",
        ":grinning:": "😀",
        ":guadeloupe:": "🇬🇵",
        ":guam:": "🇬🇺",
        ":guard:": "💂",
        ":guardsman:": "💂‍♂️",
        ":guardswoman:": "💂‍♀️",
        ":guatemala:": "🇬🇹",
        ":guernsey:": "🇬🇬",
        ":guide_dog:": "🦮",
        ":guinea:": "🇬🇳",
        ":guinea_bissau:": "🇬🇼",
        ":guitar:": "🎸",
        ":gun:": "🔫",
        ":guyana:": "🇬🇾",
        ":hair_pick:": "🪮",
        ":haircut:": "💇",
        ":haircut_man:": "💇‍♂️",
        ":haircut_woman:": "💇‍♀️",
        ":haiti:": "🇭🇹",
        ":hamburger:": "🍔",
        ":hammer:": "🔨",
        ":hammer_and_pick:": "⚒️",
        ":hammer_and_wrench:": "🛠️",
        ":hamsa:": "🪬",
        ":hamster:": "🐹",
        ":hand:": "✋",
        ":hand_over_mouth:": "🤭",
        ":hand_with_index_finger_and_thumb_crossed:": "🫰",
        ":handbag:": "👜",
        ":handball_person:": "🤾",
        ":handshake:": "🤝",
        ":hankey:": "💩",
        ":hash:": "#️⃣",
        ":hatched_chick:": "🐥",
        ":hatching_chick:": "🐣",
        ":headphones:": "🎧",
        ":headstone:": "🪦",
        ":health_worker:": "🧑‍⚕️",
        ":hear_no_evil:": "🙉",
        ":heard_mcdonald_islands:": "🇭🇲",
        ":heart:": "❤️",
        ":heart_decoration:": "💟",
        ":heart_eyes:": "😍",
        ":heart_eyes_cat:": "😻",
        ":heart_hands:": "🫶",
        ":heart_on_fire:": "❤️‍🔥",
        ":heartbeat:": "💓",
        ":heartpulse:": "💗",
        ":hearts:": "♥️",
        ":heavy_check_mark:": "✔️",
        ":heavy_division_sign:": "➗",
        ":heavy_dollar_sign:": "💲",
        ":heavy_equals_sign:": "🟰",
        ":heavy_exclamation_mark:": "❗",
        ":heavy_heart_exclamation:": "❣️",
        ":heavy_minus_sign:": "➖",
        ":heavy_multiplication_x:": "✖️",
        ":heavy_plus_sign:": "➕",
        ":hedgehog:": "🦔",
        ":helicopter:": "🚁",
        ":herb:": "🌿",
        ":hibiscus:": "🌺",
        ":high_brightness:": "🔆",
        ":high_heel:": "👠",
        ":hiking_boot:": "🥾",
        ":hindu_temple:": "🛕",
        ":hippopotamus:": "🦛",
        ":hocho:": "🔪",
        ":hole:": "🕳️",
        ":honduras:": "🇭🇳",
        ":honey_pot:": "🍯",
        ":honeybee:": "🐝",
        ":hong_kong:": "🇭🇰",
        ":hook:": "🪝",
        ":horse:": "🐴",
        ":horse_racing:": "🏇",
        ":hospital:": "🏥",
        ":hot_face:": "🥵",
        ":hot_pepper:": "🌶️",
        ":hotdog:": "🌭",
        ":hotel:": "🏨",
        ":hotsprings:": "♨️",
        ":hourglass:": "⌛",
        ":hourglass_flowing_sand:": "⏳",
        ":house:": "🏠",
        ":house_with_garden:": "🏡",
        ":houses:": "🏘️",
        ":hugs:": "🤗",
        ":hungary:": "🇭🇺",
        ":hushed:": "😯",
        ":hut:": "🛖",
        ":hyacinth:": "🪻",
        ":ice_cream:": "🍨",
        ":ice_cube:": "🧊",
        ":ice_hockey:": "🏒",
        ":ice_skate:": "⛸️",
        ":icecream:": "🍦",
        ":iceland:": "🇮🇸",
        ":id:": "🆔",
        ":identification_card:": "🪪",
        ":ideograph_advantage:": "🉐",
        ":imp:": "👿",
        ":inbox_tray:": "📥",
        ":incoming_envelope:": "📨",
        ":index_pointing_at_the_viewer:": "🫵",
        ":india:": "🇮🇳",
        ":indonesia:": "🇮🇩",
        ":infinity:": "♾️",
        ":information_desk_person:": "💁",
        ":information_source:": "ℹ️",
        ":innocent:": "😇",
        ":interrobang:": "⁉️",
        ":iphone:": "📱",
        ":iran:": "🇮🇷",
        ":iraq:": "🇮🇶",
        ":ireland:": "🇮🇪",
        ":isle_of_man:": "🇮🇲",
        ":israel:": "🇮🇱",
        ":it:": "🇮🇹",
        ":izakaya_lantern:": "🏮",
        ":jack_o_lantern:": "🎃",
        ":jamaica:": "🇯🇲",
        ":japan:": "🗾",
        ":japanese_castle:": "🏯",
        ":japanese_goblin:": "👺",
        ":japanese_ogre:": "👹",
        ":jar:": "🫙",
        ":jeans:": "👖",
        ":jellyfish:": "🪼",
        ":jersey:": "🇯🇪",
        ":jigsaw:": "🧩",
        ":jordan:": "🇯🇴",
        ":joy:": "😂",
        ":joy_cat:": "😹",
        ":joystick:": "🕹️",
        ":jp:": "🇯🇵",
        ":judge:": "🧑‍⚖️",
        ":juggling_person:": "🤹",
        ":kaaba:": "🕋",
        ":kangaroo:": "🦘",
        ":kazakhstan:": "🇰🇿",
        ":kenya:": "🇰🇪",
        ":key:": "🔑",
        ":keyboard:": "⌨️",
        ":keycap_ten:": "🔟",
        ":khanda:": "🪯",
        ":kick_scooter:": "🛴",
        ":kimono:": "👘",
        ":kiribati:": "🇰🇮",
        ":kiss:": "💋",
        ":kissing:": "😗",
        ":kissing_cat:": "😽",
        ":kissing_closed_eyes:": "😚",
        ":kissing_heart:": "😘",
        ":kissing_smiling_eyes:": "😙",
        ":kite:": "🪁",
        ":kiwi_fruit:": "🥝",
        ":kneeling_man:": "🧎‍♂️",
        ":kneeling_person:": "🧎",
        ":kneeling_woman:": "🧎‍♀️",
        ":knife:": "🔪",
        ":knot:": "🪢",
        ":koala:": "🐨",
        ":koko:": "🈁",
        ":kosovo:": "🇽🇰",
        ":kr:": "🇰🇷",
        ":kuwait:": "🇰🇼",
        ":kyrgyzstan:": "🇰🇬",
        ":lab_coat:": "🥼",
        ":label:": "🏷️",
        ":lacrosse:": "🥍",
        ":ladder:": "🪜",
        ":lady_beetle:": "🐞",
        ":lantern:": "🏮",
        ":laos:": "🇱🇦",
        ":large_blue_circle:": "🔵",
        ":large_blue_diamond:": "🔷",
        ":large_orange_diamond:": "🔶",
        ":last_quarter_moon:": "🌗",
        ":last_quarter_moon_with_face:": "🌜",
        ":latin_cross:": "✝️",
        ":latvia:": "🇱🇻",
        ":laughing:": "😆",
        ":leafy_green:": "🥬",
        ":leaves:": "🍃",
        ":lebanon:": "🇱🇧",
        ":ledger:": "📒",
        ":left_luggage:": "🛅",
        ":left_right_arrow:": "↔️",
        ":left_speech_bubble:": "🗨️",
        ":leftwards_arrow_with_hook:": "↩️",
        ":leftwards_hand:": "🫲",
        ":leftwards_pushing_hand:": "🫷",
        ":leg:": "🦵",
        ":lemon:": "🍋",
        ":leo:": "♌",
        ":leopard:": "🐆",
        ":lesotho:": "🇱🇸",
        ":level_slider:": "🎚️",
        ":liberia:": "🇱🇷",
        ":libra:": "♎",
        ":libya:": "🇱🇾",
        ":liechtenstein:": "🇱🇮",
        ":light_blue_heart:": "🩵",
        ":light_rail:": "🚈",
        ":link:": "🔗",
        ":lion:": "🦁",
        ":lips:": "👄",
        ":lipstick:": "💄",
        ":lithuania:": "🇱🇹",
        ":lizard:": "🦎",
        ":llama:": "🦙",
        ":lobster:": "🦞",
        ":lock:": "🔒",
        ":lock_with_ink_pen:": "🔏",
        ":lollipop:": "🍭",
        ":long_drum:": "🪘",
        ":loop:": "➿",
        ":lotion_bottle:": "🧴",
        ":lotus:": "🪷",
        ":lotus_position:": "🧘",
        ":lotus_position_man:": "🧘‍♂️",
        ":lotus_position_woman:": "🧘‍♀️",
        ":loud_sound:": "🔊",
        ":loudspeaker:": "📢",
        ":love_hotel:": "🏩",
        ":love_letter:": "💌",
        ":love_you_gesture:": "🤟",
        ":low_battery:": "🪫",
        ":low_brightness:": "🔅",
        ":luggage:": "🧳",
        ":lungs:": "🫁",
        ":luxembourg:": "🇱🇺",
        ":lying_face:": "🤥",
        ":m:": "Ⓜ️",
        ":macau:": "🇲🇴",
        ":macedonia:": "🇲🇰",
        ":madagascar:": "🇲🇬",
        ":mag:": "🔍",
        ":mag_right:": "🔎",
        ":mage:": "🧙",
        ":mage_man:": "🧙‍♂️",
        ":mage_woman:": "🧙‍♀️",
        ":magic_wand:": "🪄",
        ":magnet:": "🧲",
        ":mahjong:": "🀄",
        ":mailbox:": "📫",
        ":mailbox_closed:": "📪",
        ":mailbox_with_mail:": "📬",
        ":mailbox_with_no_mail:": "📭",
        ":malawi:": "🇲🇼",
        ":malaysia:": "🇲🇾",
        ":maldives:": "🇲🇻",
        ":male_detective:": "🕵️‍♂️",
        ":male_sign:": "♂️",
        ":mali:": "🇲🇱",
        ":malta:": "🇲🇹",
        ":mammoth:": "🦣",
        ":man:": "👨",
        ":man_artist:": "👨‍🎨",
        ":man_astronaut:": "👨‍🚀",
        ":man_beard:": "🧔‍♂️",
        ":man_cartwheeling:": "🤸‍♂️",
        ":man_cook:": "👨‍🍳",
        ":man_dancing:": "🕺",
        ":man_facepalming:": "🤦‍♂️",
        ":man_factory_worker:": "👨‍🏭",
        ":man_farmer:": "👨‍🌾",
        ":man_feeding_baby:": "👨‍🍼",
        ":man_firefighter:": "👨‍🚒",
        ":man_health_worker:": "👨‍⚕️",
        ":man_in_manual_wheelchair:": "👨‍🦽",
        ":man_in_motorized_wheelchair:": "👨‍🦼",
        ":man_in_tuxedo:": "🤵‍♂️",
        ":man_judge:": "👨‍⚖️",
        ":man_juggling:": "🤹‍♂️",
        ":man_mechanic:": "👨‍🔧",
        ":man_office_worker:": "👨‍💼",
        ":man_pilot:": "👨‍✈️",
        ":man_playing_handball:": "🤾‍♂️",
        ":man_playing_water_polo:": "🤽‍♂️",
        ":man_scientist:": "👨‍🔬",
        ":man_shrugging:": "🤷‍♂️",
        ":man_singer:": "👨‍🎤",
        ":man_student:": "👨‍🎓",
        ":man_teacher:": "👨‍🏫",
        ":man_technologist:": "👨‍💻",
        ":man_with_gua_pi_mao:": "👲",
        ":man_with_probing_cane:": "👨‍🦯",
        ":man_with_turban:": "👳‍♂️",
        ":man_with_veil:": "👰‍♂️",
        ":mandarin:": "🍊",
        ":mango:": "🥭",
        ":mans_shoe:": "👞",
        ":mantelpiece_clock:": "🕰️",
        ":manual_wheelchair:": "🦽",
        ":maple_leaf:": "🍁",
        ":maracas:": "🪇",
        ":marshall_islands:": "🇲🇭",
        ":martial_arts_uniform:": "🥋",
        ":martinique:": "🇲🇶",
        ":mask:": "😷",
        ":massage:": "💆",
        ":massage_man:": "💆‍♂️",
        ":massage_woman:": "💆‍♀️",
        ":mate:": "🧉",
        ":mauritania:": "🇲🇷",
        ":mauritius:": "🇲🇺",
        ":mayotte:": "🇾🇹",
        ":meat_on_bone:": "🍖",
        ":mechanic:": "🧑‍🔧",
        ":mechanical_arm:": "🦾",
        ":mechanical_leg:": "🦿",
        ":medal_military:": "🎖️",
        ":medal_sports:": "🏅",
        ":medical_symbol:": "⚕️",
        ":mega:": "📣",
        ":melon:": "🍈",
        ":melting_face:": "🫠",
        ":memo:": "📝",
        ":men_wrestling:": "🤼‍♂️",
        ":mending_heart:": "❤️‍🩹",
        ":menorah:": "🕎",
        ":mens:": "🚹",
        ":mermaid:": "🧜‍♀️",
        ":merman:": "🧜‍♂️",
        ":merperson:": "🧜",
        ":metal:": "🤘",
        ":metro:": "🚇",
        ":mexico:": "🇲🇽",
        ":microbe:": "🦠",
        ":micronesia:": "🇫🇲",
        ":microphone:": "🎤",
        ":microscope:": "🔬",
        ":middle_finger:": "🖕",
        ":military_helmet:": "🪖",
        ":milk_glass:": "🥛",
        ":milky_way:": "🌌",
        ":minibus:": "🚐",
        ":minidisc:": "💽",
        ":mirror:": "🪞",
        ":mirror_ball:": "🪩",
        ":mobile_phone_off:": "📴",
        ":moldova:": "🇲🇩",
        ":monaco:": "🇲🇨",
        ":money_mouth_face:": "🤑",
        ":money_with_wings:": "💸",
        ":moneybag:": "💰",
        ":mongolia:": "🇲🇳",
        ":monkey:": "🐒",
        ":monkey_face:": "🐵",
        ":monocle_face:": "🧐",
        ":monorail:": "🚝",
        ":montenegro:": "🇲🇪",
        ":montserrat:": "🇲🇸",
        ":moon:": "🌔",
        ":moon_cake:": "🥮",
        ":moose:": "🫎",
        ":morocco:": "🇲🇦",
        ":mortar_board:": "🎓",
        ":mosque:": "🕌",
        ":mosquito:": "🦟",
        ":motor_boat:": "🛥️",
        ":motor_scooter:": "🛵",
        ":motorcycle:": "🏍️",
        ":motorized_wheelchair:": "🦼",
        ":motorway:": "🛣️",
        ":mount_fuji:": "🗻",
        ":mountain:": "⛰️",
        ":mountain_bicyclist:": "🚵",
        ":mountain_biking_man:": "🚵‍♂️",
        ":mountain_biking_woman:": "🚵‍♀️",
        ":mountain_cableway:": "🚠",
        ":mountain_railway:": "🚞",
        ":mountain_snow:": "🏔️",
        ":mouse2:": "🐁",
        ":mouse:": "🐭",
        ":mouse_trap:": "🪤",
        ":movie_camera:": "🎥",
        ":moyai:": "🗿",
        ":mozambique:": "🇲🇿",
        ":mrs_claus:": "🤶",
        ":muscle:": "💪",
        ":mushroom:": "🍄",
        ":musical_keyboard:": "🎹",
        ":musical_note:": "🎵",
        ":musical_score:": "🎼",
        ":mute:": "🔇",
        ":mx_claus:": "🧑‍🎄",
        ":myanmar:": "🇲🇲",
        ":nail_care:": "💅",
        ":name_badge:": "📛",
        ":namibia:": "🇳🇦",
        ":national_park:": "🏞️",
        ":nauru:": "🇳🇷",
        ":nauseated_face:": "🤢",
        ":nazar_amulet:": "🧿",
        ":necktie:": "👔",
        ":negative_squared_cross_mark:": "❎",
        ":nepal:": "🇳🇵",
        ":nerd_face:": "🤓",
        ":nest_with_eggs:": "🪺",
        ":nesting_dolls:": "🪆",
        ":netherlands:": "🇳🇱",
        ":neutral_face:": "😐",
        ":new:": "🆕",
        ":new_caledonia:": "🇳🇨",
        ":new_moon:": "🌑",
        ":new_moon_with_face:": "🌚",
        ":new_zealand:": "🇳🇿",
        ":newspaper:": "📰",
        ":newspaper_roll:": "🗞️",
        ":next_track_button:": "⏭️",
        ":ng:": "🆖",
        ":ng_man:": "🙅‍♂️",
        ":ng_woman:": "🙅‍♀️",
        ":nicaragua:": "🇳🇮",
        ":niger:": "🇳🇪",
        ":nigeria:": "🇳🇬",
        ":night_with_stars:": "🌃",
        ":nine:": "9️⃣",
        ":ninja:": "🥷",
        ":niue:": "🇳🇺",
        ":no_bell:": "🔕",
        ":no_bicycles:": "🚳",
        ":no_entry:": "⛔",
        ":no_entry_sign:": "🚫",
        ":no_good:": "🙅",
        ":no_good_man:": "🙅‍♂️",
        ":no_good_woman:": "🙅‍♀️",
        ":no_mobile_phones:": "📵",
        ":no_mouth:": "😶",
        ":no_pedestrians:": "🚷",
        ":no_smoking:": "🚭",
        ":non-potable_water:": "🚱",
        ":norfolk_island:": "🇳🇫",
        ":north_korea:": "🇰🇵",
        ":northern_mariana_islands:": "🇲🇵",
        ":norway:": "🇳🇴",
        ":nose:": "👃",
        ":notebook:": "📓",
        ":notebook_with_decorative_cover:": "📔",
        ":notes:": "🎶",
        ":nut_and_bolt:": "🔩",
        ":o2:": "🅾️",
        ":o:": "⭕",
        ":ocean:": "🌊",
        ":octopus:": "🐙",
        ":oden:": "🍢",
        ":office:": "🏢",
        ":office_worker:": "🧑‍💼",
        ":oil_drum:": "🛢️",
        ":ok:": "🆗",
        ":ok_hand:": "👌",
        ":ok_man:": "🙆‍♂️",
        ":ok_person:": "🙆",
        ":ok_woman:": "🙆‍♀️",
        ":old_key:": "🗝️",
        ":older_adult:": "🧓",
        ":older_man:": "👴",
        ":older_woman:": "👵",
        ":olive:": "🫒",
        ":om:": "🕉️",
        ":oman:": "🇴🇲",
        ":on:": "🔛",
        ":oncoming_automobile:": "🚘",
        ":oncoming_bus:": "🚍",
        ":oncoming_police_car:": "🚔",
        ":oncoming_taxi:": "🚖",
        ":one:": "1️⃣",
        ":one_piece_swimsuit:": "🩱",
        ":onion:": "🧅",
        ":open_book:": "📖",
        ":open_file_folder:": "📂",
        ":open_hands:": "👐",
        ":open_mouth:": "😮",
        ":open_umbrella:": "☂️",
        ":ophiuchus:": "⛎",
        ":orange:": "🍊",
        ":orange_book:": "📙",
        ":orange_circle:": "🟠",
        ":orange_heart:": "🧡",
        ":orange_square:": "🟧",
        ":orangutan:": "🦧",
        ":orthodox_cross:": "☦️",
        ":otter:": "🦦",
        ":outbox_tray:": "📤",
        ":owl:": "🦉",
        ":ox:": "🐂",
        ":oyster:": "🦪",
        ":package:": "📦",
        ":page_facing_up:": "📄",
        ":page_with_curl:": "📃",
        ":pager:": "📟",
        ":paintbrush:": "🖌️",
        ":pakistan:": "🇵🇰",
        ":palau:": "🇵🇼",
        ":palestinian_territories:": "🇵🇸",
        ":palm_down_hand:": "🫳",
        ":palm_tree:": "🌴",
        ":palm_up_hand:": "🫴",
        ":palms_up_together:": "🤲",
        ":panama:": "🇵🇦",
        ":pancakes:": "🥞",
        ":panda_face:": "🐼",
        ":paperclip:": "📎",
        ":paperclips:": "🖇️",
        ":papua_new_guinea:": "🇵🇬",
        ":parachute:": "🪂",
        ":paraguay:": "🇵🇾",
        ":parasol_on_ground:": "⛱️",
        ":parking:": "🅿️",
        ":parrot:": "🦜",
        ":part_alternation_mark:": "〽️",
        ":partly_sunny:": "⛅",
        ":partying_face:": "🥳",
        ":passenger_ship:": "🛳️",
        ":passport_control:": "🛂",
        ":pause_button:": "⏸️",
        ":paw_prints:": "🐾",
        ":pea_pod:": "🫛",
        ":peace_symbol:": "☮️",
        ":peach:": "🍑",
        ":peacock:": "🦚",
        ":peanuts:": "🥜",
        ":pear:": "🍐",
        ":pen:": "🖊️",
        ":pencil2:": "✏️",
        ":pencil:": "📝",
        ":penguin:": "🐧",
        ":pensive:": "😔",
        ":people_holding_hands:": "🧑‍🤝‍🧑",
        ":people_hugging:": "🫂",
        ":performing_arts:": "🎭",
        ":persevere:": "😣",
        ":person_bald:": "🧑‍🦲",
        ":person_curly_hair:": "🧑‍🦱",
        ":person_feeding_baby:": "🧑‍🍼",
        ":person_fencing:": "🤺",
        ":person_in_manual_wheelchair:": "🧑‍🦽",
        ":person_in_motorized_wheelchair:": "🧑‍🦼",
        ":person_in_tuxedo:": "🤵",
        ":person_red_hair:": "🧑‍🦰",
        ":person_white_hair:": "🧑‍🦳",
        ":person_with_crown:": "🫅",
        ":person_with_probing_cane:": "🧑‍🦯",
        ":person_with_turban:": "👳",
        ":person_with_veil:": "👰",
        ":peru:": "🇵🇪",
        ":petri_dish:": "🧫",
        ":philippines:": "🇵🇭",
        ":phone:": "☎️",
        ":pick:": "⛏️",
        ":pickup_truck:": "🛻",
        ":pie:": "🥧",
        ":pig2:": "🐖",
        ":pig:": "🐷",
        ":pig_nose:": "🐽",
        ":pill:": "💊",
        ":pilot:": "🧑‍✈️",
        ":pinata:": "🪅",
        ":pinched_fingers:": "🤌",
        ":pinching_hand:": "🤏",
        ":pineapple:": "🍍",
        ":ping_pong:": "🏓",
        ":pink_heart:": "🩷",
        ":pirate_flag:": "🏴‍☠️",
        ":pisces:": "♓",
        ":pitcairn_islands:": "🇵🇳",
        ":pizza:": "🍕",
        ":placard:": "🪧",
        ":place_of_worship:": "🛐",
        ":plate_with_cutlery:": "🍽️",
        ":play_or_pause_button:": "⏯️",
        ":playground_slide:": "🛝",
        ":pleading_face:": "🥺",
        ":plunger:": "🪠",
        ":point_down:": "👇",
        ":point_left:": "👈",
        ":point_right:": "👉",
        ":point_up:": "☝️",
        ":point_up_2:": "👆",
        ":poland:": "🇵🇱",
        ":polar_bear:": "🐻‍❄️",
        ":police_car:": "🚓",
        ":police_officer:": "👮",
        ":policeman:": "👮‍♂️",
        ":policewoman:": "👮‍♀️",
        ":poodle:": "🐩",
        ":poop:": "💩",
        ":popcorn:": "🍿",
        ":portugal:": "🇵🇹",
        ":post_office:": "🏣",
        ":postal_horn:": "📯",
        ":postbox:": "📮",
        ":potable_water:": "🚰",
        ":potato:": "🥔",
        ":potted_plant:": "🪴",
        ":pouch:": "👝",
        ":poultry_leg:": "🍗",
        ":pound:": "💷",
        ":pouring_liquid:": "🫗",
        ":pout:": "😡",
        ":pouting_cat:": "😾",
        ":pouting_face:": "🙎",
        ":pouting_man:": "🙎‍♂️",
        ":pouting_woman:": "🙎‍♀️",
        ":pray:": "🙏",
        ":prayer_beads:": "📿",
        ":pregnant_man:": "🫃",
        ":pregnant_person:": "🫄",
        ":pregnant_woman:": "🤰",
        ":pretzel:": "🥨",
        ":previous_track_button:": "⏮️",
        ":prince:": "🤴",
        ":princess:": "👸",
        ":printer:": "🖨️",
        ":probing_cane:": "🦯",
        ":puerto_rico:": "🇵🇷",
        ":punch:": "👊",
        ":purple_circle:": "🟣",
        ":purple_heart:": "💜",
        ":purple_square:": "🟪",
        ":purse:": "👛",
        ":pushpin:": "📌",
        ":put_litter_in_its_place:": "🚮",
        ":qatar:": "🇶🇦",
        ":question:": "❓",
        ":rabbit2:": "🐇",
        ":rabbit:": "🐰",
        ":raccoon:": "🦝",
        ":racehorse:": "🐎",
        ":racing_car:": "🏎️",
        ":radio:": "📻",
        ":radio_button:": "🔘",
        ":radioactive:": "☢️",
        ":rage:": "😡",
        ":railway_car:": "🚃",
        ":railway_track:": "🛤️",
        ":rainbow:": "🌈",
        ":rainbow_flag:": "🏳️‍🌈",
        ":raised_back_of_hand:": "🤚",
        ":raised_eyebrow:": "🤨",
        ":raised_hand:": "✋",
        ":raised_hand_with_fingers_splayed:": "🖐️",
        ":raised_hands:": "🙌",
        ":raising_hand:": "🙋",
        ":raising_hand_man:": "🙋‍♂️",
        ":raising_hand_woman:": "🙋‍♀️",
        ":ram:": "🐏",
        ":ramen:": "🍜",
        ":rat:": "🐀",
        ":razor:": "🪒",
        ":receipt:": "🧾",
        ":record_button:": "⏺️",
        ":recycle:": "♻️",
        ":red_car:": "🚗",
        ":red_circle:": "🔴",
        ":red_envelope:": "🧧",
        ":red_haired_man:": "👨‍🦰",
        ":red_haired_woman:": "👩‍🦰",
        ":red_square:": "🟥",
        ":registered:": "®️",
        ":relaxed:": "☺️",
        ":relieved:": "😌",
        ":reminder_ribbon:": "🎗️",
        ":repeat:": "🔁",
        ":repeat_one:": "🔂",
        ":rescue_worker_helmet:": "⛑️",
        ":restroom:": "🚻",
        ":reunion:": "🇷🇪",
        ":revolving_hearts:": "💞",
        ":rewind:": "⏪",
        ":rhinoceros:": "🦏",
        ":ribbon:": "🎀",
        ":rice:": "🍚",
        ":rice_ball:": "🍙",
        ":rice_cracker:": "🍘",
        ":rice_scene:": "🎑",
        ":right_anger_bubble:": "🗯️",
        ":rightwards_hand:": "🫱",
        ":rightwards_pushing_hand:": "🫸",
        ":ring:": "💍",
        ":ring_buoy:": "🛟",
        ":ringed_planet:": "🪐",
        ":robot:": "🤖",
        ":rock:": "🪨",
        ":rocket:": "🚀",
        ":rofl:": "🤣",
        ":roll_eyes:": "🙄",
        ":roll_of_paper:": "🧻",
        ":roller_coaster:": "🎢",
        ":roller_skate:": "🛼",
        ":romania:": "🇷🇴",
        ":rooster:": "🐓",
        ":rose:": "🌹",
        ":rosette:": "🏵️",
        ":rotating_light:": "🚨",
        ":round_pushpin:": "📍",
        ":rowboat:": "🚣",
        ":rowing_man:": "🚣‍♂️",
        ":rowing_woman:": "🚣‍♀️",
        ":ru:": "🇷🇺",
        ":rugby_football:": "🏉",
        ":runner:": "🏃",
        ":running:": "🏃",
        ":running_man:": "🏃‍♂️",
        ":running_shirt_with_sash:": "🎽",
        ":running_woman:": "🏃‍♀️",
        ":rwanda:": "🇷🇼",
        ":sa:": "🈂️",
        ":safety_pin:": "🧷",
        ":safety_vest:": "🦺",
        ":sagittarius:": "♐",
        ":sailboat:": "⛵",
        ":sake:": "🍶",
        ":salt:": "🧂",
        ":saluting_face:": "🫡",
        ":samoa:": "🇼🇸",
        ":san_marino:": "🇸🇲",
        ":sandal:": "👡",
        ":sandwich:": "🥪",
        ":santa:": "🎅",
        ":sao_tome_principe:": "🇸🇹",
        ":sari:": "🥻",
        ":sassy_man:": "💁‍♂️",
        ":sassy_woman:": "💁‍♀️",
        ":satellite:": "📡",
        ":satisfied:": "😆",
        ":saudi_arabia:": "🇸🇦",
        ":sauna_man:": "🧖‍♂️",
        ":sauna_person:": "🧖",
        ":sauna_woman:": "🧖‍♀️",
        ":sauropod:": "🦕",
        ":saxophone:": "🎷",
        ":scarf:": "🧣",
        ":school:": "🏫",
        ":school_satchel:": "🎒",
        ":scientist:": "🧑‍🔬",
        ":scissors:": "✂️",
        ":scorpion:": "🦂",
        ":scorpius:": "♏",
        ":scotland:": "🏴󠁧󠁢󠁳󠁣󠁴󠁿",
        ":scream:": "😱",
        ":scream_cat:": "🙀",
        ":screwdriver:": "🪛",
        ":scroll:": "📜",
        ":seal:": "🦭",
        ":seat:": "💺",
        ":secret:": "㊙️",
        ":see_no_evil:": "🙈",
        ":seedling:": "🌱",
        ":selfie:": "🤳",
        ":senegal:": "🇸🇳",
        ":serbia:": "🇷🇸",
        ":service_dog:": "🐕‍🦺",
        ":seven:": "7️⃣",
        ":sewing_needle:": "🪡",
        ":seychelles:": "🇸🇨",
        ":shaking_face:": "🫨",
        ":shallow_pan_of_food:": "🥘",
        ":shamrock:": "☘️",
        ":shark:": "🦈",
        ":shaved_ice:": "🍧",
        ":sheep:": "🐑",
        ":shell:": "🐚",
        ":shield:": "🛡️",
        ":shinto_shrine:": "⛩️",
        ":ship:": "🚢",
        ":shirt:": "👕",
        ":shit:": "💩",
        ":shoe:": "👞",
        ":shopping:": "🛍️",
        ":shopping_cart:": "🛒",
        ":shorts:": "🩳",
        ":shower:": "🚿",
        ":shrimp:": "🦐",
        ":shrug:": "🤷",
        ":shushing_face:": "🤫",
        ":sierra_leone:": "🇸🇱",
        ":signal_strength:": "📶",
        ":singapore:": "🇸🇬",
        ":singer:": "🧑‍🎤",
        ":sint_maarten:": "🇸🇽",
        ":six:": "6️⃣",
        ":six_pointed_star:": "🔯",
        ":skateboard:": "🛹",
        ":ski:": "🎿",
        ":skier:": "⛷️",
        ":skull:": "💀",
        ":skull_and_crossbones:": "☠️",
        ":skunk:": "🦨",
        ":sled:": "🛷",
        ":sleeping:": "😴",
        ":sleeping_bed:": "🛌",
        ":sleepy:": "😪",
        ":slightly_frowning_face:": "🙁",
        ":slightly_smiling_face:": "🙂",
        ":slot_machine:": "🎰",
        ":sloth:": "🦥",
        ":slovakia:": "🇸🇰",
        ":slovenia:": "🇸🇮",
        ":small_airplane:": "🛩️",
        ":small_blue_diamond:": "🔹",
        ":small_orange_diamond:": "🔸",
        ":small_red_triangle:": "🔺",
        ":small_red_triangle_down:": "🔻",
        ":smile:": "😄",
        ":smile_cat:": "😸",
        ":smiley:": "😃",
        ":smiley_cat:": "😺",
        ":smiling_face_with_tear:": "🥲",
        ":smiling_face_with_three_hearts:": "🥰",
        ":smiling_imp:": "😈",
        ":smirk:": "😏",
        ":smirk_cat:": "😼",
        ":smoking:": "🚬",
        ":snail:": "🐌",
        ":snake:": "🐍",
        ":sneezing_face:": "🤧",
        ":snowboarder:": "🏂",
        ":snowflake:": "❄️",
        ":snowman:": "⛄",
        ":snowman_with_snow:": "☃️",
        ":soap:": "🧼",
        ":sob:": "😭",
        ":soccer:": "⚽",
        ":socks:": "🧦",
        ":softball:": "🥎",
        ":solomon_islands:": "🇸🇧",
        ":somalia:": "🇸🇴",
        ":soon:": "🔜",
        ":sos:": "🆘",
        ":sound:": "🔉",
        ":south_africa:": "🇿🇦",
        ":south_georgia_south_sandwich_islands:": "🇬🇸",
        ":south_sudan:": "🇸🇸",
        ":space_invader:": "👾",
        ":spades:": "♠️",
        ":spaghetti:": "🍝",
        ":sparkle:": "❇️",
        ":sparkler:": "🎇",
        ":sparkles:": "✨",
        ":sparkling_heart:": "💖",
        ":speak_no_evil:": "🙊",
        ":speaker:": "🔈",
        ":speaking_head:": "🗣️",
        ":speech_balloon:": "💬",
        ":speedboat:": "🚤",
        ":spider:": "🕷️",
        ":spider_web:": "🕸️",
        ":spiral_calendar:": "🗓️",
        ":spiral_notepad:": "🗒️",
        ":sponge:": "🧽",
        ":spoon:": "🥄",
        ":squid:": "🦑",
        ":sri_lanka:": "🇱🇰",
        ":st_barthelemy:": "🇧🇱",
        ":st_helena:": "🇸🇭",
        ":st_kitts_nevis:": "🇰🇳",
        ":st_lucia:": "🇱🇨",
        ":st_martin:": "🇲🇫",
        ":st_pierre_miquelon:": "🇵🇲",
        ":st_vincent_grenadines:": "🇻🇨",
        ":stadium:": "🏟️",
        ":standing_man:": "🧍‍♂️",
        ":standing_person:": "🧍",
        ":standing_woman:": "🧍‍♀️",
        ":star2:": "🌟",
        ":star:": "⭐",
        ":star_and_crescent:": "☪️",
        ":star_of_david:": "✡️",
        ":star_struck:": "🤩",
        ":stars:": "🌠",
        ":station:": "🚉",
        ":statue_of_liberty:": "🗽",
        ":steam_locomotive:": "🚂",
        ":stethoscope:": "🩺",
        ":stew:": "🍲",
        ":stop_button:": "⏹️",
        ":stop_sign:": "🛑",
        ":stopwatch:": "⏱️",
        ":straight_ruler:": "📏",
        ":strawberry:": "🍓",
        ":stuck_out_tongue:": "😛",
        ":stuck_out_tongue_closed_eyes:": "😝",
        ":stuck_out_tongue_winking_eye:": "😜",
        ":student:": "🧑‍🎓",
        ":studio_microphone:": "🎙️",
        ":stuffed_flatbread:": "🥙",
        ":sudan:": "🇸🇩",
        ":sun_behind_large_cloud:": "🌥️",
        ":sun_behind_rain_cloud:": "🌦️",
        ":sun_behind_small_cloud:": "🌤️",
        ":sun_with_face:": "🌞",
        ":sunflower:": "🌻",
        ":sunglasses:": "😎",
        ":sunny:": "☀️",
        ":sunrise:": "🌅",
        ":sunrise_over_mountains:": "🌄",
        ":superhero:": "🦸",
        ":superhero_man:": "🦸‍♂️",
        ":superhero_woman:": "🦸‍♀️",
        ":supervillain:": "🦹",
        ":supervillain_man:": "🦹‍♂️",
        ":supervillain_woman:": "🦹‍♀️",
        ":surfer:": "🏄",
        ":surfing_man:": "🏄‍♂️",
        ":surfing_woman:": "🏄‍♀️",
        ":suriname:": "🇸🇷",
        ":sushi:": "🍣",
        ":suspension_railway:": "🚟",
        ":svalbard_jan_mayen:": "🇸🇯",
        ":swan:": "🦢",
        ":swaziland:": "🇸🇿",
        ":sweat:": "😓",
        ":sweat_drops:": "💦",
        ":sweat_smile:": "😅",
        ":sweden:": "🇸🇪",
        ":sweet_potato:": "🍠",
        ":swim_brief:": "🩲",
        ":swimmer:": "🏊",
        ":swimming_man:": "🏊‍♂️",
        ":swimming_woman:": "🏊‍♀️",
        ":switzerland:": "🇨🇭",
        ":symbols:": "🔣",
        ":synagogue:": "🕍",
        ":syria:": "🇸🇾",
        ":syringe:": "💉",
        ":t-rex:": "🦖",
        ":taco:": "🌮",
        ":tada:": "🎉",
        ":taiwan:": "🇹🇼",
        ":tajikistan:": "🇹🇯",
        ":takeout_box:": "🥡",
        ":tamale:": "🫔",
        ":tanabata_tree:": "🎋",
        ":tangerine:": "🍊",
        ":tanzania:": "🇹🇿",
        ":taurus:": "♉",
        ":taxi:": "🚕",
        ":tea:": "🍵",
        ":teacher:": "🧑‍🏫",
        ":teapot:": "🫖",
        ":technologist:": "🧑‍💻",
        ":teddy_bear:": "🧸",
        ":telephone:": "☎️",
        ":telephone_receiver:": "📞",
        ":telescope:": "🔭",
        ":tennis:": "🎾",
        ":tent:": "⛺",
        ":test_tube:": "🧪",
        ":thailand:": "🇹🇭",
        ":thermometer:": "🌡️",
        ":thinking:": "🤔",
        ":thong_sandal:": "🩴",
        ":thought_balloon:": "💭",
        ":thread:": "🧵",
        ":three:": "3️⃣",
        ":thumbsdown:": "👎",
        ":thumbsup:": "👍",
        ":ticket:": "🎫",
        ":tickets:": "🎟️",
        ":tiger2:": "🐅",
        ":tiger:": "🐯",
        ":timer_clock:": "⏲️",
        ":timor_leste:": "🇹🇱",
        ":tipping_hand_man:": "💁‍♂️",
        ":tipping_hand_person:": "💁",
        ":tipping_hand_woman:": "💁‍♀️",
        ":tired_face:": "😫",
        ":tm:": "™️",
        ":togo:": "🇹🇬",
        ":toilet:": "🚽",
        ":tokelau:": "🇹🇰",
        ":tokyo_tower:": "🗼",
        ":tomato:": "🍅",
        ":tonga:": "🇹🇴",
        ":tongue:": "👅",
        ":toolbox:": "🧰",
        ":tooth:": "🦷",
        ":toothbrush:": "🪥",
        ":top:": "🔝",
        ":tophat:": "🎩",
        ":tornado:": "🌪️",
        ":tr:": "🇹🇷",
        ":trackball:": "🖲️",
        ":tractor:": "🚜",
        ":traffic_light:": "🚥",
        ":train2:": "🚆",
        ":train:": "🚋",
        ":tram:": "🚊",
        ":transgender_flag:": "🏳️‍⚧️",
        ":transgender_symbol:": "⚧️",
        ":triangular_flag_on_post:": "🚩",
        ":triangular_ruler:": "📐",
        ":trident:": "🔱",
        ":trinidad_tobago:": "🇹🇹",
        ":tristan_da_cunha:": "🇹🇦",
        ":triumph:": "😤",
        ":troll:": "🧌",
        ":trolleybus:": "🚎",
        ":trophy:": "🏆",
        ":tropical_drink:": "🍹",
        ":tropical_fish:": "🐠",
        ":truck:": "🚚",
        ":trumpet:": "🎺",
        ":tshirt:": "👕",
        ":tulip:": "🌷",
        ":tumbler_glass:": "🥃",
        ":tunisia:": "🇹🇳",
        ":turkey:": "🦃",
        ":turkmenistan:": "🇹🇲",
        ":turks_caicos_islands:": "🇹🇨",
        ":turtle:": "🐢",
        ":tuvalu:": "🇹🇻",
        ":tv:": "📺",
        ":twisted_rightwards_arrows:": "🔀",
        ":two:": "2️⃣",
        ":two_hearts:": "💕",
        ":two_men_holding_hands:": "👬",
        ":two_women_holding_hands:": "👭",
        ":u5272:": "🈹",
        ":u5408:": "🈴",
        ":u55b6:": "🈺",
        ":u6307:": "🈯",
        ":u6708:": "🈷️",
        ":u6709:": "🈶",
        ":u6e80:": "🈵",
        ":u7121:": "🈚",
        ":u7533:": "🈸",
        ":u7981:": "🈲",
        ":u7a7a:": "🈳",
        ":uganda:": "🇺🇬",
        ":uk:": "🇬🇧",
        ":ukraine:": "🇺🇦",
        ":umbrella:": "☔",
        ":unamused:": "😒",
        ":underage:": "🔞",
        ":unicorn:": "🦄",
        ":united_arab_emirates:": "🇦🇪",
        ":united_nations:": "🇺🇳",
        ":unlock:": "🔓",
        ":up:": "🆙",
        ":upside_down_face:": "🙃",
        ":uruguay:": "🇺🇾",
        ":us:": "🇺🇸",
        ":us_outlying_islands:": "🇺🇲",
        ":us_virgin_islands:": "🇻🇮",
        ":uzbekistan:": "🇺🇿",
        ":v:": "✌️",
        ":vampire:": "🧛",
        ":vampire_man:": "🧛‍♂️",
        ":vampire_woman:": "🧛‍♀️",
        ":vanuatu:": "🇻🇺",
        ":vatican_city:": "🇻🇦",
        ":venezuela:": "🇻🇪",
        ":vertical_traffic_light:": "🚦",
        ":vhs:": "📼",
        ":vibration_mode:": "📳",
        ":video_camera:": "📹",
        ":video_game:": "🎮",
        ":vietnam:": "🇻🇳",
        ":violin:": "🎻",
        ":virgo:": "♍",
        ":volcano:": "🌋",
        ":volleyball:": "🏐",
        ":vomiting_face:": "🤮",
        ":vs:": "🆚",
        ":vulcan_salute:": "🖖",
        ":waffle:": "🧇",
        ":wales:": "🏴󠁧󠁢󠁷󠁬󠁳󠁿",
        ":walking:": "🚶",
        ":walking_man:": "🚶‍♂️",
        ":walking_woman:": "🚶‍♀️",
        ":wallis_futuna:": "🇼🇫",
        ":waning_crescent_moon:": "🌘",
        ":waning_gibbous_moon:": "🌖",
        ":warning:": "⚠️",
        ":wastebasket:": "🗑️",
        ":watch:": "⌚",
        ":water_buffalo:": "🐃",
        ":water_polo:": "🤽",
        ":watermelon:": "🍉",
        ":wave:": "👋",
        ":wavy_dash:": "〰️",
        ":waxing_crescent_moon:": "🌒",
        ":waxing_gibbous_moon:": "🌔",
        ":wc:": "🚾",
        ":weary:": "😩",
        ":wedding:": "💒",
        ":weight_lifting:": "🏋️",
        ":weight_lifting_man:": "🏋️‍♂️",
        ":weight_lifting_woman:": "🏋️‍♀️",
        ":western_sahara:": "🇪🇭",
        ":whale2:": "🐋",
        ":whale:": "🐳",
        ":wheel:": "🛞",
        ":wheel_of_dharma:": "☸️",
        ":wheelchair:": "♿",
        ":white_check_mark:": "✅",
        ":white_circle:": "⚪",
        ":white_flag:": "🏳️",
        ":white_flower:": "💮",
        ":white_haired_man:": "👨‍🦳",
        ":white_haired_woman:": "👩‍🦳",
        ":white_heart:": "🤍",
        ":white_large_square:": "⬜",
        ":white_medium_small_square:": "◽",
        ":white_medium_square:": "◻️",
        ":white_small_square:": "▫️",
        ":white_square_button:": "🔳",
        ":wilted_flower:": "🥀",
        ":wind_chime:": "🎐",
        ":wind_face:": "🌬️",
        ":window:": "🪟",
        ":wine_glass:": "🍷",
        ":wing:": "🪽",
        ":wink:": "😉",
        ":wireless:": "🛜",
        ":wolf:": "🐺",
        ":woman:": "👩",
        ":woman_artist:": "👩‍🎨",
        ":woman_astronaut:": "👩‍🚀",
        ":woman_beard:": "🧔‍♀️",
        ":woman_cartwheeling:": "🤸‍♀️",
        ":woman_cook:": "👩‍🍳",
        ":woman_dancing:": "💃",
        ":woman_facepalming:": "🤦‍♀️",
        ":woman_factory_worker:": "👩‍🏭",
        ":woman_farmer:": "👩‍🌾",
        ":woman_feeding_baby:": "👩‍🍼",
        ":woman_firefighter:": "👩‍🚒",
        ":woman_health_worker:": "👩‍⚕️",
        ":woman_in_manual_wheelchair:": "👩‍🦽",
        ":woman_in_motorized_wheelchair:": "👩‍🦼",
        ":woman_in_tuxedo:": "🤵‍♀️",
        ":woman_judge:": "👩‍⚖️",
        ":woman_juggling:": "🤹‍♀️",
        ":woman_mechanic:": "👩‍🔧",
        ":woman_office_worker:": "👩‍💼",
        ":woman_pilot:": "👩‍✈️",
        ":woman_playing_handball:": "🤾‍♀️",
        ":woman_playing_water_polo:": "🤽‍♀️",
        ":woman_scientist:": "👩‍🔬",
        ":woman_shrugging:": "🤷‍♀️",
        ":woman_singer:": "👩‍🎤",
        ":woman_student:": "👩‍🎓",
        ":woman_teacher:": "👩‍🏫",
        ":woman_technologist:": "👩‍💻",
        ":woman_with_headscarf:": "🧕",
        ":woman_with_probing_cane:": "👩‍🦯",
        ":woman_with_turban:": "👳‍♀️",
        ":woman_with_veil:": "👰‍♀️",
        ":womans_clothes:": "👚",
        ":womans_hat:": "👒",
        ":women_wrestling:": "🤼‍♀️",
        ":womens:": "🚺",
        ":wood:": "🪵",
        ":woozy_face:": "🥴",
        ":world_map:": "🗺️",
        ":worm:": "🪱",
        ":worried:": "😟",
        ":wrench:": "🔧",
        ":wrestling:": "🤼",
        ":writing_hand:": "✍️",
        ":x:": "❌",
        ":x_ray:": "🩻",
        ":yarn:": "🧶",
        ":yawning_face:": "🥱",
        ":yellow_circle:": "🟡",
        ":yellow_heart:": "💛",
        ":yellow_square:": "🟨",
        ":yemen:": "🇾🇪",
        ":yen:": "💴",
        ":yin_yang:": "☯️",
        ":yo_yo:": "🪀",
        ":yum:": "😋",
        ":zambia:": "🇿🇲",
        ":zany_face:": "🤪",
        ":zap:": "⚡",
        ":zebra:": "🦓",
        ":zero:": "0️⃣",
        ":zimbabwe:": "🇿🇼",
        ":zipper_mouth_face:": "🤐",
        ":zombie:": "🧟",
        ":zombie_man:": "🧟‍♂️",
        ":zombie_woman:": "🧟‍♀️",
        ":zzz:": "💤",
    ]

    /// Busca shortcodes que coincidan parcialmente con la query.
    /// Mientras el usuario escribe ":tac" muestra sugerencias como ":taco:", etc.
    public static func searchShortcodes(_ query: String, workspaceEmojiCodes: [String]) -> [(shortcode: String, emoji: String)] {
        let trimmed = query.trimmingCharacters(in: CharacterSet(charactersIn: ": "))
        guard !trimmed.isEmpty else { return [] }

        var searchMap = Self.standardShortcodeMap
        for code in workspaceEmojiCodes where searchMap[code] == nil {
            searchMap[code] = ""
        }

        let lowerQuery = trimmed.lowercased()

        let matches = searchMap.filter { shortcode, _ in
            let stripped = shortcode.trimmingCharacters(in: CharacterSet(charactersIn: ":")).lowercased()
            return stripped.contains(lowerQuery)
        }

        let sorted = matches.sorted { a, b in
            let aS = a.key.trimmingCharacters(in: CharacterSet(charactersIn: ":")).lowercased()
            let bS = b.key.trimmingCharacters(in: CharacterSet(charactersIn: ":")).lowercased()
            let aPrefix = aS.hasPrefix(lowerQuery)
            let bPrefix = bS.hasPrefix(lowerQuery)
            if aPrefix != bPrefix { return aPrefix }
            return aS < bS
        }

        return Array(sorted.prefix(20).map { ($0.key, $0.value) })
    }

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

        // Mapa amplio de emojis unicode → shortcode oficial de Slack.
        // Cubre: emojis default de tareas en Focally, emojis comunes de productividad,
        // y variantes con/sin FE0F (variation selector-16) para máxima compatibilidad.
        let emojiMap: [String: String] = [
            // Emojis default de tareas Focally (FocusStatusOption.common + default tasks)
            "🧠": ":brain:",
            "💻": ":computer:",
            "📝": ":memo:",
            "📚": ":books:",
            "🎯": ":dart:",
            "⚡️": ":zap:",
            "⚡": ":zap:",
            "☕️": ":coffee:",
            "☕": ":coffee:",
            "🍅": ":tomato:",
            "📧": ":email:",
            "✉️": ":email:",
            "✉": ":email:",
            "💌": ":love_letter:",
            "📥": ":inbox_tray:",
            "📤": ":outbox_tray:",
            "📦": ":package:",
            "💪": ":muscle:",
            "🏋️": ":weight_lifter:",
            "🤸": ":cartwheel:",
            "🧘": ":person_in_lotus_position:",
            "📅": ":date:",
            "📆": ":calendar:",
            "🗓️": ":calendar:",
            "🗓": ":calendar:",
            "⏳": ":hourglass_flowing_sand:",
            "⌛️": ":hourglass:",
            "⌛": ":hourglass:",
            "⏰": ":alarm_clock:",
            "⏱️": ":stopwatch:",
            "⏱": ":stopwatch:",
            "🔥": ":fire:",
            "🚀": ":rocket:",
            "✨": ":sparkles:",
            "⭐️": ":star:",
            "⭐": ":star:",
            "🌟": ":star2:",
            "💡": ":bulb:",
            "🔔": ":bell:",
            "🔕": ":no_bell:",
            "📌": ":pushpin:",
            "📍": ":round_pushpin:",
            "📎": ":paperclip:",
            "🔒": ":lock:",
            "🔓": ":unlock:",
            "🔑": ":key:",
            "🛠️": ":hammer_and_pick:",
            "🛠": ":hammer_and_pick:",
            "🔨": ":hammer:",
            "⚙️": ":gear:",
            "⚙": ":gear:",
            "🧩": ":jigsaw:",
            "🎮": ":video_game:",
            "🕹️": ":joystick:",
            "🎧": ":headphones:",
            "🎤": ":microphone:",
            "📞": ":phone:",
            "📱": ":iphone:",
            "🔍": ":mag:",
            "🔎": ":mag_right:",
            "👀": ":eyes:",
            "🤔": ":thinking:",
            "🧐": ":monocle_face:",
            "😎": ":sunglasses:",
            "🥳": ":partying_face:",
            "😴": ":sleeping:",
            "🎉": ":tada:",
            "✅": ":white_check_mark:",
            "☑️": ":ballot_box_with_check:",
            "❌": ":x:",
            "⚠️": ":warning:",
            "⚠": ":warning:",
            "❗️": ":exclamation:",
            "❗": ":exclamation:",
            "❓": ":question:",
            "💯": ":100:",
            "🚫": ":no_entry_sign:",
            "🆗": ":ok:",
            "🆕": ":new:",
            "🆒": ":cool:",
            "🆓": ":free:",
            "🔝": ":top:",
            "💬": ":speech_balloon:",
            "🗨️": ":speech_left:",
            "🗯️": ":anger_right:",
            "❤️": ":heart:",
            "❤": ":heart:",
            "🧡": ":orange_heart:",
            "💛": ":yellow_heart:",
            "💚": ":green_heart:",
            "💙": ":blue_heart:",
            "💜": ":purple_heart:",
            "🖤": ":black_heart:",
            "🤍": ":white_heart:",
            "🤎": ":brown_heart:",
            "👋": ":wave:",
            "👍": ":thumbsup:",
            "👎": ":thumbsdown:",
            "🙏": ":pray:",
            "👏": ":clap:",
            "🤝": ":handshake:",
            "🙌": ":raised_hands:",
            "🫶": ":heart_hands:"
        ]

        // Buscar match exacto en map.
        // Los shortcodes del map son emojis oficiales de Slack y existen en TODOS los
        // workspaces por defecto, así que si hay match lo usamos sin requerir validación
        // extra del workspace (que puede estar vacío o no haberse cargado aún).
        if let shortcode = emojiMap[emoji] {
            // Si conocemos el catálogo del workspace y el shortcode NO está, igualmente
            // preferimos el shortcode oficial: los default emojis siempre están disponibles.
            return shortcode
        }

        // Buscar en workspace por similitud de nombre (fallback)
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

        // Map inverso de shortcodes conocidos a unicode.
        // Sincronizado con convertUnicodeToShortcode. Incluye los shortcodes
        // oficiales de Slack más los custom de Focally.

        // Buscar match exacto en map
        if let emoji = Self.standardShortcodeMap[shortcode] {
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

    public static func isCustomWorkspaceEmoji(_ shortcode: String, workspaceEmojiCodes: [String]) -> Bool {
        let trimmed = shortcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSlackShortcode(trimmed) else { return false }
        return workspaceEmojiCodes.contains(trimmed) && convertShortcodeToUnicode(trimmed, workspaceEmojis: []) == nil
    }

    /// Extrae el nombre base de un emoji unicode (simplificado)
    private static func emojiName(_ emoji: String) -> String {
        // Map ampliado de emojis a nombres de shortcode Slack (para fallback por nombre)
        let names: [String: String] = [
            "🧠": "brain",
            "💻": "computer",
            "📝": "memo",
            "📚": "books",
            "🎯": "dart",
            "⚡": "zap",
            "⚡️": "zap",
            "☕": "coffee",
            "☕️": "coffee",
            "🍅": "tomato",
            "📧": "email",
            "✉️": "email",
            "✉": "email",
            "💌": "love_letter",
            "📥": "inbox_tray",
            "📤": "outbox_tray",
            "📦": "package",
            "💪": "muscle",
            "🏋️": "weight_lifter",
            "🤸": "cartwheel",
            "🧘": "person_in_lotus_position",
            "📅": "date",
            "📆": "calendar",
            "🗓️": "calendar",
            "🗓": "calendar",
            "⏳": "hourglass_flowing_sand",
            "⌛️": "hourglass",
            "⌛": "hourglass",
            "⏰": "alarm_clock",
            "⏱️": "stopwatch",
            "⏱": "stopwatch",
            "🔥": "fire",
            "🚀": "rocket",
            "✨": "sparkles",
            "⭐️": "star",
            "⭐": "star",
            "🌟": "star2",
            "💡": "bulb",
            "🔔": "bell",
            "🔕": "no_bell",
            "📌": "pushpin",
            "📍": "round_pushpin",
            "📎": "paperclip",
            "🔒": "lock",
            "🔓": "unlock",
            "🔑": "key",
            "🛠️": "hammer_and_pick",
            "🛠": "hammer_and_pick",
            "🔨": "hammer",
            "⚙️": "gear",
            "⚙": "gear",
            "🧩": "jigsaw",
            "🎮": "video_game",
            "🕹️": "joystick",
            "🎧": "headphones",
            "🎤": "microphone",
            "📞": "phone",
            "📱": "iphone",
            "🔍": "mag",
            "🔎": "mag_right",
            "👀": "eyes",
            "🤔": "thinking",
            "🧐": "monocle_face",
            "😎": "sunglasses",
            "🥳": "partying_face",
            "😴": "sleeping",
            "🎉": "tada",
            "✅": "white_check_mark",
            "☑️": "ballot_box_with_check",
            "❌": "x",
            "⚠️": "warning",
            "⚠": "warning",
            "❗️": "exclamation",
            "❗": "exclamation",
            "❓": "question",
            "💯": "100",
            "🚫": "no_entry_sign",
            "🆗": "ok",
            "🆕": "new",
            "🆒": "cool",
            "🆓": "free",
            "🔝": "top",
            "💬": "speech_balloon",
            "🗨️": "speech_left",
            "🗯️": "anger_right",
            "❤️": "heart",
            "❤": "heart",
            "🧡": "orange_heart",
            "💛": "yellow_heart",
            "💚": "green_heart",
            "💙": "blue_heart",
            "💜": "purple_heart",
            "🖤": "black_heart",
            "🤍": "white_heart",
            "🤎": "brown_heart",
            "👋": "wave",
            "👍": "thumbsup",
            "👎": "thumbsdown",
            "🙏": "pray",
            "👏": "clap",
            "🤝": "handshake",
            "🙌": "raised_hands",
            "🫶": "heart_hands"
        ]
        return names[emoji] ?? "simple_smile"
    }
}

// MARK: - Emoji Usage Tracker

/// Rastrea el uso de emojis para mostrar sugerencias de recientes
@MainActor
@Observable
public final class EmojiUsageTracker {
    public static let shared = EmojiUsageTracker()

    private static let maxRecentCount = 12
    private static let usageKey = "emojiUsageHistory"

    private(set) public var recentEmojis: [String] = []

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
