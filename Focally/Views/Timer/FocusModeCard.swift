import SwiftUI

struct FocusModeCard: View {
    @Environment(SlackService.self) private var slackService

    let mode: FocusMode
    let onStart: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onStart) {
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

                        Text(mode.name)
                            .font(.focallyH2)
                            .foregroundStyle(Color.focallyOnSurface)
                    }

                    Spacer()

                    Button(action: onEdit) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                            .padding(10)
                            .background(Color.focallySurfaceContainerHighest)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit \(mode.name)")
                }

                Text(mode.statusText)
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    badge(label: "\(mode.durationMinutes) min", systemImage: "timer")
                    if mode.enableDND {
                        badge(label: "DND", systemImage: "moon.fill")
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
        .contentShape(Rectangle())
        .buttonStyle(.plain)
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
