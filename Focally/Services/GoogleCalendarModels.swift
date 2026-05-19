import Foundation

// MARK: - Private Models

struct GoogleTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

struct GoogleTokenErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

struct GoogleCalendarEventsResponse: Decodable {
    let items: [GoogleCalendarItem]
}

struct GoogleCalendarItem: Decodable {
    let id: String
    let summary: String?
    let start: GoogleCalendarDateValue
    let end: GoogleCalendarDateValue
    let hangoutLink: String?
}

struct GoogleCalendarDateValue: Decodable {
    let date: String?
    let dateTime: String?

    enum CodingKeys: String, CodingKey {
        case date
        case dateTime
    }
}

enum GoogleCalendarServiceError: LocalizedError {
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
