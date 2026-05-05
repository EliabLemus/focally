import SwiftUI

struct AutomationSettingsView: View {
    @State private var focusModeEnabled: Bool = false
    @State private var cfPreferencesEnabled: Bool = false

    var body: some View {
        VStack(spacing: FocallySpacing.lg) {
            // System Focus Mode Card
            VStack(alignment: .leading, spacing: FocallySpacing.md) {
                HStack(spacing: FocallySpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: FocallyRadius.sm)
                            .fill(Color.focallyPrimary.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: "moon.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.focallyPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("System Focus Mode")
                            .font(.focallyBodyBold)
                            .foregroundStyle(Color.focallyOnSurface)

                        Text("Sync directly with macOS Focus filters to silence native notifications and hide Dock badges.")
                            .font(.focallyBody)
                            .foregroundStyle(Color.focallyOutline)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    FocallyToggleButton(isOn: $focusModeEnabled)
                }
            }
            .padding(FocallySpacing.lg)
            .focallyCard()

            // CFPreferences Hook Card
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: FocallySpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: FocallyRadius.sm)
                            .fill(Color.focallyTertiaryContainer.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.focallyTertiary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("CFPreferences Hook")
                            .font(.focallyBodyBold)
                            .foregroundStyle(Color.focallyOnSurface)

                        Text("Low-level toggle using CoreFoundation to override global app behaviors.")
                            .font(.focallyBody)
                            .foregroundStyle(Color.focallyOutline)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    FocallyToggleButton(isOn: $cfPreferencesEnabled)
                }
                .padding(FocallySpacing.lg)

                Divider()
                    .background(Color.focallyOutlineVariant)
                    .padding(.horizontal, FocallySpacing.lg)

                HStack(spacing: FocallySpacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.focallyTertiary)

                    Text("Requires Accessibility permissions in System Settings")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyTertiary)
                }
                .padding(.horizontal, FocallySpacing.lg)
                .padding(.bottom, FocallySpacing.md)
            }
            .focallyCard()
        }
    }
}
