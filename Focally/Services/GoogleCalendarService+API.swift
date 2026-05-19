import Foundation

// MARK: - API Requests

extension GoogleCalendarService {
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
}
