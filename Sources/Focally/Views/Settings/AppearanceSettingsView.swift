import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.large) {
            Text(AppLanguage.shared.localizedString("appearance_title"))
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)
                .padding(.bottom, FocallySpacing.extraSmall)

            VStack(spacing: 0) {
                ForEach(ThemeChoice.allCases) { theme in
                    themeRow(theme: theme)

                    if theme != ThemeChoice.allCases.last {
                        Divider()
                            .background(Color.focallyOutlineVariant)
                    }
                }
            }
            .focallyGlassCard()
        }
    }

    private var themeBinding: Binding<ThemeChoice> {
        Binding(
            get: { settingsStore.appTheme },
            set: { newValue in
                settingsStore.appTheme = newValue
                settingsStore.saveTheme()
            }
        )
    }

    private func themeRow(theme: ThemeChoice) -> some View {
        Button(action: {
            themeBinding.wrappedValue = theme
        }) {
            HStack(spacing: FocallySpacing.medium) {
                Image(systemName: theme.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .frame(width: 20)

                Text(theme.localizedLabel)
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                // Radio button
                ZStack {
                    Circle()
                        .stroke(themeBinding.wrappedValue == theme ? Color.focallyPrimary : Color.focallyOutline, lineWidth: 1.5)
                        .frame(width: 18, height: 18)

                    if themeBinding.wrappedValue == theme {
                        Circle()
                            .fill(Color.focallyPrimary)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.horizontal, FocallySpacing.large)
            .padding(.vertical, FocallySpacing.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
