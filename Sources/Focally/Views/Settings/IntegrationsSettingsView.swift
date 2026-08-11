import SwiftUI

struct IntegrationsSettingsView: View {
    @Environment(SlackService.self) private var slackService
    @Environment(CalendarSlackIntegrationService.self) private var calendarService
    @Environment(FocusIntegrationService.self) private var focusIntegrationService
    @Environment(ManagedFocusShortcutsService.self) private var shortcutsService
    @Environment(AppLanguage.self) private var appLanguage

    @State private var slackToken = ""

    var body: some View {
        VStack(spacing: FocallySpacing.large) {
            slackCard
            calendarCard
            automationCard
        }
        .onAppear(perform: loadCredentials)
    }

    private var calendarCard: some View {
        @Bindable var calendarService = calendarService

        return VStack(alignment: .leading, spacing: FocallySpacing.medium) {
            HStack(spacing: FocallySpacing.medium) {
                iconTile(systemImage: "calendar", color: Color.focallyTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    LocalizedText("integrations_calendar_title")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)

                    LocalizedText("integrations_calendar_desc")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOutline)
                }

                Spacer()

                connectionBadge(connected: calendarService.hasCalendarAccess)
                FocallyToggleButton(isOn: calendarEnabledBinding)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                calendarEnabledBinding.wrappedValue.toggle()
            }

            Toggle("show_calendar_in_slack", isOn: $calendarService.showCalendarInSlack)
                .accessibilityLabel(
                    AppLanguage.shared.localizedString("show_calendar_in_slack")
                )

