import SwiftUI

struct FocusSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dontShowAgain = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LocalizedText("setup_title")
                .font(.focallyH1)
                .foregroundStyle(Color.focallyOnSurface)

            LocalizedText("setup_subtitle")
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                setupRow(
                    titleKey: "setup_step1_title",
                    detailKey: "setup_step1_detail"
                )
                setupRow(
                    titleKey: "setup_step2_title",
                    detailKey: "setup_step2_detail"
                )
                setupRow(
                    titleKey: "setup_step3_title",
                    detailKey: "setup_step3_detail"
                )
            }
            .padding(18)
            .background(Color.focallySurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            Toggle("setup_dont_show_again", isOn: $dontShowAgain)

            HStack {
                Spacer()
                Button("general_done") {
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

    private func setupRow(titleKey: String, detailKey: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LocalizedText(titleKey)
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)
            LocalizedText(detailKey)
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
