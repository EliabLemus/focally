import Foundation
import Observation

/// Checks GitHub releases for app updates.
/// Uses a 24h cooldown via UserDefaults to avoid excessive API calls.
@MainActor
@Observable
final class UpdateCheckerService {
    static let shared = UpdateCheckerService()

    // MARK: - Properties

    private let logger = Logger.update
    private let defaults = UserDefaults.standard
    private let githubRepo = "EliabLemus/focally"

    private static let lastCheckKey = "focally.updateChecker.lastCheck"
    private static let latestVersionKey = "focally.updateChecker.latestVersion"
    private static let updateUrlKey = "focally.updateChecker.updateUrl"

    var isChecking = false
    var latestVersion: String?
    var updateUrl: URL?
    var lastCheckDate: Date?

    var isNewVersionAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return compareVersions(latest, currentVersion) == .orderedDescending
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Parses a semantic version string (e.g., "0.8.15") into an array of Int components.
    private func parseVersion(_ versionString: String) -> [Int] {
        return versionString.split(separator: ".")
            .compactMap { Int($0) }
    }

    /// Compares two semantic version strings.
    /// Returns .orderedDescending if lhs > rhs, .orderedAscending if lhs < rhs, .orderedSame if equal.
    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = parseVersion(lhs)
        let rhsParts = parseVersion(rhs)

        let maxCount = max(lhsParts.count, rhsParts.count)

        for i in 0..<maxCount {
            let lhs = lhsParts.indices.contains(i) ? lhsParts[i] : 0
            let rhs = rhsParts.indices.contains(i) ? rhsParts[i] : 0

            if lhs < rhs { return .orderedAscending }
            if lhs > rhs { return .orderedDescending }
        }

        return .orderedSame
    }

    private var shouldCheck: Bool {
        guard let lastCheck = lastCheckDate else { return true }
        let hoursSinceLastCheck = Date().timeIntervalSince(lastCheck) / 3600
        return hoursSinceLastCheck >= 24
    }

    // MARK: - Init

    private init() {
        lastCheckDate = defaults.object(forKey: Self.lastCheckKey) as? Date
        latestVersion = defaults.string(forKey: Self.latestVersionKey)

        if let urlString = defaults.string(forKey: Self.updateUrlKey),
           let url = URL(string: urlString) {
            updateUrl = url
        }

        if shouldCheck {
            checkForUpdates()
        }
    }

    // MARK: - Public Methods

    func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true

        Task { [weak self] in
            guard let self else { return }

            do {
                guard let url = URL(string: "https://api.github.com/repos/\(self.githubRepo)/releases/latest") else {
                    await MainActor.run { self.isChecking = false }
                    return
                }

                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    await MainActor.run {
                        self.logger.warning("GitHub API returned non-200 status")
                        self.isChecking = false
                    }
                    return
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let htmlUrl = json["html_url"] as? String else {
                    await MainActor.run {
                        self.logger.warning("Could not parse GitHub release response")
                        self.isChecking = false
                    }
                    return
                }

                // Remove 'v' prefix from tag if present
                let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

                await MainActor.run {
                    self.latestVersion = version
                    self.updateUrl = URL(string: htmlUrl)
                    self.lastCheckDate = Date()

                    self.defaults.set(version, forKey: Self.latestVersionKey)
                    self.defaults.set(htmlUrl, forKey: Self.updateUrlKey)
                    self.defaults.set(Date(), forKey: Self.lastCheckKey)

                    if self.isNewVersionAvailable {
                        self.logger.info("New version available: \(version) (current: \(self.currentVersion))")
                    } else {
                        self.logger.info("Already on latest version: \(self.currentVersion)")
                    }

                    self.isChecking = false
                }
            } catch {
                await MainActor.run {
                    self.logger.error("Failed to check for updates: \(error.localizedDescription)")
                    self.isChecking = false
                }
            }
        }
    }
}
