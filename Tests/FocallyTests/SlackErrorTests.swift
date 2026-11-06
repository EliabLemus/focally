import Foundation
import Testing
@testable import Focally

@Suite("SlackError")
struct SlackErrorTests {
    // MARK: - Categorización

    @Test func fromPreservesSlackErrors() {
        let original = SlackError.rateLimited(retryAfter: 30)
        guard case .rateLimited(let retryAfter) = SlackError.from(original) else {
            Issue.record("Expected passthrough .rateLimited")
            return
        }
        #expect(retryAfter == 30)
    }

    @Test func fromWrapsTransportErrorsAsNetwork() {
        let urlError = URLError(.timedOut)
        guard case .network(let underlying) = SlackError.from(urlError) else {
            Issue.record("Expected .network wrapper")
            return
        }
        #expect((underlying as? URLError)?.code == .timedOut)
    }

    // MARK: - displayMessage (mismas strings que antes de TASK-059)

    @Test func displayMessageStringsMatchLegacyBehavior() {
        #expect(SlackError.authInvalid.displayMessage == "Invalid Slack token. Please check your token and try again.")
        #expect(SlackError.rateLimited(retryAfter: 60).displayMessage == "Too many requests. Please wait a moment and try again.")
        #expect(SlackError.network(underlying: URLError(.notConnectedToInternet)).displayMessage == "No internet connection")
        #expect(SlackError.network(underlying: URLError(.timedOut)).displayMessage == "Network request timed out")
        #expect(SlackError.network(underlying: URLError(.cannotConnectToHost)).displayMessage == "Cannot connect to Slack server")
        #expect(SlackError.network(underlying: URLError(.cannotFindHost)).displayMessage == "Cannot find Slack server")
        #expect(SlackError.decoding.displayMessage == "Invalid response from Slack")
        #expect(
            SlackError.unknown(statusCode: 403, slackError: "not_authed").displayMessage
                == "Access denied. Your token may not have the required permissions."
        )
        #expect(
            SlackError.unknown(statusCode: 200, slackError: "missing_scope").displayMessage
                == "Your token is missing required permissions."
        )
        #expect(
            SlackError.unknown(statusCode: 200, slackError: "account_inactive").displayMessage
                == "Your Slack account is inactive."
        )
        #expect(
            SlackError.unknown(statusCode: 200, slackError: "token_revoked").displayMessage
                == "Your Slack token has been revoked."
        )
        #expect(
            SlackError.unknown(statusCode: 200, slackError: "org_login_required").displayMessage
                == "Your Slack workspace requires login."
        )
        #expect(
            SlackError.unknown(statusCode: 500, slackError: "internal_error").displayMessage
                == "Slack API error: internal_error"
        )
    }

    @Test func userFriendlyMessageDirectClassification() {
        #expect(SlackError.userFriendlyMessage(for: 401, slackError: "") == "Invalid Slack token. Please check your token and try again.")
        #expect(SlackError.userFriendlyMessage(for: 429, slackError: "other") == "Too many requests. Please wait a moment and try again.")
    }

    @Test func networkMessageFallbackUsesLocalizedDescription() {
        struct CustomError: LocalizedError {
            var errorDescription: String? { "custom failure" }
        }
        #expect(SlackError.networkMessage(CustomError()) == "custom failure")
    }
}
