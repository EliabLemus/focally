import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appTheme") private var selectedTheme: ThemeChoice = .system

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.large) {
            Text("Appearance")
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
            .focallyCard()
        }
    }

    private func themeRow(theme: ThemeChoice) -> some View {
        Button(action: {
            selectedTheme = theme
        }) {
            HStack(spacing: FocallySpacing.medium) {
                Image(systemName: theme.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .frame(width: 20)

                Text(theme.label)
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                // Radio button
                ZStack {
                    Circle()
                        .stroke(selectedTheme == theme ? Color.focallyPrimary : Color.focallyOutline, lineWidth: 1.5)
                        .frame(width: 18, height: 18)

                    if selectedTheme == theme {
                        Circle()
                            .fill(Color.focallyPrimary)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.horizontal, FocallySpacing.large)
            .padding(.vertical, FocallySpacing.medium)
        }
        .buttonStyle(.plain)
    }
}
