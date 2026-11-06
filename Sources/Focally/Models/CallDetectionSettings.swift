import Foundation

/// User-facing call-detection preferences. A plain value read from a store at
/// each call transition so changes take effect on the NEXT call without an app
/// restart.
struct CallDetectionSettings: Equatable {
    static let defaultStatusMessage = "In a Call - Powered by Focally"
    static let slackStatusCharacterLimit = 256

    var callStatusEnabled: Bool
    var callStatusMessage: String
    var enableDNDDuringCalls: Bool
    var pauseFocusDuringCalls: Bool

    init(
        callStatusEnabled: Bool = true,
        callStatusMessage: String = CallDetectionSettings.defaultStatusMessage,
        enableDNDDuringCalls: Bool = true,
        pauseFocusDuringCalls: Bool = true
    ) {
        self.callStatusEnabled = callStatusEnabled
        self.callStatusMessage = callStatusMessage
        self.enableDNDDuringCalls = enableDNDDuringCalls
        self.pauseFocusDuringCalls = pauseFocusDuringCalls
    }

    /// Slack statuses are capped at 256 characters; an empty/whitespace message
    /// falls back to the default text.
    static func sanitizedStatusMessage(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultStatusMessage }
        guard trimmed.count > slackStatusCharacterLimit else { return trimmed }
        return String(trimmed.prefix(slackStatusCharacterLimit))
    }

    var sanitizedStatusMessage: String {
        Self.sanitizedStatusMessage(callStatusMessage)
    }
}

/// UserDefaults-backed store for `CallDetectionSettings`.
@MainActor
final class CallDetectionSettingsStore {
    enum Key {
        static let callStatusEnabled = "callStatusEnabled"
        static let callStatusMessage = "callStatusMessage"
        static let enableDNDDuringCalls = "enableDNDDuringCalls"
        static let pauseFocusDuringCalls = "pauseFocusDuringCalls"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Reads current values on every access: toggles and messages changed in the
    /// settings panel apply to the next call with no restart.
    func currentSettings() -> CallDetectionSettings {
        var settings = CallDetectionSettings()
        if defaults.object(forKey: Key.callStatusEnabled) != nil {
            settings.callStatusEnabled = defaults.bool(forKey: Key.callStatusEnabled)
        }
        if let message = defaults.string(forKey: Key.callStatusMessage) {
            settings.callStatusMessage = message
        }
        if defaults.object(forKey: Key.enableDNDDuringCalls) != nil {
            settings.enableDNDDuringCalls = defaults.bool(forKey: Key.enableDNDDuringCalls)
        }
        if defaults.object(forKey: Key.pauseFocusDuringCalls) != nil {
            settings.pauseFocusDuringCalls = defaults.bool(forKey: Key.pauseFocusDuringCalls)
        }
        return settings
    }

    func save(_ settings: CallDetectionSettings) {
        defaults.set(settings.callStatusEnabled, forKey: Key.callStatusEnabled)
        defaults.set(CallDetectionSettings.sanitizedStatusMessage(settings.callStatusMessage), forKey: Key.callStatusMessage)
        defaults.set(settings.enableDNDDuringCalls, forKey: Key.enableDNDDuringCalls)
        defaults.set(settings.pauseFocusDuringCalls, forKey: Key.pauseFocusDuringCalls)
    }

    var callStatusEnabled: Bool {
        get { currentSettings().callStatusEnabled }
        set { var s = currentSettings(); s.callStatusEnabled = newValue; save(s) }
    }

    var callStatusMessage: String {
        get { currentSettings().callStatusMessage }
        set { var s = currentSettings(); s.callStatusMessage = newValue; save(s) }
    }

    var enableDNDDuringCalls: Bool {
        get { currentSettings().enableDNDDuringCalls }
        set { var s = currentSettings(); s.enableDNDDuringCalls = newValue; save(s) }
    }

    var pauseFocusDuringCalls: Bool {
        get { currentSettings().pauseFocusDuringCalls }
        set { var s = currentSettings(); s.pauseFocusDuringCalls = newValue; save(s) }
    }
}
