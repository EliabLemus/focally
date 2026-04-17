import Foundation
import Combine

class SlackService: ObservableObject {
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

    func setStatus(emoji: String, text: String, expirationTimestamp: Int) {
        guard isEnabled, let token = token else { return }

        let profile: [String: String] = [
            "status_text": text,
            "status_emoji": emoji,
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
                    print("[Focally] Slack status set: \(emoji) \(text)")
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
        guard let token = token else {
            connectionError = "No token configured"
            isConnected = false
            return
        }

        // Test by setting a quick status and clearing it
        setStatus(emoji: "🧪", text: "Testing Focally", expirationTimestamp: Int(Date().timeIntervalSince1970) + 10)

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
}
