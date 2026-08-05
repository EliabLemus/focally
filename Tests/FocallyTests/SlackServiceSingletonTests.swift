import XCTest
@testable import Focally

@MainActor
final class SlackServiceSingletonTests: XCTestCase {
    private var originalIsEnabled = false
    private var originalConnectionError: String?
    private var originalWorkspaceEmojiCodes: [String] = []
    private var originalWorkspaceEmojiImageURLs: [String: String] = [:]
    private var originalSlackEnabledDefault: Any?

    override func setUp() {
        super.setUp()
        let service = SlackService.shared
        originalIsEnabled = service.isEnabled
        originalConnectionError = service.connectionError
        originalWorkspaceEmojiCodes = service.workspaceEmojiCodes
        originalWorkspaceEmojiImageURLs = service.workspaceEmojiImageURLs
        originalSlackEnabledDefault = UserDefaults.standard.object(forKey: "slackEnabled")
    }

    override func tearDown() {
        let service = SlackService.shared
        service.isEnabled = originalIsEnabled
        service.connectionError = originalConnectionError
        service.workspaceEmojiCodes = originalWorkspaceEmojiCodes
        service.workspaceEmojiImageURLs = originalWorkspaceEmojiImageURLs
        if let originalSlackEnabledDefault {
            UserDefaults.standard.set(originalSlackEnabledDefault, forKey: "slackEnabled")
        } else {
            UserDefaults.standard.removeObject(forKey: "slackEnabled")
        }
        super.tearDown()
    }

    func testSharedReturnsSameInstance() {
        XCTAssertTrue(SlackService.shared === SlackService.shared)
    }

    func testFocusIntegrationServiceUsesSharedSlackService() {
        XCTAssertTrue(FocusIntegrationService.shared.slackServiceForTesting === SlackService.shared)
    }

    func testFocusIntegrationServiceObservesSharedEnabledState() {
        SlackService.shared.isEnabled = true
        XCTAssertTrue(FocusIntegrationService.shared.slackServiceForTesting.isEnabled)

        SlackService.shared.isEnabled = false
        XCTAssertFalse(FocusIntegrationService.shared.slackServiceForTesting.isEnabled)
    }

    func testFocusIntegrationServiceObservesSharedErrorAndEmojiState() {
        SlackService.shared.connectionError = "test error"
        SlackService.shared.workspaceEmojiCodes = [":deep_work:"]
        SlackService.shared.workspaceEmojiImageURLs = [":deep_work:": "https://example.com/deep-work.png"]

        let dependency = FocusIntegrationService.shared.slackServiceForTesting
        XCTAssertEqual(dependency.connectionError, "test error")
        XCTAssertEqual(dependency.workspaceEmojiCodes, [":deep_work:"])
        XCTAssertEqual(
            dependency.workspaceEmojiImageURLs,
            [":deep_work:": "https://example.com/deep-work.png"]
        )
    }
}
