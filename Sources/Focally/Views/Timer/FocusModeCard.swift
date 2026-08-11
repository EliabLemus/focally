import SwiftUI

struct FocusModeCard: View {
    @Environment(SlackService.self) private var slackService

    let mode: FocusMode
    let onStart: () -> Void
    let onQuickStart: () -> Void
    let onEdit: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onStart) {
                cardContent
            }
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .accessibilityLabel(mode.name)
            .accessibilityHint(AppLanguage.shared.localizedString("quick_start_default_hint"))

            HStack(spacing: 8) {
                secondaryButton(
                    systemImage: "slider.horizontal.3",
                    labelKey: "quick_start_open_accessibility",
                    action: onQuickStart
                )

                secondaryButton(
                    systemImage: "gearshape.fill",
                    labelKey: "focus_type_edit_accessibility",
                    action: onEdit
                )
            }
            .padding(22)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    EmojiView(
                        mode.emoji,
                        customEmojiImageURLs: slackService.workspaceEmojiImageURLs,
                        workspaceEmojiCodes: slackService.workspaceEmojiCodes,
                        font: .system(size: 34),
                        dimension: 34
                    )
                    .fixedSize()
                    .frame(minWidth: 36, minHeight: 36)

                    Text(mode.name)
                        .font(.focallyH2)
                        .foregroundStyle(Color.focallyOnSurface)
                }

                Spacer()
                    .frame(minWidth: 88)
            }

            Text(mode.statusText)
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .lineLimit(2)

            HStack(spacing: 10) {
                badge(label: "\(mode.durationMinutes) min", systemImage: "timer")
                if mode.enableMacOSDND {
                    badge(label: AppLanguage.shared.localizedString("focus_mode_dnd"), systemImage: "moon.fill")
                }
                if mode.enablePomodoro {
                    badge(label: "\(mode.pomodoroWorkMinutes)/\(mode.pomodoroBreakMinutes)", systemImage: "repeat")
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.focallyOutline.opacity(0.9), lineWidth: 0.75)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(
                LinearGradient(
                    colors: [
                        Color.focallySurfaceContainerHigh,
                        Color.focallySurfaceContainerLow,
                        Color.focallySurfaceContainerLowest
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func secondaryButton(
        systemImage: String,
        labelKey: String,
        action: @escaping () -> Void
    ) -> some View {
        let label = String(
            format: AppLanguage.shared.localizedString(labelKey),
            mode.name
        )

        return Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .padding(10)
                .background(Color.focallySurfaceContainerHighest)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }

    private func badge(label: String, systemImage: String) -> some View {
        Label(label, systemImage: systemImage)
            .font(.focallyCaption)
            .foregroundStyle(Color.focallyOnSurface)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.focallySurfaceContainerHighest)
            .clipShape(Capsule())
    }
}
