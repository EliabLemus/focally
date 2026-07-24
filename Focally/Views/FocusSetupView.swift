import SwiftUI

struct FocusSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dontShowAgain = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Focally")
                .font(.focallyH1)
                .foregroundStyle(Color.focallyOnSurface)

            Text("Focus timer with smart Do Not Disturb and Slack integration")
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                setupRow(
                    title: "1. Notifications Permission",
                    detail: "Required to notify you when focus sessions start, almost end, and when breaks begin. We only send alerts for timer events."
                )
                setupRow(
                    title: "2. Three Focus Modes",
                    detail: "Focus Time (enables DND), Meeting & Inbox (leave DND off). Each mode has configurable duration, emoji, and status message."
                )
                setupRow(
                    title: "3. Slack Integration (Optional)",
                    detail: "Paste your Slack token in Settings to auto-update your status. Focally sets status for all modes and DND only for Focus Time."
                )
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