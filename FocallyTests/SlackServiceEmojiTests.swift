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
}
