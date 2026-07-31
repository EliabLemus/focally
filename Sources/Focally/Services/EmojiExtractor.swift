import Foundation

@MainActor
final class EmojiExtractor {
    static let shared = EmojiExtractor()

    private init() {}

    func extractAllEmojis(from text: String) -> [String] {
        text.compactMap { character in
            character.unicodeScalars.contains { scalar in
                scalar.properties.isEmojiPresentation ||
                    (scalar.properties.isEmoji && scalar.value > 0x238C)
            } ? String(character) : nil
        }
    }

    func concatenate(emojis: [String]) -> String {
        emojis.joined()
    }
}
