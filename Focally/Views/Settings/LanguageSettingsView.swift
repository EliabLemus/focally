import SwiftUI

struct LanguageSettingsView: View {
    @Environment(AppLanguage.self) private var appLanguage

    private struct LanguageOption: Identifiable {
        let code: String
        let localizationKey: String
        var id: String { code }
    }

    private let languages: [LanguageOption] = [
        LanguageOption(code: "en", localizationKey: "language_english"),
        LanguageOption(code: "es", localizationKey: "language_spanish"),
        LanguageOption(code: "pt", localizationKey: "language_portuguese")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.large) {
            VStack(spacing: 0) {
                ForEach(languages) { language in
                    languageRow(language)
                    if language.id != languages.last?.id {
                        Divider()
                            .background(Color.focallyOutlineVariant)
                    }
                }
            }
            .focallyGlassCard()
        }
    }

    private func languageRow(_ language: LanguageOption) -> some View {
        Button(action: {
            appLanguage.setLanguage(language.code)
        }) {
            HStack(spacing: FocallySpacing.medium) {
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .frame(width: 20)

                Text(appLanguage.localizedString(language.localizationKey))
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                if appLanguage.currentLanguage == language.code {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.focallyPrimary)
                }
            }
            .padding(.horizontal, FocallySpacing.large)
            .padding(.vertical, FocallySpacing.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
