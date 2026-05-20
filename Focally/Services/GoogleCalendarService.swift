import AppKit
import AuthenticationServices
import Foundation

final class GoogleCalendarService: NSObject, ObservableObject {
    static let shared = GoogleCalendarService()
    static let calendarReadonlyScope: String = "https://www.googleapis.com/auth/calendar.readonly"
    static let enabledDefaultsKey: String = "googleCalendarEnabled"
    static let tokenExpirationDefaultsKey: String = "googleCalendarTokenExpiration"
    static let clientIDKey: String = "google-calendar-client-id"
    static let clientSecretKey: String = "google-calendar-client-secret"
    static let accessTokenKey: String = "google-calendar-access-token"
    static let refreshTokenKey: String = "google-calendar-refresh-token"
    static let authURLString: String = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenURLString: String = "https://oauth2.googleapis.com/token"
    static let redirectURI: String = "http://localhost"

    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledDefaultsKey)
            if !isEnabled {
                events = []
            }
        }
    }
    @Published var isSignedIn: Bool = false
    @Published var events: [CalendarEvent] = []
    @Published var connectionError: String?

    var currentMeeting: CalendarEvent? {
        let now = Date()
        return events.first { now >= $0.startTime && now < $0.endTime }
    }

    var clientID: String? {
        KeychainHelper.load(key: Self.clientIDKey)
    }

    var clientSecret: String? {
        KeychainHelper.load(key: Self.clientSecretKey)
    }

    var authSession: ASWebAuthenticationSession?
    let urlSession: URLSession
    var accessToken: String? {
        get { KeychainHelper.load(key: Self.accessTokenKey) }
        set {
            if let newValue, !newValue.isEmpty {
                KeychainHelper.save(key: Self.accessTokenKey, value: newValue)
            } else {
                KeychainHelper.delete(key: Self.accessTokenKey)
            }
        }
    }
    var refreshToken: String? {
        get { KeychainHelper.load(key: Self.refreshTokenKey) }
        set {
            if let newValue, !newValue.isEmpty {
                KeychainHelper.save(key: Self.refreshTokenKey, value: newValue)
            } else {
                KeychainHelper.delete(key: Self.refreshTokenKey)
            }
        }
    }
    var tokenExpirationDate: Date? {
        get {
            let value: Double = UserDefaults.standard.double(forKey: Self.tokenExpirationDefaultsKey)
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

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        super.init()
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
        isSignedIn = accessToken != nil || refreshToken != nil
    }

    func saveClientCredentials(clientID: String, clientSecret: String) {
        let trimmedClientID: String = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClientSecret: String = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

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
}
