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
    static let usersProfileGetURL = URL(string: "https://slack.com/api/users.profile.get")!
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

    /// slack-presence-sync 6.3: releasing a Slack DND snooze is left to its
    /// NATURAL expiration. Calling `dnd.endSnooze` as a release path is
    /// prohibited (it would also kill a snooze the user set manually).
    func disableSlackDND() {
        logger.info("disableSlackDND: letting Slack snooze expire naturally (endSnooze forbidden as release)")
        lastActionMessage = "Slack notifications resume when the snooze expires"
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
        // slack-presence-sync 6.5: Slack caps status_text at 100 chars.
        let effectiveText = Self.truncatedStatusText(text)
        // 6.5: backup expiration so the status never outlives the call even if
        // Focally dies: any past timestamp becomes now + margin.
        let nowEpoch = Int(now().timeIntervalSince1970)
        let effectiveExpiration = expirationTimestamp > nowEpoch
            ? expirationTimestamp
            : nowEpoch + Self.backupExpirationMarginSeconds

        emojiUsageRecorder(statusEmoji)

        let profile: [String: String] = [
            "status_text": effectiveText,
            "status_emoji": statusEmoji,
            "status_expiration": "\(effectiveExpiration)"
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
                    self.lastStatusText = effectiveText
                    // 6.1: remember what Focally set — restore only ever runs
                    // while this exact status is still live on the profile.
                    self.focallySetStatus = SlackStatusSnapshot(
                        statusText: effectiveText,
                        statusEmoji: statusEmoji,
                        statusExpiration: effectiveExpiration
                    )
                    self.logger.info("Slack status set successfully: \(statusEmoji) \(effectiveText)")
                    completion?(.success(()))
                }
            }
        }
    }

    func clearStatus() {
        clearStatus(attempt: 1)
    }

    /// call-reliability 4.4: `clearStatus` retries with a short backoff (≥2
    /// attempts) on network/rate-limit failure before giving up.
    static let clearStatusMaxAttempts = 2
    static let clearStatusRetryDelaySeconds: TimeInterval = 2
    /// 4.4: injectable backoff sleep between clearStatus retries (tests zero it).
    private let clearStatusRetryDelay: (TimeInterval) async -> Void

    private func clearStatus(attempt: Int) {
        let maskedToken = maskedToken(token)
        logger.info("clearStatus called. isEnabled=\(self.isEnabled), token=\(maskedToken), attempt=\(attempt)")
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
                    self.logger.error("Slack clearStatus failed. userMessage=\(error.displayMessage), attempt=\(attempt)")
                    if attempt < Self.clearStatusMaxAttempts {
                        Task { [weak self] in
                            await self?.clearStatusRetryDelay(Self.clearStatusRetryDelaySeconds)
                            self?.clearStatus(attempt: attempt + 1)
                        }
                    }
                case .success:
                    self.lastStatusText = nil
                    // 6.1: an empty profile is still a status Focally owns —
                    // restore is allowed from here.
                    self.focallySetStatus = SlackStatusSnapshot(
                        statusText: "",
                        statusEmoji: "",
                        statusExpiration: nil
                    )
                    self.logger.info("Slack status cleared")
                }
            }
        }
    }

    // MARK: slack-presence-sync 6.1 — save & restore the user's status

    struct SlackStatusSnapshot: Equatable {
        let statusText: String
        let statusEmoji: String
        let statusExpiration: Int?
    }

    /// Slack API cap on `status_text` (slack-presence-sync 6.5).
    static let statusTextLimit = 100
    /// Backup expiration margin when the estimated end is already past (6.5).
    static let backupExpirationMarginSeconds = 300

    static func truncatedStatusText(_ text: String, limit: Int = statusTextLimit) -> String {
        String(text.prefix(limit))
    }

    /// 6.5: only user tokens (xoxp-) may write profiles. Logged as a warning —
    /// Slack itself rejects workspace/bot tokens with a user-facing error.
    static func isValidUserToken(_ token: String) -> Bool {
        token.hasPrefix("xoxp-")
    }

    /// The status currently saved for restore (the user's own status at call start).
    private(set) var savedStatusSnapshot: SlackStatusSnapshot?
    /// The status Focally itself last set ("" / "" once cleared). Restore only
    /// runs while the live profile still matches this — a manual mid-call
    /// change by the user is never overwritten.
    private(set) var focallySetStatus: SlackStatusSnapshot?

    /// 6.1: fetch and remember the current status before Focally overwrites it.
    func saveCurrentStatus(completion: ((SlackStatusSnapshot?) -> Void)? = nil) {
        fetchCurrentProfile { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.savedStatusSnapshot = snapshot
                completion?(snapshot)
            }
        }
    }

    /// 6.1: restore the saved status, but ONLY if the live profile is still the
    /// status Focally set (check before restore).
    func restoreSavedStatus(completion: ((Bool) -> Void)? = nil) {
        guard let saved = savedStatusSnapshot else {
            completion?(false)
            return
        }
        fetchCurrentProfile { [weak self] current in
            DispatchQueue.main.async {
                guard let self else { completion?(false); return }
                guard current == self.focallySetStatus else {
                    self.logger.info("Slack status restore skipped: live status was changed after Focally set it")
                    completion?(false)
                    return
                }
                var profile = [
                    "status_text": saved.statusText,
                    "status_emoji": saved.statusEmoji
                ]
                if let expiration = saved.statusExpiration {
                    profile["status_expiration"] = "\(expiration)"
                }
                guard let token = self.token else { completion?(false); return }
                self.statusService.setProfile(profile: profile, token: token) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .failure(let error):
                            self.logger.error("Slack status restore failed. userMessage=\(error.displayMessage)")
                            completion?(false)
                        case .success:
                            self.lastStatusText = saved.statusText.isEmpty ? nil : saved.statusText
                            self.focallySetStatus = saved
                            self.logger.info("Slack status restored: \(saved.statusEmoji) \(saved.statusText)")
                            completion?(true)
                        }
                    }
                }
            }
        }
    }

    /// 6.2: checks the live profile against the status Focally last set. A
    /// fetch failure conservatively reports "still live" (no false pause).
    func confirmFocallyStatusStillLive(completion: @escaping (Bool) -> Void) {
        fetchCurrentProfile { [weak self] current in
            DispatchQueue.main.async {
                guard let self else { completion(false); return }
                completion(current == nil || current == self.focallySetStatus)
            }
        }
    }

    /// call-reliability 4.3: blocking status clear for the terminate path
    /// (≤ timeoutSeconds, real URLSession — the process is dying).
    @discardableResult
    func clearStatusSynchronously(timeoutSeconds: TimeInterval) -> Bool {
        guard isEnabled, let token else { return false }
        var request = URLRequest(url: Self.profileSetURL, timeoutInterval: timeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"profile":{"status_text":"","status_emoji":""}}"#.utf8)
        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        URLSession.shared.dataTask(with: request) { _, response, _ in
            ok = ((response as? HTTPURLResponse)?.statusCode == 200)
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + timeoutSeconds + 0.5)
        return ok
    }

    private func fetchCurrentProfile(completion: @escaping (SlackStatusSnapshot?) -> Void) {
        guard isEnabled, let token else {
            completion(nil)
            return
        }
        guard let request = SlackStatusService.makeSlackRequest(url: Self.usersProfileGetURL, token: token, formFields: [:]) else {
            completion(nil)
            return
        }
        performSlackRequest(request) { [weak self] data, response, error in
            guard let self else { completion(nil); return }
            if let error = error {
                self.logger.error("Slack users.profile.get failed: \(error.localizedDescription)")
                completion(nil)
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200...299).contains(statusCode),
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["ok"] as? Bool == true,
                  let profile = json["profile"] as? [String: Any] else {
                self.logger.error("Slack users.profile.get returned invalid response. httpStatus=\(statusCode)")
                completion(nil)
                return
            }
            completion(SlackStatusSnapshot(
                statusText: profile["status_text"] as? String ?? "",
                statusEmoji: profile["status_emoji"] as? String ?? "",
                // Slack encodes status_expiration as a JSON number, but it may
                // arrive as a numeric string (e.g. echoed from a form-encoded
                // profile.set) — accept both or snapshot comparisons break.
                statusExpiration: (profile["status_expiration"] as? Int)
                    ?? (profile["status_expiration"] as? String).flatMap(Int.init)
            ))
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
        self.clearStatusRetryDelay = { seconds in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
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
        emojiCatalogFreshnessInterval: TimeInterval = 3_600,
        clearStatusRetryDelay: @escaping (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.enabledDefaults = enabledDefaults
        self.requestPerformer = requestPerformer
        self.apiClient = SlackAPIClient(transport: requestPerformer, now: now)
        self.statusService = SlackStatusService(client: apiClient)
        self.emojiUsageRecorder = emojiUsageRecorder
        self.testTokenOverride = .some(tokenForTesting)
        self.now = now
        self.emojiCatalogFreshnessInterval = emojiCatalogFreshnessInterval
        self.clearStatusRetryDelay = clearStatusRetryDelay
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
