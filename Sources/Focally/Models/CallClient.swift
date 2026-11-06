import Foundation

/// A conferencing client attributed from a media-capture process.
/// Matched by bundle-id prefix (conferencing apps capture from helper processes),
/// never by exact PID.
struct CallClient: Equatable, Identifiable {
    let bundlePrefix: String
    let displayName: String
    let emoji: String

    var id: String { bundlePrefix }
}

enum CallClientCatalog {
    /// Single source of truth for bundle-id prefix → client mapping.
    /// Prefix matching: a bundle identifier starting with the prefix resolves to
    /// the client (helpers such as `com.google.chrome.helper` map to Chrome).
    /// Longest matching prefix wins. User-extendable settings UI is a follow-up;
    /// this table stays code-defined for TASK-057.
    static let defaultClients: [CallClient] = [
        CallClient(bundlePrefix: "com.google.chrome", displayName: "Google Meet (Chrome)", emoji: ":google-meet:"),
        CallClient(bundlePrefix: "org.mozilla.firefox", displayName: "Firefox Call", emoji: ":phone:"),
        CallClient(bundlePrefix: "com.microsoft.edgemac", displayName: "Edge Call", emoji: ":phone:"),
        CallClient(bundlePrefix: "com.tinyspeck.slackmacgap", displayName: "Slack Call", emoji: ":slack-call:"),
        CallClient(bundlePrefix: "com.zoom", displayName: "Zoom", emoji: ":zoom:"),
        CallClient(bundlePrefix: "us.zoom", displayName: "Zoom", emoji: ":zoom:"),
        CallClient(bundlePrefix: "com.microsoft.teams", displayName: "Microsoft Teams", emoji: ":teams:"),
        CallClient(bundlePrefix: "com.hnc.Discord", displayName: "Discord", emoji: ":phone:")
    ]

    /// Client used when a non-Apple process captures but matches no known prefix.
    static let unknownClient = CallClient(bundlePrefix: "unknown", displayName: "Unknown Client", emoji: ":phone:")

    /// Apple-owned processes (dictation / CoreSpeech open the mic) never count as calls.
    static let excludedPrefix = "com.apple."

    static func client(for bundleIdentifier: String) -> CallClient {
        let lowered = bundleIdentifier.lowercased()
        guard !lowered.hasPrefix(excludedPrefix) else { return unknownClient }
        let match = defaultClients
            .filter { lowered.hasPrefix($0.bundlePrefix.lowercased()) }
            .max(by: { $0.bundlePrefix.count < $1.bundlePrefix.count })
        return match ?? unknownClient
    }
}

/// Attributes capturing processes to call clients. Pure and injectable so tests
/// never touch real process object APIs.
final class CallProcessAttributor {
    let ownBundleIdentifier: String

    init(ownBundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.focally.app") {
        self.ownBundleIdentifier = ownBundleIdentifier
    }

    /// Filters out Focally's own bundle and Apple-owned processes, then maps the
    /// remaining capturing bundle ids to call clients (deduped).
    func attributedClients(fromBundleIdentifiers bundleIDs: [String]) -> [CallClient] {
        var seen = Set<String>()
        var clients: [CallClient] = []
        for bundleID in bundleIDs {
            let lowered = bundleID.lowercased()
            guard !lowered.isEmpty else { continue }
            guard lowered != ownBundleIdentifier.lowercased() else { continue }
            guard !lowered.hasPrefix(CallClientCatalog.excludedPrefix) else { continue }
            let client = CallClientCatalog.client(for: lowered)
            guard seen.insert(client.bundlePrefix).inserted else { continue }
            clients.append(client)
        }
        return clients
    }
}
