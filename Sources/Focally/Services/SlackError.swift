import Foundation

// MARK: - Typed Slack API Errors (TASK-059)

/// Tipado de errores del transporte y la API de Slack.
/// Reemplaza el manejo ad-hoc de `NSError` + strings por categorías explícitas.
enum SlackError: Error {
    /// HTTP 429 o `rate_limited`; `retryAfter` viene del header `Retry-After` (default 60 s).
    case rateLimited(retryAfter: TimeInterval)
    /// `invalid_auth` — el token no es válido.
    case authInvalid
    /// Fallo de transporte (URLError y similares).
    case network(underlying: Error)
    /// El cuerpo de la respuesta no es JSON decodificable.
    case decoding
    /// La API respondió `ok: false` u otro error no categorizado.
    case unknown(statusCode: Int, slackError: String)

    // MARK: Classification

    /// Clasifica un error de transporte en mensaje amigable (migrado desde SlackService).
    static func networkMessage(_ error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNotConnectedToInternet {
            return "No internet connection"
        }
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
            return "Network request timed out"
        }
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCannotConnectToHost {
            return "Cannot connect to Slack server"
        }
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCannotFindHost {
            return "Cannot find Slack server"
        }
        if nsError.domain == NSURLErrorDomain {
            return "Network error: \(error.localizedDescription)"
        }
        return error.localizedDescription
    }

    /// Convierte errores de Slack en mensajes amigables para el usuario (migrado desde SlackService).
    static func userFriendlyMessage(for statusCode: Int, slackError: String) -> String {
        if statusCode == 401 || slackError == "invalid_auth" {
            return "Invalid Slack token. Please check your token and try again."
        }
        if statusCode == 403 || slackError == "not_authed" {
            return "Access denied. Your token may not have the required permissions."
        }
        if statusCode == 429 || slackError == "rate_limited" {
            return "Too many requests. Please wait a moment and try again."
        }
        if slackError == "missing_scope" {
            return "Your token is missing required permissions."
        }
        if slackError == "account_inactive" {
            return "Your Slack account is inactive."
        }
        if slackError == "token_revoked" {
            return "Your Slack token has been revoked."
        }
        if slackError == "org_login_required" {
            return "Your Slack workspace requires login."
        }
        return "Slack API error: \(slackError)"
    }

    /// Mensaje de cara al usuario para esta instancia de error.
    /// Los strings reproducen exactamente los de `SlackService.userFriendlyError` /
    /// `SlackService.categorizeNetworkError` para no cambiar comportamiento observable.
    var displayMessage: String {
        switch self {
        case .rateLimited:
            return SlackError.userFriendlyMessage(for: 429, slackError: "rate_limited")
        case .authInvalid:
            return SlackError.userFriendlyMessage(for: 200, slackError: "invalid_auth")
        case .network(let underlying):
            return SlackError.networkMessage(underlying)
        case .decoding:
            return "Invalid response from Slack"
        case .unknown(let statusCode, let slackError):
            return SlackError.userFriendlyMessage(for: statusCode, slackError: slackError)
        }
    }

    /// Categoriza un error arbitrario del transporte.
    static func from(_ error: Error) -> SlackError {
        if let slackError = error as? SlackError {
            return slackError
        }
        return .network(underlying: error)
    }
}
