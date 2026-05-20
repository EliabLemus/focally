import SwiftUI

struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.5.1"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "8"
    }

    var body: some View {
        VStack(spacing: FocallySpacing.large) {
            // App icon placeholder
            RoundedRectangle(cornerRadius: FocallyRadius.large)
                .fill(
                    LinearGradient(
                        colors: [Color.focallyPrimary, Color.focallyPrimaryContainer],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "timer")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.focallyOnPrimary)
                )

            VStack(spacing: FocallySpacing.extraSmall) {
                Text("Focally")
                    .font(.focallyH1)
                    .foregroundStyle(Color.focallyOnSurface)

                HStack(spacing: FocallySpacing.extraSmall) {
                    Text("Version \(appVersion)")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOutline)

                    Text("·")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOutline)

                    Text("Build \(buildNumber)")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOutline)
                }
            }

            Divider()
                .background(Color.focallyOutlineVariant)
                .padding(.vertical, FocallySpacing.small)

            VStack(spacing: FocallySpacing.extraSmall) {
                Text("Developed with ❤️ using SwiftUI")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOutline)

                Text("© 2025-2026 Eliab Lemus")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOutline)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FocallySpacing.extraLarge)
    }
}
