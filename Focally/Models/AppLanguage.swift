import Foundation
import Observation

/// Manages app language selection with auto-detection and persistence.
/// Supports English (en), Spanish (es), and Portuguese (pt).
@Observable
final class AppLanguage {
    static let shared = AppLanguage()

    /// Supported language codes.
    static let supportedLanguages: [String] = ["en", "es", "pt"]

    /// UserDefaults key for persisting manual language override.
    private static let storageKey = "focally.language"

    /// The current language code (e.g. "en", "es", "pt").
    var currentLanguage: String

    private init() {
        // 1. Check UserDefaults for manual override
        if let manual = UserDefaults.standard.string(forKey: Self.storageKey),
           Self.supportedLanguages.contains(manual) {
            currentLanguage = manual
            return
        }

        // 2. Auto-detect system language
        let systemCode = Locale.current.language.languageCode?.identifier ?? "en"
        currentLanguage = Self.supportedLanguages.contains(systemCode) ? systemCode : "en"
    }

    /// Changes the app language and persists the choice.
    /// - Parameter code: Language code ("en", "es", or "pt").
    func setLanguage(_ code: String) {
        guard Self.supportedLanguages.contains(code) else {
            return
        }
        currentLanguage = code
        UserDefaults.standard.set(code, forKey: Self.storageKey)
    }

    /// The current locale derived from the current language.
    var locale: Locale {
        Locale(identifier: currentLanguage)
    }

    /// Resolves a localized string from the correct `.lproj` bundle for the
    /// current language.
    ///
    /// `String(localized:)` and `LocalizedStringResource` resolve against
    /// `Bundle.main.preferredLocalizations` (the OS language), ignoring
    /// SwiftUI's `\.locale` environment. This method loads the string from
    /// the specific language's `.lproj` directory so that the user's manual
    /// language override takes effect immediately.
    ///
    /// - Parameter key: The localization key in `Localizable.strings`.
    /// - Returns: The translated string, or the key itself if not found.
    func localizedString(_ key: String) -> String {
        // Try the specific language bundle first
        if let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key {
                return value
            }
        }

        // Fallback: main bundle (uses preferredLocalizations)
        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
}
