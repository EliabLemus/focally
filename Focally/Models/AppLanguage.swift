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
}
