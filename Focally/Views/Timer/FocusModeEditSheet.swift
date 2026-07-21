import SwiftUI

struct FocusModeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SlackService.self) private var slackService

    @State private var draftMode: FocusMode
    @State private var localPreviewURL: URL?
    let onSave: (FocusMode) -> Void
    var onDelete: (() -> Void)?

    init(mode: FocusMode, onSave: @escaping (FocusMode) -> Void, onDelete: (() -> Void)? = nil) {
        _draftMode = State(initialValue: mode)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Edit \(draftMode.name)")
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)
            VStack(alignment: .leading, spacing: 8) {
                Text("Emoji")
                    .font(.focallyBodyBold)
                TextField(
                    draftMode.name.isEmpty ? "e.g. :brain:" : draftMode.emoji,
                    text: $draftMode.emoji
                )
                .textFieldStyle(.roundedBorder)
                .task(id: draftMode.emoji) {
                    let shortcode = draftMode.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
                    if EmojiValidator.isCustomWorkspaceEmoji(shortcode, workspaceEmojiCodes: slackService.workspaceEmojiCodes),
                       let urlString = slackService.workspaceEmojiImageURLs[shortcode],
                       let url = URL(string: urlString) {
                        let fetched = await EmojiCacheService.shared.emoji(for: shortcode, remoteURL: url)
                        localPreviewURL = fetched
                    } else {
                        localPreviewURL = nil
                    }
                }

                HStack(spacing: 10) {
                    // Live preview: larger size for clear visibility while typing
                    if let localPreviewURL, let nsImage = NSImage(contentsOf: localPreviewURL) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    } else if EmojiValidator.isCustomWorkspaceEmoji(draftMode.emoji, workspaceEmojiCodes: slackService.workspaceEmojiCodes) {
                        ProgressView()
                            .frame(width: 40, height: 40)
                    } else {
                        Text(EmojiValidator.convertShortcodeToUnicode(draftMode.emoji, workspaceEmojis: slackService.workspaceEmojiCodes) ?? draftMode.emoji)
                            .font(.system(size: 28))
                            .frame(width: 40, height: 40)
                    }
                    Text(EmojiValidator.convertShortcodeToUnicode(draftMode.emoji, workspaceEmojis: slackService.workspaceEmojiCodes) ?? draftMode.emoji)
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                        .lineLimit(1)
                }

                Text("Enter Slack emoji shortcode, e.g. :brain:")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Status message")
                    .font(.focallyBodyBold)
                TextField("In focus mode", text: $draftMode.statusText)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(.focallyBodyBold)
                Stepper("\(draftMode.durationMinutes) min", value: $draftMode.durationMinutes, in: 5...120, step: 5)
            }

            Toggle("Enable Do Not Disturb in Slack and macOS", isOn: $draftMode.enableDND)
                .font(.focallyBody)

            if draftMode.enableDND {
                Toggle("Enable Pomodoro", isOn: $draftMode.enablePomodoro)
                    .font(.focallyBody)
            }

            if draftMode.enableDND && draftMode.enablePomodoro {
                DisclosureGroup("Pomodoro settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        Stepper("Work: \(draftMode.pomodoroWorkMinutes) min", value: $draftMode.pomodoroWorkMinutes, in: 5...120, step: 5)
                        Stepper("Break: \(draftMode.pomodoroBreakMinutes) min", value: $draftMode.pomodoroBreakMinutes, in: 1...30, step: 1)
                        Stepper("Rounds: \(draftMode.pomodoroRounds)", value: $draftMode.pomodoroRounds, in: 1...12, step: 1)
                    }
                    .padding(.top, 8)
                }
            }

            Spacer()

            HStack {
                if !draftMode.isBuiltIn {
                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Label("Delete Mode", systemImage: "trash")
                    }
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    onSave(draftMode.sanitized())
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420, height: 430)
        .background(Color.focallyBackground)
    }
}
