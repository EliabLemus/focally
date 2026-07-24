import SwiftUI

struct FocusModeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SlackService.self) private var slackService
    @Environment(EmojiUsageTracker.self) private var usageTracker

    @State private var draftMode: FocusMode
    @State private var localPreviewURL: URL?
    @State private var showEmojiPicker = false
    @State private var recentEmojis: [String] = []
    @State private var searchResults: [(shortcode: String, emoji: String)] = []
    let onSave: (FocusMode) -> Void
    var onDelete: (() -> Void)?

    // Break label emoji picker state
    @State private var showBreakLabelEmojiPicker = false
    @State private var breakLabelRecentEmojis: [String] = []
    @State private var breakLabelSearchResults: [(shortcode: String, emoji: String)] = []
    @State private var breakLabelLocalPreviewURL: URL?

    // Status message emoji picker state
    @State private var showStatusEmojiPicker = false
    @State private var statusRecentEmojis: [String] = []
    @State private var statusSearchResults: [(shortcode: String, emoji: String)] = []

    init(mode: FocusMode, onSave: @escaping (FocusMode) -> Void, onDelete: (() -> Void)? = nil) {
        _draftMode = State(initialValue: mode)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    // MARK: - Search Queries

    private var searchQuery: String {
        let t = draftMode.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix(":"), t.count > 1 else { return "" }
        return String(t.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
    }

    private var breakLabelBinding: Binding<String> {
        Binding(
            get: { draftMode.breakLabel ?? "" },
            set: { draftMode.breakLabel = $0.isEmpty ? nil : $0 }
        )
    }

    private var breakLabelSearchQuery: String {
        let t = breakLabelBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix(":"), t.count > 1 else { return "" }
        return String(t.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
    }

    private var statusSearchQuery: String {
        let t = draftMode.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix(":"), t.count > 1 else { return "" }
        return String(t.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(String(format: String(localized: "edit_mode_title"), draftMode.name))
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ========== Section: Basic Settings ==========
                    Text("edit_mode_section_basic")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)

                    VStack(alignment: .leading, spacing: 18) {
                        // MARK: Mode Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("edit_mode_name")
                                .font(.focallyBodyBold)

                            TextField(String(localized: "edit_mode_name_placeholder"), text: $draftMode.name)
                                .textFieldStyle(.roundedBorder)
                        }

                        // MARK: Mode Emoji
                        VStack(alignment: .leading, spacing: 8) {
                            Text("edit_mode_emoji")
                                .font(.focallyBodyBold)

                            ZStack(alignment: .topLeading) {
                                HStack(spacing: 8) {
                                    TextField(
                                        draftMode.name.isEmpty ? String(localized: "edit_mode_emoji_placeholder_search") : draftMode.emoji,
                                        text: $draftMode.emoji
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: draftMode.emoji) { _, newValue in
                                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if trimmed == ":" {
                                            showEmojiPicker = true
                                            recentEmojis = usageTracker.getRecentEmojis(forWorkspace: slackService.workspaceEmojiCodes)
                                            searchResults = []
                                        } else if trimmed.hasPrefix(":") && trimmed.count > 1 {
                                            showEmojiPicker = true
                                            recentEmojis = []
                                            let q = String(trimmed.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
                                            searchResults = EmojiValidator.searchShortcodes(q, workspaceEmojiCodes: slackService.workspaceEmojiCodes)
                                        } else {
                                            showEmojiPicker = false
                                            searchResults = []
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

                                    Button {
                                        closeAllPickersExcept("emoji")
                                        showEmojiPicker.toggle()
                                        if showEmojiPicker {
                                            recentEmojis = usageTracker.getRecentEmojis(forWorkspace: slackService.workspaceEmojiCodes)
                                        }
                                    } label: {
                                        Image(systemName: "face.smiling")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                                    }
                                    .buttonStyle(.plain)
                                    .help(String(localized: "emoji_picker_help"))
                                }

                                if showEmojiPicker && (!recentEmojis.isEmpty || !searchResults.isEmpty) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ScrollView {
                                            if !searchResults.isEmpty {
                                                LazyVStack(spacing: 2) {
                                                    ForEach(searchResults, id: \.shortcode) { item in
                                                        Button {
                                                            draftMode.emoji = item.shortcode
                                                            showEmojiPicker = false
                                                            searchResults = []
                                                        } label: {
                                                            HStack(spacing: 8) {
                                                                Text(item.emoji.isEmpty ? "🔗" : item.emoji)
                                                                    .font(.system(size: 20))
                                                                    .frame(width: 30, alignment: .center)
                                                                Text(item.shortcode)
                                                                    .font(.focallyBody)
                                                                    .foregroundStyle(Color.focallyOnSurface)
                                                                Spacer()
                                                            }
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .contentShape(Rectangle())
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                            } else {
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
                            }

                            Text("edit_mode_emoji_hint")
                                .font(.focallyCaption)
                                .foregroundStyle(Color.focallyOnSurfaceVariant)
                        }

                        // MARK: Status Message
                        VStack(alignment: .leading, spacing: 8) {
                            Text("edit_mode_status_message")
                                .font(.focallyBodyBold)

                            HStack(spacing: 8) {
                                TextField(String(localized: "edit_mode_status_placeholder"), text: $draftMode.statusText)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: draftMode.statusText) { _, newValue in
                                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if trimmed == ":" {
                                            showStatusEmojiPicker = true
                                            statusRecentEmojis = usageTracker.getRecentEmojis(forWorkspace: slackService.workspaceEmojiCodes)
                                            statusSearchResults = []
                                        } else if trimmed.hasPrefix(":") && trimmed.count > 1 {
                                            showStatusEmojiPicker = true
                                            statusRecentEmojis = []
                                            let q = String(trimmed.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
                                            statusSearchResults = EmojiValidator.searchShortcodes(q, workspaceEmojiCodes: slackService.workspaceEmojiCodes)
                                        } else {
                                            showStatusEmojiPicker = false
                                            statusSearchResults = []
                                        }
                                    }

                                Button {
                                    closeAllPickersExcept("status")
                                    showStatusEmojiPicker.toggle()
                                    if showStatusEmojiPicker {
                                        statusRecentEmojis = usageTracker.getRecentEmojis(forWorkspace: slackService.workspaceEmojiCodes)
                                    }
                                } label: {
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                                }
                                .buttonStyle(.plain)
                                .help(String(localized: "emoji_picker_help"))
                            }

                            // Emoji picker overlay for status message
                            if showStatusEmojiPicker && (!statusRecentEmojis.isEmpty || !statusSearchResults.isEmpty) {
                                VStack(alignment: .leading, spacing: 4) {
                                    ScrollView {
                                        if !statusSearchResults.isEmpty {
                                            LazyVStack(spacing: 2) {
                                                ForEach(statusSearchResults, id: \.shortcode) { item in
                                                    Button {
                                                        draftMode.statusText += item.shortcode
                                                        showStatusEmojiPicker = false
                                                        statusSearchResults = []
                                                    } label: {
                                                        HStack(spacing: 8) {
                                                            Text(item.emoji.isEmpty ? "🔗" : item.emoji)
                                                                .font(.system(size: 20))
                                                                .frame(width: 30, alignment: .center)
                                                            Text(item.shortcode)
                                                                .font(.focallyBody)
                                                                .foregroundStyle(Color.focallyOnSurface)
                                                            Spacer()
                                                        }
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .contentShape(Rectangle())
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        } else {
                                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                                                ForEach(statusRecentEmojis, id: \.self) { emoji in
                                                    let display = EmojiValidator.convertShortcodeToUnicode(emoji, workspaceEmojis: slackService.workspaceEmojiCodes) ?? emoji
                                                    Button {
                                                        draftMode.statusText += emoji
                                                        showStatusEmojiPicker = false
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
                                    }
                                    .frame(maxHeight: 140)
                                }
                                .padding(8)
                                .background(Color.focallySurfaceVariant)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                                .offset(y: 36)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .animation(.easeOut(duration: 0.15), value: showStatusEmojiPicker)
                            }
                        }

                        // MARK: Break Label (only visible when pomodoro is enabled)
                        if draftMode.enablePomodoro {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("edit_mode_break_label")
                                .font(.focallyBodyBold)

                            ZStack(alignment: .topLeading) {
                                HStack(spacing: 8) {
                                    TextField(String(localized: "edit_mode_break_placeholder"), text: breakLabelBinding)
                                        .textFieldStyle(.roundedBorder)
                                        .onChange(of: breakLabelBinding.wrappedValue) { _, newValue in
                                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if trimmed == ":" {
                                                showBreakLabelEmojiPicker = true
                                                breakLabelRecentEmojis = usageTracker.getRecentEmojis(forWorkspace: slackService.workspaceEmojiCodes)
                                                breakLabelSearchResults = []
                                            } else if trimmed.hasPrefix(":") && trimmed.count > 1 {
                                                showBreakLabelEmojiPicker = true
                                                breakLabelRecentEmojis = []
                                                let q = String(trimmed.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
                                                breakLabelSearchResults = EmojiValidator.searchShortcodes(q, workspaceEmojiCodes: slackService.workspaceEmojiCodes)
                                            } else {
                                                showBreakLabelEmojiPicker = false
                                                breakLabelSearchResults = []
                                            }
                                        }

                                    Button {
                                        closeAllPickersExcept("breakLabel")
                                        showBreakLabelEmojiPicker.toggle()
                                        if showBreakLabelEmojiPicker {
                                            breakLabelRecentEmojis = usageTracker.getRecentEmojis(forWorkspace: slackService.workspaceEmojiCodes)
                                        }
                                    } label: {
                                        Image(systemName: "face.smiling")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                                    }
                                    .buttonStyle(.plain)
                                    .help(String(localized: "emoji_picker_help"))
                                }

                                if showBreakLabelEmojiPicker && (!breakLabelRecentEmojis.isEmpty || !breakLabelSearchResults.isEmpty) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ScrollView {
                                            if !breakLabelSearchResults.isEmpty {
                                                LazyVStack(spacing: 2) {
                                                    ForEach(breakLabelSearchResults, id: \.shortcode) { item in
                                                        Button {
                                                            draftMode.breakLabel = item.shortcode
                                                            showBreakLabelEmojiPicker = false
                                                            breakLabelSearchResults = []
                                                        } label: {
                                                            HStack(spacing: 8) {
                                                                Text(item.emoji.isEmpty ? "🔗" : item.emoji)
                                                                    .font(.system(size: 20))
                                                                    .frame(width: 30, alignment: .center)
                                                                Text(item.shortcode)
                                                                    .font(.focallyBody)
                                                                    .foregroundStyle(Color.focallyOnSurface)
                                                                Spacer()
                                                            }
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .contentShape(Rectangle())
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                            } else {
                                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                                                    ForEach(breakLabelRecentEmojis, id: \.self) { emoji in
                                                        let display = EmojiValidator.convertShortcodeToUnicode(emoji, workspaceEmojis: slackService.workspaceEmojiCodes) ?? emoji
                                                        Button {
                                                            draftMode.breakLabel = emoji
                                                            showBreakLabelEmojiPicker = false
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
                                        }
                                        .frame(maxHeight: 140)
                                    }
                                    .padding(8)
                                    .background(Color.focallySurfaceVariant)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                                    .offset(y: 36)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                    .animation(.easeOut(duration: 0.15), value: showBreakLabelEmojiPicker)
                                }
                            }

                            Text("edit_mode_break_hint")
                                .font(.focallyCaption)
                                .foregroundStyle(Color.focallyOnSurfaceVariant)
                        }
                        }

                        // MARK: Duration
                        VStack(alignment: .leading, spacing: 8) {
                            Text("edit_mode_duration")
                                .font(.focallyBodyBold)
                            Stepper(String(format: String(localized: "edit_mode_duration_value"), draftMode.durationMinutes), value: $draftMode.durationMinutes, in: 1...600, step: 5)
                                .font(.focallyBody)
                        }
                    }

                    Divider()
                        .background(Color.focallyOutlineVariant)
                        .padding(.vertical, 8)

                    // ========== Section: Advanced Settings ==========
                    Text("edit_mode_section_advanced")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)

                    VStack(alignment: .leading, spacing: 18) {
                        // DND Toggle (independent)
                        Toggle("edit_mode_enable_dnd", isOn: $draftMode.enableDND)
                            .font(.focallyBody)

                        // Pomodoro Toggle (independent)
                        Toggle("edit_mode_enable_pomodoro", isOn: $draftMode.enablePomodoro)
                            .font(.focallyBody)

                        // Pomodoro Settings (DisclosureGroup, shown when Pomodoro enabled)
                        if draftMode.enablePomodoro {
                            DisclosureGroup("edit_mode_pomodoro_settings") {
                                VStack(alignment: .leading, spacing: 12) {
                                    Stepper(String(format: String(localized: "edit_mode_work"), draftMode.pomodoroWorkMinutes), value: $draftMode.pomodoroWorkMinutes, in: 5...120, step: 5)
                                    Stepper(String(format: String(localized: "edit_mode_short_break"), draftMode.pomodoroBreakMinutes), value: $draftMode.pomodoroBreakMinutes, in: 1...30, step: 1)
                                    Stepper(String(format: String(localized: "edit_mode_long_break"), draftMode.pomodoroLongBreakMinutes), value: $draftMode.pomodoroLongBreakMinutes, in: 5...60, step: 5)
                                    Stepper(String(format: String(localized: "edit_mode_rounds"), draftMode.pomodoroRounds), value: $draftMode.pomodoroRounds, in: 1...12, step: 1)
                                }
                                .padding(.top, 8)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }

            HStack {
                if !draftMode.isBuiltIn {
                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Label("edit_mode_delete", systemImage: "trash")
                    }
                }

                Spacer()

                Button("general_cancel") {
                    dismiss()
                }
                Button("general_save") {
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
            closeAllPickers()
        }
    }

    // MARK: - Picker Management

    private func closeAllPickers() {
        if showEmojiPicker { showEmojiPicker = false }
        if showBreakLabelEmojiPicker { showBreakLabelEmojiPicker = false }
        if showStatusEmojiPicker { showStatusEmojiPicker = false }
    }

    private func closeAllPickersExcept(_ keepOpen: String) {
        if keepOpen != "emoji" && showEmojiPicker { showEmojiPicker = false }
        if keepOpen != "breakLabel" && showBreakLabelEmojiPicker { showBreakLabelEmojiPicker = false }
        if keepOpen != "status" && showStatusEmojiPicker { showStatusEmojiPicker = false }
    }
}
