import SwiftUI
import os.log

final class EmojiCacheService {
    static let shared = EmojiCacheService()

    private let logger = Logger.uiLogger
    private let fileManager = FileManager.default
    private let cacheDirectory: URL = {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Focally/EmojiCache", isDirectory: true)
    }()

    /// Cached emojis: ":shortcode:" -> local file URL
    private(set) var cachedEmojis: [String: URL] = [:]

    init() {
        ensureCacheDirectory()
        loadCachedEmojis()
    }

    func emoji(for shortcode: String, remoteURL: URL?) async -> URL? {
        if let cached = cachedEmojis[shortcode], fileManager.fileExists(atPath: cached.path) {
            return cached
        }

        guard let remoteURL else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.warning("Failed to download emoji: bad response")
                return nil
            }

            let localURL = cacheDirectory.appendingPathComponent(
                "\(encodedFileName(for: shortcode)).\(normalizedFileExtension(for: remoteURL))"
            )

            try data.write(to: localURL, options: .atomic)
            cachedEmojis[shortcode] = localURL
            logger.info("Cached emoji to disk")
            return localURL
        } catch {
            logger.error("Failed to download emoji")
            return nil
        }
    }

    func warmCache(with emojiURLs: [String: String]) async {
        guard !emojiURLs.isEmpty else { return }

        for (shortcode, urlString) in emojiURLs {
            guard cachedEmojis[shortcode] == nil, let remoteURL = URL(string: urlString) else { continue }
            _ = await emoji(for: shortcode, remoteURL: remoteURL)
        }
    }

    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        ensureCacheDirectory()
        cachedEmojis = [:]
        logger.info("Emoji cache cleared")
    }

    private func loadCachedEmojis() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return
        }

        cachedEmojis = files.reduce(into: [:]) { partialResult, url in
            let fileName = url.deletingPathExtension().lastPathComponent
            let shortcode = fileName.removingPercentEncoding ?? fileName
            partialResult[shortcode] = url
        }
        logger.info("Loaded \(cachedEmojis.count) cached emojis from disk")
    }

    private func ensureCacheDirectory() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func encodedFileName(for shortcode: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return shortcode.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? shortcode
    }

    private func normalizedFileExtension(for remoteURL: URL) -> String {
        let pathExtension = remoteURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return pathExtension.isEmpty ? "png" : pathExtension.lowercased()
    }
}