            LocalizedText("show_calendar_in_slack_help")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)

            Picker("calendar_title_display", selection: $calendarService.titleDisplay) {
                ForEach(CalendarTitleDisplay.allCases, id: \.self) { option in
                    Text(option.displayName)
                        .tag(option)
                }
            }
            .disabled(!calendarService.showCalendarInSlack)
            .accessibilityLabel(
                AppLanguage.shared.localizedString("calendar_title_display")
            )

            Toggle("use_event_emojis", isOn: $calendarService.useEventEmojisForStatus)
                .disabled(!calendarService.showCalendarInSlack)
                .accessibilityLabel(AppLanguage.shared.localizedString("use_event_emojis"))

            LocalizedText("use_event_emojis_help")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)

            Toggle(
                "activate_dnd_video_calls",
                isOn: $calendarService.activateDNDForVideoCalls
            )
            .disabled(!calendarService.showCalendarInSlack)
            .accessibilityLabel(
                AppLanguage.shared.localizedString("activate_dnd_video_calls")
            )

            if let calendarError = calendarService.connectionError, !calendarError.isEmpty {
                Text(calendarError)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyError)
            }
        }
        .padding(FocallySpacing.large)
        .focallyGlassCard()
    }

    private var slackCard: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.medium) {
            HStack(spacing: FocallySpacing.medium) {
                iconTile(systemImage: "message.fill", color: Color.focallyPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    LocalizedText("integrations_slack_title")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)

                    LocalizedText("integrations_slack_desc")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOutline)
                }

                Spacer()

                connectionBadge(connected: slackService.isConnected)
                FocallyToggleButton(isOn: slackEnabledBinding)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                slackEnabledBinding.wrappedValue.toggle()
            }

            credentialField(title: appLanguage.localizedString("integrations_user_token"), prompt: "xoxp-...", text: $slackToken, isSecure: true)

            LocalizedText("integrations_token_emoji_scope")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyTertiary)

            if !slackToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !slackToken.hasPrefix("xoxp-") && !slackToken.hasPrefix("xoxb-") {
                LocalizedText("integrations_invalid_format")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyError)
            }

            HStack(spacing: FocallySpacing.small) {
                primaryButton(appLanguage.localizedString("integrations_save_token"), action: saveSlackToken)
                secondaryButton(appLanguage.localizedString("integrations_test_connection"), action: testSlackConnection)
                    .disabled(
                        slackToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        slackService.connectionTestState == .working
                    )
                if slackService.connectionTestState == .working {
                    compactProgressView(labelKey: "integrations_testing_connection")
                }
                secondaryButton(appLanguage.localizedString("integrations_test_focus"), action: testSlackFocusIntegration)
                    .disabled(
                        slackToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        focusIntegrationService.slackTestState == .working
                    )
                if focusIntegrationService.slackTestState == .working {
                    compactProgressView(labelKey: "integrations_testing_focus")
                }
            }

            operationFeedback(
                state: slackService.connectionTestState,
                successKey: "integrations_connection_test_succeeded",
                retry: testSlackConnection
            )

            operationFeedback(
                state: focusIntegrationService.slackTestState,
                successKey: "integrations_focus_test_succeeded",
                retry: testSlackFocusIntegration
            )

            if slackService.isEnabled {
                if slackService.workspaceEmojiCodes.isEmpty {
                    LocalizedText("integrations_emoji_loading")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                } else {
                    HStack(spacing: FocallySpacing.extraSmall) {
                        Text(String(format: appLanguage.localizedString("integrations_emoji_loaded"), slackService.workspaceEmojiCodes.count))
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyTertiary)
                        Button("integrations_reload") {
                            slackService.refreshEmojiCatalogIfPossible()
                        }
                        .font(.focallyCaption)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.focallyPrimary)
                    }
                }
            }

        }
        .padding(FocallySpacing.large)
        .focallyGlassCard()
    }

    private var automationCard: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.medium) {
            HStack(spacing: FocallySpacing.medium) {
                iconTile(systemImage: "moon.circle.fill", color: Color.focallySecondary)

                VStack(alignment: .leading, spacing: 2) {
                    LocalizedText("integrations_dnd_title")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)

                    LocalizedText("integrations_dnd_desc")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOutline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: FocallySpacing.small) {
                if focusIntegrationService.areShortcutsInstalled {
                    Label("integrations_shortcuts_installed", systemImage: "checkmark.circle.fill")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyPrimary)
                } else {
                    Button {
                        shortcutsService.installShortcuts()
                    } label: {
                        Label("integrations_install_shortcuts", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button {
                    shortcutsService.refreshInstallationState()
                } label: {
                    LocalizedText("integrations_refresh")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text(focusIntegrationService.statusText)
                .font(.focallyCaption)
                .foregroundStyle(focusIntegrationService.lastError == nil ? Color.focallyOnSurfaceVariant : Color.focallyError)

            if let error = shortcutsService.lastError, !error.isEmpty {
                Text(error)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyError)
            }
        }
        .padding(FocallySpacing.large)
        .focallyGlassCard()
    }

    private func iconTile(systemImage: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: FocallyRadius.small)
                .fill(color.opacity(0.1))
                .frame(width: 40, height: 40)
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundStyle(color)
        }
    }

    private var slackEnabledBinding: Binding<Bool> {
        Binding(
            get: { slackService.isEnabled },
            set: { newValue in
                slackService.isEnabled = newValue
                if newValue {
                    slackService.refreshEmojiCatalogIfPossible()
                }
            }
        )
    }

    private var calendarEnabledBinding: Binding<Bool> {
        Binding(
            get: { calendarService.isEnabled },
            set: { calendarService.setEnabled($0) }
        )
    }

    private func loadCredentials() {
        slackToken = slackService.token ?? ""
        slackService.refreshEmojiCatalogIfPossible()
    }

    private func saveSlackToken() {
        slackService.token = slackToken.trimmingCharacters(in: .whitespacesAndNewlines)
        slackService.isEnabled = !(slackService.token ?? "").isEmpty
        slackService.refreshEmojiCatalogIfPossible()
    }

    private func testSlackConnection() {
        slackService.testConnection()
    }

    private func testSlackFocusIntegration() {
        focusIntegrationService.runSlackTest()
    }

    private func compactProgressView(labelKey: String) -> some View {
        ProgressView()
            .controlSize(.small)
            .accessibilityLabel(appLanguage.localizedString(labelKey))
    }

    @ViewBuilder
    private func operationFeedback(
        state: SlackOperationState,
        successKey: String,
        retry: @escaping () -> Void
    ) -> some View {
        switch state {
        case .idle, .working:
            EmptyView()
        case .success:
            LocalizedText(successKey)
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyPrimary)
        case .failed(let message):
            HStack(spacing: FocallySpacing.extraSmall) {
                Text(SlackService.localizedOperationError(message, localizedString: appLanguage.localizedString))
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyError)

                Button(appLanguage.localizedString("integrations_retry"), action: retry)
                    .font(.focallyCaption)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.focallyPrimary)
            }
        }
    }

    private func connectionBadge(connected: Bool) -> some View {
        Text(connected ? appLanguage.localizedString("integrations_connected") : appLanguage.localizedString("integrations_disconnected"))
            .font(.focallyCaption)
            .foregroundStyle(connected ? Color.focallyPrimary : Color.focallyOnSurfaceVariant)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((connected ? Color.focallyPrimary : Color.focallySurfaceContainerHighest).opacity(0.12))
            .clipShape(Capsule())
    }

    private func credentialField(title: String, prompt: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)

            Group {
                if isSecure {
                    SecureField(prompt, text: text)
                } else {
                    TextField(prompt, text: text)
                }
            }
            .textFieldStyle(.roundedBorder)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
    }
}
