import SwiftUI

struct QuickStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: FocusSessionDraft

    let onStart: (FocusSessionDraft) -> Void

    init(mode: FocusMode, onStart: @escaping (FocusSessionDraft) -> Void) {
        _draft = State(initialValue: FocusSessionDraft(mode: mode))
        self.onStart = onStart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.large) {
            VStack(alignment: .leading, spacing: FocallySpacing.small) {
                LocalizedText("quick_start_title")
                    .font(.focallyH1)
                    .foregroundStyle(Color.focallyOnSurface)

                Text(draft.mode.name)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyPrimary)

                LocalizedText("quick_start_saved_mode_unchanged")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: FocallySpacing.small) {
                LocalizedText("quick_start_activity")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                TextField(
                    AppLanguage.shared.localizedString("quick_start_activity_placeholder"),
                    text: $draft.activity
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(AppLanguage.shared.localizedString("quick_start_activity"))
            }

            VStack(alignment: .leading, spacing: FocallySpacing.small) {
                LocalizedText("quick_start_duration")
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Stepper(
                    String(
                        format: AppLanguage.shared.localizedString("quick_start_duration_value"),
                        draft.durationMinutes
                    ),
                    value: $draft.durationMinutes,
                    in: 5...120,
                    step: 5
                )
                .font(.focallyBody)
                .accessibilityLabel(AppLanguage.shared.localizedString("quick_start_duration"))
                .accessibilityValue(
                    String(
                        format: AppLanguage.shared.localizedString("quick_start_duration_value"),
                        draft.durationMinutes
                    )
                )
            }
            .padding(FocallySpacing.medium)
            .background(Color.focallySurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack {
                Spacer()

                Button(AppLanguage.shared.localizedString("general_cancel")) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(AppLanguage.shared.localizedString("quick_start_start_session")) {
                    onStart(draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(FocallySpacing.large)
        .frame(width: 420)
        .background(Color.focallyBackground)
    }
}
