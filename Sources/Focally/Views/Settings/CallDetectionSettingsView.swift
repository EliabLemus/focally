import SwiftUI

/// "Calls" settings section (TASK-057). All four controls persist via
/// `CallDetectionSettingsStore` and take effect on the NEXT call — no restart.
struct CallDetectionSettingsView: View {
    @Environment(AppLanguage.self) private var appLanguage
    @Environment(SlackService.self) private var slackService
    @State private var store = CallDetectionSettingsStore()

    @State private var callStatusEnabled = true
    @State private var callStatusMessage = CallDetectionSettings.defaultStatusMessage
    @State private var enableDNDDuringCalls = true
    @State private var pauseFocusDuringCalls = true
    // 3.1: what a capture WITHOUT an active calendar meeting means.
    @State private var uncorroboratedBrowserCapture: CallCaptureMode = .notice

    // TASK-058: per-client Slack emoji overrides.
    @State private var emojiOverrides: [String: String] = [:]
    @State private var unknownCallClientEmoji = ""
    @State private var activeEmojiPickerKey: String?
    @State private var emojiSearchResults: [(shortcode: String, emoji: String)] = []

    private static let messageCharacterLimit = CallDetectionSettings.slackStatusCharacterLimit

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.medium) {
            Toggle("calls_update_slack_status", isOn: $callStatusEnabled)
                .accessibilityLabel(AppLanguage.shared.localizedString("calls_update_slack_status"))

            VStack(alignment: .leading, spacing: 6) {
                TextField(
                    CallDetectionSettings.defaultStatusMessage,
                    text: $callStatusMessage
                )
                .textFieldStyle(.roundedBorder)
                .onChange(of: callStatusMessage) { _, newValue in
                    if newValue.count > Self.messageCharacterLimit {
                        callStatusMessage = String(newValue.prefix(Self.messageCharacterLimit))
                    }
                }

                Text("\(callStatusMessage.count)/\(Self.messageCharacterLimit)")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)

                LocalizedText("calls_status_message_help")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Toggle("calls_enable_dnd", isOn: $enableDNDDuringCalls)
                .accessibilityLabel(AppLanguage.shared.localizedString("calls_enable_dnd"))

            Toggle("calls_pause_focus", isOn: $pauseFocusDuringCalls)
                .accessibilityLabel(AppLanguage.shared.localizedString("calls_pause_focus"))

            // 3.1: capture without an active calendar meeting.
            VStack(alignment: .leading, spacing: 6) {
                Picker("calls_uncorroborated_capture", selection: $uncorroboratedBrowserCapture) {
                    Text("calls_capture_mode_call").tag(CallCaptureMode.call)
                    Text("calls_capture_mode_notice").tag(CallCaptureMode.notice)
                }
                .pickerStyle(.radioGroup)
                .accessibilityLabel(AppLanguage.shared.localizedString("calls_uncorroborated_capture"))

                LocalizedText("calls_capture_mode_help")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            // 6.6: documented notification-blocking limit.
            LocalizedText("calls_time_sensitive_note")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)

            // TASK-058: per-app Slack emoji section.
            VStack(alignment: .leading, spacing: 8) {
                LocalizedText("calls_emoji_by_app")
                    .font(.focallyBodyBold)

                ForEach(CallClientCatalog.defaultClients, id: \.bundlePrefix) { client in
                    emojiOverrideRow(
                        key: client.bundlePrefix,
                        label: client.displayName,
                        binding: Binding(
                            get: { emojiOverrides[client.bundlePrefix] ?? "" },
                            set: {
                                emojiOverrides[client.bundlePrefix] = $0
                                persistEmojiOverrides()
                            }
                        )
                    )
                }

                emojiOverrideRow(
                    key: CallClientCatalog.unknownClient.bundlePrefix,
                    label: AppLanguage.shared.localizedString("calls_emoji_unknown_client"),
                    binding: Binding(
                        get: { unknownCallClientEmoji },
                        set: {
                            unknownCallClientEmoji = $0
                            persistEmojiOverrides()
                        }
                    )
                )

                LocalizedText("calls_emoji_help")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            LocalizedText("calls_help")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
        }
        .padding(FocallySpacing.large)
        .focallyGlassCard()
        .onAppear(perform: load)
        .onChange(of: callStatusEnabled) { _, newValue in
            var settings = store.currentSettings()
            settings.callStatusEnabled = newValue
            store.save(settings)
        }
        .onChange(of: enableDNDDuringCalls) { _, newValue in
            var settings = store.currentSettings()
            settings.enableDNDDuringCalls = newValue
            store.save(settings)
        }
        .onChange(of: pauseFocusDuringCalls) { _, newValue in
            var settings = store.currentSettings()
            settings.pauseFocusDuringCalls = newValue
            store.save(settings)
        }
        .onChange(of: uncorroboratedBrowserCapture) { _, newValue in
            var settings = store.currentSettings()
            settings.uncorroboratedBrowserCapture = newValue
            store.save(settings)
        }
        .onChange(of: callStatusMessage) { oldValue, newValue in
            // Persist on edit: empty/whitespace falls back to the default text.
            guard newValue != oldValue || newValue != storedMessage() else { return }
            var settings = store.currentSettings()
            settings.callStatusMessage = newValue
            store.save(settings)
        }
    }

    private func storedMessage() -> String {
        store.currentSettings().callStatusMessage
    }

    // MARK: - TASK-058: emoji overrides

    /// Normalizes a typed value into a `:shortcode:` form (adds colons if missing).
    private func normalizedEmoji(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        var value = trimmed
        if !value.hasPrefix(":") { value = ":" + value }
        if value.count > 1 && !value.hasSuffix(":") { value += ":" }
        return value
    }

    /// True when the workspace emoji list is loaded and does not contain the
    /// (normalized) shortcode. Non-blocking — best-effort validation only.
    private func isEmojiMissingFromWorkspace(_ raw: String) -> Bool {
        let value = normalizedEmoji(raw)
        guard !value.isEmpty else { return false }
        let codes = slackService.workspaceEmojiCodes
        guard !codes.isEmpty else { return false }
        return !codes.contains(value)
    }

    private func persistEmojiOverrides() {
        var settings = store.currentSettings()
        // Store only normalized, non-empty values; normalize the unknown too.
        var normalized: [String: String] = [:]
        for (key, value) in emojiOverrides {
            let v = normalizedEmoji(value)
            if !v.isEmpty { normalized[key] = v }
        }
        settings.callClientEmojiOverrides = normalized
        let unknown = normalizedEmoji(unknownCallClientEmoji)
        settings.unknownCallClientEmoji = unknown.isEmpty ? nil : unknown
        store.save(settings)
    }

    private func updateEmojiSearch(key: String, raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(":"), trimmed.count > 1 else {
            if activeEmojiPickerKey == key {
                activeEmojiPickerKey = nil
                emojiSearchResults = []
            }
            return
        }
        let q = String(trimmed.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
        guard !q.isEmpty else {
            activeEmojiPickerKey = key
            emojiSearchResults = []
            return
        }
        activeEmojiPickerKey = key
        emojiSearchResults = EmojiValidator.searchShortcodes(q, workspaceEmojiCodes: slackService.workspaceEmojiCodes)
    }

    private func applyEmojiSearchResult(key: String, shortcode: String) {
        if key == CallClientCatalog.unknownClient.bundlePrefix {
            unknownCallClientEmoji = shortcode
        } else {
            emojiOverrides[key] = shortcode
        }
        activeEmojiPickerKey = nil
        emojiSearchResults = []
        persistEmojiOverrides()
    }

    @ViewBuilder
    private func emojiOverrideRow(key: String, label: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.focallyBody)
                    .frame(width: 160, alignment: .leading)
                TextField(
                    AppLanguage.shared.localizedString("calls_emoji_placeholder"),
                    text: binding
                )
                .textFieldStyle(.roundedBorder)
                .onChange(of: binding.wrappedValue) { _, newValue in
                    updateEmojiSearch(key: key, raw: newValue)
                }
            }

            if isEmojiMissingFromWorkspace(binding.wrappedValue) {
                LocalizedText("calls_emoji_not_in_workspace")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.orange)
            }

            if activeEmojiPickerKey == key, !emojiSearchResults.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(emojiSearchResults, id: \.shortcode) { item in
                                Button {
                                    applyEmojiSearchResult(key: key, shortcode: item.shortcode)
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
                    }
                    .frame(maxHeight: 160)
                }
            }
        }
    }

    private func load() {
        let settings = store.currentSettings()
        callStatusEnabled = settings.callStatusEnabled
        enableDNDDuringCalls = settings.enableDNDDuringCalls
        pauseFocusDuringCalls = settings.pauseFocusDuringCalls
        uncorroboratedBrowserCapture = settings.uncorroboratedBrowserCapture
        // Surface the stored (sanitized) message so empty shows the default.
        callStatusMessage = store.currentSettings().callStatusMessage
        emojiOverrides = settings.callClientEmojiOverrides
        unknownCallClientEmoji = settings.unknownCallClientEmoji ?? ""
    }
}
