import SwiftUI

/// A SwiftUI `Text` that resolves localization keys against `AppLanguage`'s
/// current language bundle, NOT `Bundle.main.preferredLocalizations`.
///
/// SwiftUI's built-in `Text("key")` (which takes `LocalizedStringKey`) and
/// `String(localized:)` both resolve against the bundle's
/// `preferredLocalizations` — effectively the OS language. They do NOT
/// respect `.environment(\.locale, ...)`. This means a user who manually
/// selects "Spanish" in settings while running an English OS still sees
/// English strings.
///
/// `LocalizedText` reads `AppLanguage.shared` (an `@Observable` injected into
/// the environment) and resolves the key from the correct `.lproj` bundle,
/// updating immediately when the language changes.
///
/// Usage:
/// ```swift
/// LocalizedText("settings_title")
/// // or with styling:
/// LocalizedText("settings_title")
///     .font(.focallyH2)
///     .foregroundStyle(Color.focallyOnSurface)
/// ```
struct LocalizedText: View {
    @Environment(AppLanguage.self) private var appLanguage

    private let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(appLanguage.localizedString(key))
    }
}
