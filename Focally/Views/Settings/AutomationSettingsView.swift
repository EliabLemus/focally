import SwiftUI

struct AutomationSettingsView: View {
    @State private var focusModeEnabled: Bool = false

    var body: some View {
        VStack(spacing: FocallySpacing.large) {
            VStack(alignment: .leading, spacing: FocallySpacing.medium) {
                HStack(spacing: FocallySpacing.medium) {
                    ZStack {
                        RoundedRectangle(cornerRadius: FocallyRadius.small)
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

                        Text("Keep macOS notifications quiet while Focally is running a focus session.")
                            .font(.focallyBody)
                            .foregroundStyle(Color.focallyOutline)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    FocallyToggleButton(isOn: $focusModeEnabled)
                }
            }
            .padding(FocallySpacing.large)
            .focallyGlassCard()
        }
    }
}
