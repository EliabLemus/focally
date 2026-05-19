import AppKit
import AuthenticationServices
import Foundation
import GoogleCalendarModels

// MARK: - Authentication

extension GoogleCalendarService {
    func signIn() {
        guard isEnabled else {
            connectionError = "Enable Google Calendar first"
            return
        }

        guard let clientID: String, !clientID.isEmpty, let clientSecret: String, !clientSecret.isEmpty else {
            connectionError = "Missing Google Client ID or Client Secret"
            return
        }

        guard let authURL = buildAuthURL(clientID: clientID) else {
            connectionError = "Could not build Google auth URL"
            return
        }

        connectionError = nil

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "http"
        ) { [weak self] callbackURL, error in
            self?.handleAuthCallback(callbackURL, error: error)
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        authSession = session

        if !session.start() {
            connectionError = "Could not start Google sign-in"
        }
    }

    private func buildAuthURL(clientID: String) -> URL? {
        let components: URLComponents? = URLComponents(string: Self.authURLString)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.calendarReadonlyScope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components?.url
    }

    private func handleAuthCallback(_ callbackURL: URL?, error: (any Error)?) {
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

        if let authError: String = components.queryItems?.first(where: { $0.name == "error" })?.value {
            Task { @MainActor [weak self] in
                self?.connectionError = authError
            }
            return
        }

        guard let code: String = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            Task { @MainActor [weak self] in
                self?.connectionError = "Missing Google auth code"
            }
            return
        }

        Task { @MainActor [weak self] in
            await self?.exchangeAuthorizationCodeForTokens(code)
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

    private func exchangeAuthorizationCodeForTokens(_ code: String) async {
        guard let clientID: String, let clientSecret: String else {
            connectionError = "Missing Google Client ID or Client Secret"
            return
        }

        let parameters: [String: String] = [
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
        let tokenIsValid: Bool = {
            guard let tokenExpirationDate, tokenExpirationDate > Date().addingTimeInterval(60), accessToken != nil else {
                return false
            }
            return true
        }()

        if tokenIsValid {
            return true
        }

        guard let refreshToken: String, let clientID: String, let clientSecret: String else {
            return accessToken != nil
        }

        let parameters: [String: String] = [
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
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleCalendarService: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
    }
}
