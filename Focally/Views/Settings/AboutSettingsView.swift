import SwiftUI

struct AboutSettingsView: View {
    @Environment(UpdateCheckerService.self) private var updateChecker

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
                    Text(String(format: AppLanguage.shared.localizedString("about_version"), appVersion))
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOutline)

                    if updateChecker.isNewVersionAvailable {
                        Button(action: {
                            if let url = updateChecker.updateUrl {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.focallyCaption)
                                LocalizedText("about_update_available")
                                    .font(.focallyCaption)
                            }
                            .foregroundStyle(Color.focallyPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.focallyPrimaryContainer)
                            .cornerRadius(FocallyRadius.small)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("·")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOutline)

                    Text(String(format: AppLanguage.shared.localizedString("about_build"), buildNumber))
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOutline)
                }
            }

            Divider()
                .background(Color.focallyOutlineVariant)
                .padding(.vertical, FocallySpacing.small)

            VStack(spacing: FocallySpacing.extraSmall) {
                LocalizedText("about_developed")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOutline)

                LocalizedText("about_copyright")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOutline)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FocallySpacing.extraLarge)
    }
}
