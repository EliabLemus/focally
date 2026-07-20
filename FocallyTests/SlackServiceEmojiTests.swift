import XCTest
@testable import Focally

final class SlackServiceEmojiTests: XCTestCase {
    var service: SlackService!

    override func setUp() {
        super.setUp()
        service = SlackService()
    }

    func testValidateEmojiInWorkspace() {
        service.workspaceEmojiCodes = [":deep_work:", ":coding:", ":writing:"]
        XCTAssertTrue(service.validateEmoji(":deep_work:"))
        XCTAssertFalse(service.validateEmoji(":invalid:"))
    }

    func testValidateUnicodeEmoji() {
        service.workspaceEmojiCodes = [":deep_work:", ":coding:"]
        // Unicode siempre es válido para UI (Slack mostrará ? si no existe)
        XCTAssertTrue(service.validateEmoji("🧠"))
        XCTAssertTrue(service.validateEmoji("💻"))
    }

    func testWorkspaceEmojiImageURLsResolvesAliases() {
        let emojiMap: [String: String] = [
            "custom_status": "https://emoji.slack-edge.com/T123/custom_status/abc123.png",
            "alias_status": "alias:custom_status",
            "bad_alias": "alias:missing"
        ]

        let imageURLs = SlackService.workspaceEmojiImageURLs(from: emojiMap)

        XCTAssertEqual(
            imageURLs[":custom_status:"],
            "https://emoji.slack-edge.com/T123/custom_status/abc123.png"
        )
        XCTAssertEqual(
            imageURLs[":alias_status:"],
            "https://emoji.slack-edge.com/T123/custom_status/abc123.png"
        )
        XCTAssertNil(imageURLs[":bad_alias:"])
    }
}
