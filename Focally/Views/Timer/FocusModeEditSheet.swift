import SwiftUI

struct FocusModeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SlackService.self) private var slackService
    @Environment(EmojiUsageTracker.self) private var usageTracker

    @State private var draftMode: FocusMode
    @State private var localPreviewURL: URL?
    @State private var showEmojiPicker = false
    @State private var recentEmojis: [String] = []
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
                ZStack(alignment: .topLeading) {
                    TextField(
                        draftMode.name.isEmpty ? "e.g. :brain:" : draftMode.emoji,
                        text: $draftMode.emoji
                    )
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: draftMode.emoji) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        showEmojiPicker = trimmed == ":"
                        if showEmojiPicker {
                            recentEmojis = usageTracker.getRecentEmojis(forWorkspace: slackService.workspaceEmojiCodes)
                        }
                    }
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

                    if showEmojiPicker && !recentEmojis.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ScrollView {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                                    ForEach(recentEmojis, id: \.self) { emoji in
                                        let display = EmojiValidator.convertShortcodeToUnicode(emoji, workspaceEmojis: slackService.workspaceEmojiCodes) ?? emoji
                                        Button {
                                            draftMode.emoji = emoji
                                            showEmojiPicker = false
                                        } label: {
                                            Text(display)
                                                .font(.system(size: 22))
                                                .frame(width: 36, height: 36)
                                                .background(Color.focallySurfaceVariant.opacity(0.3))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .buttonStyle(.plain)
                                        .help(emoji)
                                    }
                                }
                            }
                            .frame(maxHeight: 140)
                        }
                        .padding(8)
                        .background(Color.focallySurfaceVariant)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .offset(y: 36)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeOut(duration: 0.15), value: showEmojiPicker)
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

                Text("Type `:` to see recent emojis, or enter a Slack shortcode")
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
        .frame(width: 420, height: 520)
        .background(Color.focallyBackground)
        .onTapGesture {
            if showEmojiPicker {
                showEmojiPicker = false
            }
        }
    }
}
