import SwiftUI

struct EmojiView: View {
    let emoji: String
    let customEmojiImageURLs: [String: String]
    let workspaceEmojiCodes: [String]
    let font: Font
    let dimension: CGFloat

    init(
        _ emoji: String,
        customEmojiImageURLs: [String: String] = [:],
        workspaceEmojiCodes: [String] = [],
        font: Font = .system(size: 34),
        dimension: CGFloat = 34
    ) {
        self.emoji = emoji
        self.customEmojiImageURLs = customEmojiImageURLs
        self.workspaceEmojiCodes = workspaceEmojiCodes
        self.font = font
        self.dimension = dimension
    }

    var body: some View {
        if let url = imageURL {
            CachedEmojiImage(
                shortcode: emoji,
                remoteURL: url,
                fallbackEmoji: fallbackEmoji,
                font: font,
                dimension: dimension
            )
        } else {
            fallbackText
        }
    }

    private var fallbackText: some View {
        Text(fallbackEmoji)
            .font(font)
            .frame(minWidth: dimension, minHeight: dimension)
            .fixedSize()
    }

    private var imageURL: URL? {
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EmojiValidator.isCustomWorkspaceEmoji(trimmed, workspaceEmojiCodes: workspaceEmojiCodes) else {
            return nil
        }

        let urlString = customEmojiImageURLs[trimmed]
        return urlString.flatMap { URL(string: $0) }
    }

    private var fallbackEmoji: String {
        EmojiValidator.convertShortcodeToUnicode(emoji, workspaceEmojis: workspaceEmojiCodes) ?? emoji
    }
}

private struct CachedEmojiImage: View {
    let shortcode: String
    let remoteURL: URL
    let fallbackEmoji: String
    let font: Font
    let dimension: CGFloat

    @State private var localURL: URL?

    var body: some View {
        Group {
            if let localURL, let nsImage = NSImage(contentsOf: localURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        fallbackText
                    case .empty:
                        ProgressView()
                            .frame(width: dimension, height: dimension)
                    @unknown default:
                        fallbackText
                    }
                }
            }
        }
        .frame(width: dimension, height: dimension)
        .task(id: shortcode) {
            localURL = await EmojiCacheService.shared.emoji(for: shortcode, remoteURL: remoteURL)
        }
    }

    private var fallbackText: some View {
        Text(fallbackEmoji)
            .font(font)
            .frame(minWidth: dimension, minHeight: dimension)
            .fixedSize()
    }
}
