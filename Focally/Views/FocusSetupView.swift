import SwiftUI

struct FocusSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dontShowAgain = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Focally")
                .font(.focallyH1)
                .foregroundStyle(Color.focallyOnSurface)

            Text("Focally")
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                setupRow(title: "1. Connect Slack", detail: "Paste your token in Settings → Integrations so Focally can set status and load emoji shortcodes.")
                setupRow(title: "2. Verify DND", detail: "Focus Time enables macOS Do Not Disturb and Slack DND automatically. Meeting and Inbox leave them off by default.")
                setupRow(title: "3. Customize modes", detail: "Use the gear icon on a mode card to adjust the shortcode, status message, duration, and Pomodoro cadence.")
            }
            .padding(18)
            .background(Color.focallySurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            Toggle("Don't show this again", isOn: $dontShowAgain)

            HStack {
                Spacer()
                Button("Done") {
                    if dontShowAgain {
                        UserDefaults.standard.set(true, forKey: "FocallySimpleSetupCompleted")
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500, height: 340)
        .background(Color.focallyBackground)
    }

    private func setupRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)
            Text(detail)
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
