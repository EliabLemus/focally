import AppKit
import AuthenticationServices
import Foundation

final class GoogleCalendarService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let calendarReadonlyScope = "https://www.googleapis.com/auth/calendar.readonly"

    @Published var isEnabled = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledDefaultsKey)
            if !isEnabled {
                events = []
            }
        }
    }
    @Published var isSignedIn = false
    @Published var events: [CalendarEvent] = []
    @Published var connectionError: String?

    /// The calendar event currently in progress, if any.
    var currentMeeting: CalendarEvent? {
        let now = Date()
        return events.first { now >= $0.startTime && now < $0.endTime }
    }

    private static let enabledDefaultsKey = "googleCalendarEnabled"
    private static let tokenExpirationDefaultsKey = "googleCalendarTokenExpiration"
    private static let clientIDKey = "google-calendar-client-id"
    private static let clientSecretKey = "google-calendar-client-secret"
    private static let accessTokenKey = "google-calendar-access-token"
    private static let refreshTokenKey = "google-calendar-refresh-token"
    private static let authURLString = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenURLString = "https://oauth2.googleapis.com/token"
    private static let redirectURI = "http://localhost"

    private var authSession: ASWebAuthenticationSession?
    private let urlSession: URLSession

    var clientID: String? {
        KeychainHelper.load(key: Self.clientIDKey)
    }

    var clientSecret: String? {
        KeychainHelper.load(key: Self.clientSecretKey)
    }

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        super.init()
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
        isSignedIn = accessToken != nil || refreshToken != nil
    }

    func saveClientCredentials(clientID: String, clientSecret: String) {
        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedClientID.isEmpty {
            KeychainHelper.delete(key: Self.clientIDKey)
        } else {
            KeychainHelper.save(key: Self.clientIDKey, value: trimmedClientID)
        }

        if trimmedClientSecret.isEmpty {
            KeychainHelper.delete(key: Self.clientSecretKey)
        } else {
            KeychainHelper.save(key: Self.clientSecretKey, value: trimmedClientSecret)
        }
    }

    func signIn() {
        guard isEnabled else {
            connectionError = "Enable Google Calendar first"
            return
        }

        guard let clientID, !clientID.isEmpty, let clientSecret, !clientSecret.isEmpty else {
            connectionError = "Missing Google Client ID or Client Secret"
            return
        }

        var components = URLComponents(string: Self.authURLString)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.calendarReadonlyScope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components?.url else {
            connectionError = "Could not build Google auth URL"
            return
        }

        connectionError = nil

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "http"
        ) { [weak self] callbackURL, error in
            guard let self else { return }

            if let error {
                Task { @MainActor [weak self] in
                    self?.connectionError = error.localizedDescription
                }
                return
            }

            guard let callbackURL,
                  let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                Task { @MainActor [weak self] in
                    self?.connectionError = "Missing Google auth callback"
                }
                return
            }

            if let authError = components.queryItems?.first(where: { $0.name == "error" })?.value {
                Task { @MainActor [weak self] in
                    self?.connectionError = authError
                }
                return
            }

            guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                Task { @MainActor [weak self] in
                    self?.connectionError = "Missing Google auth code"
                }
                return
            }

            Task { @MainActor [weak self] in
                await self?.exchangeAuthorizationCodeForTokens(code)
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        authSession = session

        if !session.start() {
            connectionError = "Could not start Google sign-in"
        }
    }

    func signOut() {
        KeychainHelper.delete(key: Self.accessTokenKey)
        KeychainHelper.delete(key: Self.refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: Self.tokenExpirationDefaultsKey)
        events = []
        isSignedIn = false
        connectionError = nil
    }

    func fetchTodayEvents(completion: (() -> Void)? = nil) {
        Task { @MainActor [weak self] in
            defer { completion?() }
            await self?.fetchTodayEventsInternal(forceRefreshAfterUnauthorized: true)
        }
    }

    func checkConflict(during session: DateInterval) -> CalendarEvent? {
        events.first { event in
            let eventInterval = DateInterval(start: event.startTime, end: event.endTime)
            return eventInterval.intersects(session)
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
    }

    private var accessToken: String? {
        get { KeychainHelper.load(key: Self.accessTokenKey) }
        set {
            if let newValue, !newValue.isEmpty {
                KeychainHelper.save(key: Self.accessTokenKey, value: newValue)
            } else {
                KeychainHelper.delete(key: Self.accessTokenKey)
            }
        }
    }

    private var refreshToken: String? {
        get { KeychainHelper.load(key: Self.refreshTokenKey) }
        set {
            if let newValue, !newValue.isEmpty {
                KeychainHelper.save(key: Self.refreshTokenKey, value: newValue)
            } else {
                KeychainHelper.delete(key: Self.refreshTokenKey)
            }
        }
    }

    private var tokenExpirationDate: Date? {
        get {
            let value = UserDefaults.standard.double(forKey: Self.tokenExpirationDefaultsKey)
            guard value > 0 else { return nil }
            return Date(timeIntervalSince1970: value)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: Self.tokenExpirationDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.tokenExpirationDefaultsKey)
            }
        }
    }

    private func exchangeAuthorizationCodeForTokens(_ code: String) async {
        guard let clientID, let clientSecret else {
            connectionError = "Missing Google Client ID or Client Secret"
            return
        }

        let parameters = [
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": Self.redirectURI,
            "grant_type": "authorization_code"
        ]

        do {
            let tokenResponse: GoogleTokenResponse = try await sendTokenRequest(parameters: parameters)
            persistTokenResponse(tokenResponse, preserveRefreshToken: false)
            connectionError = nil
            isSignedIn = true
            fetchTodayEvents()
        } catch {
            connectionError = error.localizedDescription
            isSignedIn = false
        }
    }

    private func refreshAccessTokenIfNeeded() async -> Bool {
        if let tokenExpirationDate, tokenExpirationDate > Date().addingTimeInterval(60), accessToken != nil {
            return true
        }

        guard let refreshToken, let clientID, let clientSecret else {
            return accessToken != nil
        }

        let parameters = [
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret,
            "grant_type": "refresh_token"
        ]

        do {
            let tokenResponse: GoogleTokenResponse = try await sendTokenRequest(parameters: parameters)
            persistTokenResponse(tokenResponse, preserveRefreshToken: true)
            connectionError = nil
            isSignedIn = true
            return true
        } catch {
            signOut()
            connectionError = error.localizedDescription
            return false
        }
    }

    private func fetchTodayEventsInternal(forceRefreshAfterUnauthorized: Bool) async {
        guard isEnabled else {
            events = []
            return
        }

        guard isSignedIn else {
            connectionError = "Google Calendar not connected"
            events = []
            return
        }

        guard await refreshAccessTokenIfNeeded(), let accessToken else {
            connectionError = "Google Calendar authentication expired"
            events = []
            return
        }

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")
        components?.queryItems = [
            URLQueryItem(name: "timeMin", value: Self.googleDateTimeFormatter.string(from: startOfToday)),
            URLQueryItem(name: "timeMax", value: Self.googleDateTimeFormatter.string(from: endOfToday)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        guard let url = components?.url else {
            connectionError = "Could not build Google Calendar request"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                connectionError = "Invalid Google Calendar response"
                return
            }

            if httpResponse.statusCode == 401, forceRefreshAfterUnauthorized {
                let refreshed = await refreshAccessTokenIfNeeded()
                if refreshed {
                    await fetchTodayEventsInternal(forceRefreshAfterUnauthorized: false)
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                connectionError = "Google Calendar request failed (\(httpResponse.statusCode))"
                return
            }

            let payload = try JSONDecoder().decode(GoogleCalendarEventsResponse.self, from: data)
            events = payload.items.compactMap(Self.makeCalendarEvent(from:))
            connectionError = nil
        } catch {
            connectionError = error.localizedDescription
        }
    }

    private func sendTokenRequest<T: Decodable>(parameters: [String: String]) async throws -> T {
        guard let url = URL(string: Self.tokenURLString) else {
            throw GoogleCalendarServiceError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters
            .map { key, value in
                let escapedKey = Self.formURLEncodedValue(for: key)
                let escapedValue = Self.formURLEncodedValue(for: value)
                return "\(escapedKey)=\(escapedValue)"
            }
            .sorted()
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let tokenError = try? JSONDecoder().decode(GoogleTokenErrorResponse.self, from: data) {
                throw GoogleCalendarServiceError.apiError(tokenError.errorDescription ?? tokenError.error)
            }
            throw GoogleCalendarServiceError.apiError("Request failed (\(httpResponse.statusCode))")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func persistTokenResponse(_ tokenResponse: GoogleTokenResponse, preserveRefreshToken: Bool) {
        accessToken = tokenResponse.accessToken
        if let refreshToken = tokenResponse.refreshToken {
            self.refreshToken = refreshToken
        } else if !preserveRefreshToken {
            self.refreshToken = nil
        }
        tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        isSignedIn = true
    }

    private static func makeCalendarEvent(from item: GoogleCalendarItem) -> CalendarEvent? {
        guard let start = parseEventDate(from: item.start) else {
            return nil
        }

        guard let end = parseEventDate(from: item.end) else {
            return nil
        }

        let isAllDay = item.start.date != nil

        return CalendarEvent(
            id: item.id,
            title: item.summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.summary! : "Untitled Event",
            startTime: start,
            endTime: end,
            isAllDay: isAllDay,
            meetLink: item.hangoutLink
        )
    }

    private static func parseEventDate(from value: GoogleCalendarDateValue) -> Date? {
        if let dateTime = value.dateTime {
            return googleDateTimeFormatter.date(from: dateTime) ?? googleDateTimeFallbackFormatter.date(from: dateTime)
        }

        guard let dateOnly = value.date, let date = googleDayFormatter.date(from: dateOnly) else {
            return nil
        }

        return Calendar.current.startOfDay(for: date)
    }

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var endOfToday: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfToday) ?? Date()
    }

    private static let googleDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = .current
        return formatter
    }()

    private static let googleDateTimeFallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = .current
        return formatter
    }()

    private static let googleDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    private static let formURLEncodedAllowedCharacters: CharacterSet = {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._*")
        return allowed
    }()

    private static func formURLEncodedValue(for string: String) -> String {
        let escaped = string.addingPercentEncoding(withAllowedCharacters: formURLEncodedAllowedCharacters) ?? string
        return escaped.replacingOccurrences(of: " ", with: "+")
    }
}

private struct GoogleTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

private struct GoogleTokenErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

private struct GoogleCalendarEventsResponse: Decodable {
    let items: [GoogleCalendarItem]
}

private struct GoogleCalendarItem: Decodable {
    let id: String
    let summary: String?
    let start: GoogleCalendarDateValue
    let end: GoogleCalendarDateValue
    let hangoutLink: String?
}

private struct GoogleCalendarDateValue: Decodable {
    let date: String?
    let dateTime: String?

    enum CodingKeys: String, CodingKey {
        case date
        case dateTime
    }
}

private enum GoogleCalendarServiceError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Could not build Google request"
        case .invalidResponse:
            return "Invalid Google response"
        case .apiError(let message):
            return message
        }
    }
}
