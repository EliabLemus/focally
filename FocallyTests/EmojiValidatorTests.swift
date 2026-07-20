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
        // Shortcodes oficiales de Slack siempre se convierten (existen en todos los workspaces)
        XCTAssertEqual(EmojiValidator.convertUnicodeToShortcode("🧠", workspaceEmojis: []), ":brain:")
        XCTAssertEqual(EmojiValidator.convertUnicodeToShortcode("💻", workspaceEmojis: []), ":computer:")
        XCTAssertEqual(EmojiValidator.convertUnicodeToShortcode("📧", workspaceEmojis: []), ":email:")
        XCTAssertEqual(EmojiValidator.convertUnicodeToShortcode("💪", workspaceEmojis: []), ":muscle:")
        XCTAssertEqual(EmojiValidator.convertUnicodeToShortcode("🍅", workspaceEmojis: []), ":tomato:")
        // Emojis workspace-custom no se convierten si no están en el catálogo
        XCTAssertNil(EmojiValidator.convertUnicodeToShortcode("🫠", workspaceEmojis: []))
    }

    func testIsSlackShortcode() {
        XCTAssertTrue(EmojiValidator.isSlackShortcode(":deep_work:"))
        XCTAssertTrue(EmojiValidator.isSlackShortcode(":test:"))
        XCTAssertFalse(EmojiValidator.isSlackShortcode("🧠"))
        XCTAssertFalse(EmojiValidator.isSlackShortcode("test"))
        XCTAssertFalse(EmojiValidator.isSlackShortcode(":"))
    }

    func testDetectsCustomWorkspaceEmoji() {
        let workspaceEmojis: [String] = [":deep_work:", ":brain:", ":custom_status:"]
        XCTAssertTrue(EmojiValidator.isCustomWorkspaceEmoji(":custom_status:", workspaceEmojiCodes: workspaceEmojis))
        XCTAssertFalse(EmojiValidator.isCustomWorkspaceEmoji(":brain:", workspaceEmojiCodes: workspaceEmojis))
        XCTAssertFalse(EmojiValidator.isCustomWorkspaceEmoji("🧠", workspaceEmojiCodes: workspaceEmojis))
    }
}
