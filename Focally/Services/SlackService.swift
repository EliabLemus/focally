import Foundation
import Combine

class SlackService: ObservableObject {
    static let defaultStatusEmoji = ":hourglass_flowing_sand:"
    static let statusEmojiDefaultsKey = "slackStatusEmoji"

    @Published var isEnabled = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "slackEnabled")
        }
    }
    @Published var isConnected = false
    @Published var connectionError: String?
    @Published var lastStatusText: String?

    private let keychainKey = "slack-token"
    private let apiURL = "https://slack.com/api/users.profile.set"

    var token: String? {
        get { KeychainHelper.load(key: keychainKey) }
        set {
            if let value = newValue {
                KeychainHelper.save(key: keychainKey, value: value)
            } else {
                KeychainHelper.delete(key: keychainKey)
            }
        }
    }

    // MARK: - Public API

    func savedStatusEmoji() -> String {
        let rawValue = UserDefaults.standard.string(forKey: Self.statusEmojiDefaultsKey) ?? Self.defaultStatusEmoji
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultStatusEmoji : trimmed
    }

    func setStatus(text: String, expirationTimestamp: Int, customEmoji: String? = nil) {
        guard isEnabled, let token = token else { return }
        let statusEmoji = normalizedStatusEmoji(customEmoji)

        let profile: [String: String] = [
            "status_text": text,
            "status_emoji": statusEmoji,
            "status_expiration": "\(expirationTimestamp)"
        ]

        guard let jsonData = try? JSONEncoder().encode(profile) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "profile=\(jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? jsonString)".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.connectionError = error.localizedDescription
                    self?.isConnected = false
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let ok = json["ok"] as? Bool else {
                    self?.connectionError = "Invalid response from Slack"
                    self?.isConnected = false
                    return
                }

                if ok {
                    self?.isConnected = true
                    self?.connectionError = nil
                    self?.lastStatusText = text
                    print("[Focally] Slack status set: \(statusEmoji) \(text)")
                } else {
                    let errorMsg = json["error"] as? String ?? "Unknown error"
                    self?.connectionError = errorMsg
                    self?.isConnected = false
                    print("[Focally] Slack error: \(errorMsg)")
                }
            }
        }.resume()
    }

    func clearStatus() {
        guard isEnabled, let token = token else { return }

        let profile: [String: String] = [
            "status_text": "",
            "status_emoji": ""
        ]

        guard let jsonData = try? JSONEncoder().encode(profile) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "profile=\(jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? jsonString)".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[Focally] Slack clear error: \(error.localizedDescription)")
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let ok = json["ok"] as? Bool else {
                    return
                }

                if ok {
                    self?.lastStatusText = nil
                    print("[Focally] Slack status cleared")
                }
            }
        }.resume()
    }

    func testConnection() {
        guard token != nil else {
            connectionError = "No token configured"
            isConnected = false
            return
        }

        // Test by setting a quick status and clearing it
        setStatus(text: "Testing Focally", expirationTimestamp: Int(Date().timeIntervalSince1970) + 10, customEmoji: ":test_tube:")

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.clearStatus()
        }
    }

    // MARK: - Init

    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "slackEnabled")
        // Try to load saved token
        if token != nil {
            // Don't auto-test, just mark as potentially connected
            self.isConnected = true
        }
    }

    private func normalizedStatusEmoji(_ emoji: String?) -> String {
        let trimmed = emoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? savedStatusEmoji() : trimmed
    }
}
