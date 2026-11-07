import Foundation
import Observation
import os.log

enum SlackOperationState: Equatable {
    case idle
    case working
    case success(String)
    case failed(String)
}

@Observable
class SlackService {
    typealias RequestPerformer = (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> Void
    typealias EmojiUsageRecorder = (String) -> Void

    static let shared = SlackService()
    static let defaultStatusEmoji = ":hourglass_flowing_sand:"
    static let statusEmojiDefaultsKey = "slackStatusEmoji"
    static let emojiListURL = URL(string: "https://slack.com/api/emoji.list")!
    static let profileSetURL = URL(string: "https://slack.com/api/users.profile.set")!
    static let authTestURL = URL(string: "https://slack.com/api/auth.test")!

    private let enabledDefaults: UserDefaults
    @ObservationIgnored private var suppressEnabledPersistence = false

    var isEnabled: Bool = false {
        didSet {
            guard !suppressEnabledPersistence else { return }
            enabledDefaults.set(isEnabled, forKey: "slackEnabled")
            if isEnabled && token != nil {
                refreshEmojiCatalogIfPossible()
            }
        }
    }
    var isConnected: Bool = false
    var connectionError: String?
    var connectionTestState: SlackOperationState = .idle
    var lastStatusText: String?
    var workspaceEmojiCodes: [String] = []
    var workspaceEmojiImageURLs: [String: String] = [:]
    var lastActionMessage: String?

    private let keychainKey = "slack-token"
    private let logger = Logger.slack
    private let endDndURL = URL(string: "https://slack.com/api/dnd.endSnooze")!
    private let dndSetSnoozeURL = URL(string: "https://slack.com/api/dnd.setSnooze")!
    private let requestPerformer: RequestPerformer?
    private let apiClient: SlackAPIClient
    private let statusService: SlackStatusService
    private let emojiUsageRecorder: EmojiUsageRecorder
    private let testTokenOverride: String??
    private let now: () -> Date
    private let emojiCatalogFreshnessInterval: TimeInterval
    private var emojiRefreshInFlight = false
    private var lastEmojiRefreshAt: Date?
    private var lastEmojiRefreshToken: String?

    var token: String? {
        get {
            if let testTokenOverride {
                return testTokenOverride
            }
            return KeychainHelper.load(key: keychainKey)
        }
        set {
            lastEmojiRefreshAt = nil
            lastEmojiRefreshToken = nil
            apiClient.clearRateLimits()
            workspaceEmojiCodes = []
            workspaceEmojiImageURLs = [:]
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

    // MARK: - Launch Reconnection

    func reconnectOnLaunchIfConfigured(completion: ((Bool) -> Void)? = nil) {
        guard isEnabled,
              let token,
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion?(false)
            return
        }

        logger.info("Validating configured Slack connection on launch. token=\(maskedToken(token))")
        isConnected = false
        testConnection(completion: completion)
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

        guard let request = SlackStatusService.makeSlackRequest(url: endDndURL, token: token, formFields: [:]) else {
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

        guard let request = SlackStatusService.makeSlackRequest(url: SlackService.profileSetURL, token: token, formFields: [
            "profile": SlackStatusService.encodedJSONString(for: profile)
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

    func setStatus(
        text: String,
        expirationTimestamp: Int,
        taskEmoji: String? = nil,
        fallbackEmoji: String? = nil
    ) {
        setStatus(
            text: text,
            expirationTimestamp: expirationTimestamp,
            taskEmoji: taskEmoji,
            fallbackEmoji: fallbackEmoji,
            completion: nil
        )
    }

    func setStatus(
        text: String,
        expirationTimestamp: Int,
        taskEmoji: String? = nil,
        fallbackEmoji: String? = nil,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        let maskedToken = maskedToken(token)
        logger.info("setStatus called. isEnabled=\(self.isEnabled), token=\(maskedToken), text=\(text), taskEmoji=\(taskEmoji ?? "nil"), fallbackEmoji=\(fallbackEmoji ?? "nil"), expirationTimestamp=\(expirationTimestamp)")
        guard isEnabled else {
            logger.info("Skipping setStatus because Slack integration is disabled")
            completion?(.failure(SlackRequestError(message: "Slack integration is disabled")))
            return
        }
        guard let token else {
            logger.error("Skipping setStatus because no Slack token is configured")
            connectionError = "No Slack token configured"
            isConnected = false
            completion?(.failure(SlackRequestError(message: "No Slack token configured")))
            return
        }
        let statusEmoji = normalizedStatusEmoji(in: text, taskEmoji: taskEmoji, fallbackEmoji: fallbackEmoji)

        emojiUsageRecorder(statusEmoji)

        let profile: [String: String] = [
            "status_text": text,
            "status_emoji": statusEmoji,
            "status_expiration": "\(expirationTimestamp)"
        ]

        statusService.setProfile(profile: profile, token: token) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .failure(let error):
                    let message = error.displayMessage
                    self.connectionError = message
                    self.isConnected = false
                    self.logger.error("Slack setStatus failed. userMessage=\(message)")
                    completion?(.failure(SlackRequestError(message: message)))
                case .success:
                    self.isConnected = true
                    self.connectionError = nil
                    self.lastStatusText = text
                    self.logger.info("Slack status set successfully: \(statusEmoji) \(text)")
                    completion?(.success(()))
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

        statusService.setProfile(profile: profile, token: token) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .failure(let error):
                    self.logger.error("Slack clearStatus failed. userMessage=\(error.displayMessage)")
                case .success:
                    self.lastStatusText = nil
                    self.logger.info("Slack status cleared")
                }
            }
        }
    }

    func testConnection(completion: ((Bool) -> Void)? = nil) {
        guard connectionTestState != .working else { return }
        connectionTestState = .working

        logger.info("testConnection called. isEnabled=\(self.isEnabled), token=\(self.maskedToken(self.token))")
        guard token != nil else {
            connectionError = "No token configured"
            isConnected = false
            connectionTestState = .failed("No token configured")
            logger.error("Slack testConnection failed because no token is configured")
            completion?(false)
            return
        }

        validateToken(completion: completion)
    }

    // MARK: - Init

    private init() {
        self.enabledDefaults = .standard
        self.requestPerformer = nil
        self.apiClient = SlackAPIClient(now: Date.init)
        self.statusService = SlackStatusService(client: apiClient)
        self.emojiUsageRecorder = { statusEmoji in
            // Registrar uso del emoji (async para evitar conflicto con @MainActor)
            Task { @MainActor in
                EmojiUsageTracker.shared.recordUsage(statusEmoji)
            }
        }
        self.testTokenOverride = nil
        self.now = Date.init
        self.emojiCatalogFreshnessInterval = 3_600
        self.suppressEnabledPersistence = true
        self.isEnabled = UserDefaults.standard.bool(forKey: "slackEnabled")
        self.suppressEnabledPersistence = false
        // Load the saved token, but do not claim connectivity before launch auth.test.
        if let savedToken = token, !savedToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.isConnected = false
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

    init(
        tokenForTesting: String?,
        enabled: Bool = false,
        enabledDefaults: UserDefaults = .standard,
        requestPerformer: @escaping RequestPerformer,
        emojiUsageRecorder: @escaping EmojiUsageRecorder = { _ in },
        now: @escaping () -> Date = Date.init,
        emojiCatalogFreshnessInterval: TimeInterval = 3_600
    ) {
        self.enabledDefaults = enabledDefaults
        self.requestPerformer = requestPerformer
        self.apiClient = SlackAPIClient(transport: requestPerformer, now: now)
        self.statusService = SlackStatusService(client: apiClient)
        self.emojiUsageRecorder = emojiUsageRecorder
        self.testTokenOverride = .some(tokenForTesting)
        self.now = now
        self.emojiCatalogFreshnessInterval = emojiCatalogFreshnessInterval
        self.suppressEnabledPersistence = true
        self.isEnabled = enabled
        self.suppressEnabledPersistence = false
    }

    func refreshEmojiCatalogIfPossible(force: Bool = false) {
        guard let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.info("Skipping emoji catalog refresh: no token available")
            workspaceEmojiCodes = []
            workspaceEmojiImageURLs = [:]
            return
        }

        let timestamp = now()
        let emojiMethod = SlackAPIClient.methodKey(for: Self.emojiListURL)
        if let blockedUntil = apiClient.blockedUntil(method: emojiMethod), blockedUntil > timestamp {
            connectionError = "Too many requests. Please wait a moment and try again."
            logger.info("Skipping Slack emoji catalog refresh until Retry-After deadline")
            return
        }
        guard !emojiRefreshInFlight else {
            logger.info("Skipping Slack emoji catalog refresh: request already in flight")
            return
        }
        if !force,
           let lastEmojiRefreshAt,
           lastEmojiRefreshToken == token,
           timestamp.timeIntervalSince(lastEmojiRefreshAt) < emojiCatalogFreshnessInterval {
            logger.info("Skipping Slack emoji catalog refresh: cached catalog is fresh")
            return
        }

        logger.info("Refreshing Slack emoji catalog (enabled=\(self.isEnabled), token length=\(token.count))...")

        guard let request = SlackStatusService.makeSlackRequest(url: Self.emojiListURL, token: token, formFields: [:]) else {
            logger.error("Failed to prepare Slack emoji.list request")
            connectionError = "Failed to prepare emoji catalog request"
            return
        }

        emojiRefreshInFlight = true
        performSlackRequest(request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.emojiRefreshInFlight = false

                guard self.token == token else {
                    self.logger.info("Discarding Slack emoji catalog response because the token changed")
                    self.refreshEmojiCatalogIfPossible(force: true)
                    return
                }

                if let error {
                    let errorType = SlackService.categorizeNetworkError(error)
                    self.logger.error("Slack emoji.list request failed: \(error.localizedDescription), categorized as: \(errorType)")
                    self.connectionError = errorType
                    return
                }

                let httpResponse = response as? HTTPURLResponse
                let statusCode = httpResponse?.statusCode ?? -1
                if statusCode == 429 {
                    let retryAfter = TimeInterval(httpResponse?.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 60
                    self.connectionError = SlackService.userFriendlyError(for: statusCode, slackError: "ratelimited")
                    self.logger.warning("Slack emoji.list rate limited; honoring Retry-After=\(retryAfter) seconds")
                    return
                }

                guard let json = self.decodeSlackResponseBody(data) else {
                    self.logger.error("Slack emoji.list failed to decode response")
                    self.connectionError = "Emoji catalog: failed to decode response"
                    return
                }

                guard let responseOK = json["ok"] as? Bool,
                      responseOK,
                      (200...299).contains(statusCode) else {
                    let errorDetail: String = json["error"] as? String ?? "Unknown error"
                    let userFriendlyError = SlackService.userFriendlyError(
                        for: statusCode,
                        slackError: errorDetail
                    )
                    self.logger.error("Slack emoji.list returned not ok: \(errorDetail), httpStatus=\(statusCode), userMessage=\(userFriendlyError)")
                    self.connectionError = userFriendlyError
                    return
                }

                guard let emojiMap = json["emoji"] as? [String: String] else {
                    self.logger.error("Slack emoji.list missing emoji field")
                    self.connectionError = "Emoji catalog response missing emoji field"
                    return
                }

                let codes = emojiMap.keys
                    .map { ":\($0):" }
                    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                let imageURLs = Self.workspaceEmojiImageURLs(from: emojiMap)

                self.workspaceEmojiCodes = codes
                self.workspaceEmojiImageURLs = imageURLs
                self.lastEmojiRefreshAt = self.now()
                self.lastEmojiRefreshToken = token
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

        guard let request = SlackStatusService.makeSlackRequest(url: dndSetSnoozeURL, token: token, formFields: [
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

    func validateToken(completion: ((Bool) -> Void)? = nil) {
        guard let token else {
            connectionError = "No token configured"
            isConnected = false
            connectionTestState = .failed("No token configured")
            logger.error("validateToken called without a token")
            completion?(false)
            return
        }

        logger.info("validateToken called. token=\(self.maskedToken(token))")

        statusService.validateToken(token) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .failure(let error):
                    let message = error.displayMessage
                    self.connectionError = message
                    self.isConnected = false
                    self.connectionTestState = .failed(message)
                    self.logger.error("Slack auth.test failed. userMessage=\(message)")
                    completion?(false)
                case .success(let outcome):
                    if outcome.ok {
                        if token.hasPrefix("xoxp-") {
                            self.isConnected = true
                            self.connectionError = nil
                            self.connectionTestState = .success("Connected ✓")
                            self.refreshEmojiCatalogIfPossible()
                            self.logger.info("Slack auth.test succeeded for a user token")
                            completion?(true)
                        } else {
                            self.isConnected = false
                            self.connectionError = "Slack status updates require a user token (xoxp-) with users.profile:write"
                            self.connectionTestState = .failed("Slack status updates require a user token (xoxp-) with users.profile:write")
                            self.logger.error("Slack auth.test succeeded but token type is not a user token")
                            completion?(false)
                        }
                    } else {
                        let errorMsg: String = outcome.slackError ?? "Unknown error"
                        let userFriendlyError = SlackError.userFriendlyMessage(for: outcome.httpStatus, slackError: errorMsg)
                        self.connectionError = userFriendlyError
                        self.isConnected = false
                        self.connectionTestState = .failed(userFriendlyError)
                        self.logger.error("Slack auth.test failed. httpStatus=\(outcome.httpStatus), error=\(errorMsg), userMessage=\(userFriendlyError)")
                        completion?(false)
                    }
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

    private func performSlackRequest(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        apiClient.perform(request, completion: completion)
    }

    private func decodeSlackResponseBody(_ data: Data?) -> [String: Any]? {
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("Failed to decode Slack response body")
            return nil
        }
        return json
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
    fileprivate static func categorizeNetworkError(_ error: Error) -> String {
        SlackError.networkMessage(error)
    }

    /// Convierte errores de Slack en mensajes amigables para el usuario
    fileprivate static func userFriendlyError(for statusCode: Int, slackError: String) -> String {
        SlackError.userFriendlyMessage(for: statusCode, slackError: slackError)
    }

    static func localizedOperationError(
        _ message: String,
        localizedString: (String) -> String
    ) -> String {
        let exactKeys: [String: String] = [
            "Slack integration is disabled": "slack_error_integration_disabled",
            "No Slack token configured": "slack_error_no_token",
            "No token configured": "slack_error_no_token",
            "Failed to prepare Slack status request": "slack_error_prepare_status_request",
            "Failed to prepare Slack auth.test request": "slack_error_prepare_connection_request",
            "Invalid response from Slack": "slack_error_invalid_response",
            "No internet connection": "slack_error_no_internet",
            "Network request timed out": "slack_error_network_timeout",
            "Cannot connect to Slack server": "slack_error_cannot_connect",
            "Cannot find Slack server": "slack_error_cannot_find_server",
            "Invalid Slack token. Please check your token and try again.": "slack_error_invalid_token",
            "Access denied. Your token may not have the required permissions.": "slack_error_access_denied",
            "Too many requests. Please wait a moment and try again.": "slack_error_rate_limited",
            "Your token is missing required permissions.": "slack_error_missing_permissions",
            "Your Slack account is inactive.": "slack_error_account_inactive",
            "Your Slack token has been revoked.": "slack_error_token_revoked",
            "Your Slack workspace requires login.": "slack_error_workspace_login",
            "Slack status updates require a user token (xoxp-) with users.profile:write": "slack_error_user_token_required"
        ]

        if let key = exactKeys[message] {
            return localizedString(key)
        }

        return localizedOperationError(
            message,
            prefix: "Network error: ",
            key: "slack_error_network_format",
            localizedString: localizedString
        ) ?? localizedOperationError(
            message,
            prefix: "Slack API error: ",
            key: "slack_error_api_format",
            localizedString: localizedString
        ) ?? message
    }

    private static func localizedOperationError(
        _ message: String,
        prefix: String,
        key: String,
        localizedString: (String) -> String
    ) -> String? {
        guard message.hasPrefix(prefix) else { return nil }
        let detail = String(message.dropFirst(prefix.count))
        return String(format: localizedString(key), detail)
    }
}

private struct SlackRequestError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}
