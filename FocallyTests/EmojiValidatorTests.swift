import XCTest
@testable import Focally

final class EmojiValidatorTests: XCTestCase {
    func testValidateUnicodeEmoji() {
        let workspaceEmojis: [String] = [":deep_work:", ":coding:", ":writing:"]
        XCTAssertTrue(EmojiValidator.isValidForSlack("🧠", workspaceEmojis: workspaceEmojis))
        XCTAssertTrue(EmojiValidator.isValidForSlack("💻", workspaceEmojis: workspaceEmojis))
    }

    func testValidateSlackShortcode() {
        let workspaceEmojis: [String] = [":deep_work:", ":coding:", ":writing:"]
        XCTAssertTrue(EmojiValidator.isValidForSlack(":deep_work:", workspaceEmojis: workspaceEmojis))
        XCTAssertFalse(EmojiValidator.isValidForSlack(":invalid:", workspaceEmojis: workspaceEmojis))
    }

    func testConvertUnicodeToShortcode() {
        let workspaceEmojis: [String] = [":brain:", ":computer:", ":memo:"]
        XCTAssertEqual(EmojiValidator.convertUnicodeToShortcode("🧠", workspaceEmojis: workspaceEmojis), ":brain:")
        XCTAssertEqual(EmojiValidator.convertUnicodeToShortcode("💻", workspaceEmojis: workspaceEmojis), ":computer:")
        XCTAssertNil(EmojiValidator.convertUnicodeToShortcode("🍅", workspaceEmojis: workspaceEmojis))
    }

    func testIsSlackShortcode() {
        XCTAssertTrue(EmojiValidator.isSlackShortcode(":deep_work:"))
        XCTAssertTrue(EmojiValidator.isSlackShortcode(":test:"))
        XCTAssertFalse(EmojiValidator.isSlackShortcode("🧠"))
        XCTAssertFalse(EmojiValidator.isSlackShortcode("test"))
        XCTAssertFalse(EmojiValidator.isSlackShortcode(":"))
    }
}
