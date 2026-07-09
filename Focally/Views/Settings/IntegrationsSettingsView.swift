import SwiftUI

struct IntegrationsSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(SlackService.self) private var slackService
    @Environment(GoogleCalendarService.self) private var calendarService
    @Environment(FocusIntegrationService.self) private var focusIntegrationService
    @Environment(ManagedFocusShortcutsService.self) private var managedShortcutsService
    @Environment(ShortcutDropHandler.self) private var shortcutDropHandler

    @State private var slackToken = ""
    @State private var googleClientID = ""
    @State private var googleClientSecret = ""
    @State private var slackTestFeedback: String?

    var body: some View {
        VStack(spacing: FocallySpacing.large) {
            slackCard
            calendarCard
            focusIntegrationCard
        }
        .onAppear(perform: loadCredentials)
    }

    private var slackCard: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.medium) {
            HStack(spacing: FocallySpacing.medium) {
                iconTile(systemImage: "message.fill", color: Color.focallyPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Slack Integration")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)

                    Text("Post focus status updates to Slack channels.")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOutline)
                }

                Spacer()

                connectionBadge(connected: slackService.isConnected)
                FocallyToggleButton(isOn: slackEnabledBinding)
            }

            credentialField(title: "User Token", prompt: "xoxp-...", text: $slackToken, isSecure: true)

            Text("Token requires emoji:read scope for emoji catalog")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyTertiary)

            // Inline validation for Slack token format
            if !slackToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !slackToken.hasPrefix("xoxp-") && !slackToken.hasPrefix("xoxb-") {
                Text("Invalid format. Slack tokens should start with xoxp- or xoxb-")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyError)
            }

            HStack(spacing: FocallySpacing.small) {
                primaryButton("Save Token", action: saveSlackToken)
                secondaryButton("Test Connection", action: testSlackConnection)
                    .disabled(slackToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                secondaryButton("Test Focus Integration", action: testSlackFocusIntegration)
                    .disabled(slackToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let slackError = slackService.connectionError, !slackError.isEmpty {
                Text(slackError)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyError)
            }

            if slackService.isEnabled {
                if slackService.workspaceEmojiCodes.isEmpty {
                    Text("Slack emoji catalog: Loading...")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                } else {
                    HStack(spacing: FocallySpacing.extraSmall) {
                        Text("Slack emoji catalog: \(slackService.workspaceEmojiCodes.count) emojis loaded")
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyTertiary)
                        Button("Reload") {
                            slackService.refreshEmojiCatalogIfPossible()
                        }
                        .font(.focallyCaption)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.focallyPrimary)
                    }
                }
            }

            if let slackTestFeedback, !slackTestFeedback.isEmpty {
                Text(slackTestFeedback)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }
        }
        .padding(FocallySpacing.large)
        .focallyGlassCard()
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.medium) {
            HStack(spacing: FocallySpacing.medium) {
                iconTile(systemImage: "calendar", color: Color.focallyTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Calendar")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)

                    Text("Sync focus sessions with your calendar events.")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOutline)
                }

                Spacer()

                connectionBadge(connected: calendarService.isSignedIn)
                FocallyToggleButton(isOn: calendarEnabledBinding)
            }

            credentialField(title: "Client ID", prompt: "Google OAuth client ID", text: $googleClientID)
            credentialField(title: "Client Secret", prompt: "Google OAuth client secret", text: $googleClientSecret, isSecure: true)

            HStack(spacing: FocallySpacing.small) {
                primaryButton("Save Credentials", action: saveGoogleCredentials)
                secondaryButton(calendarService.isSignedIn ? "Disconnect" : "Connect", action: toggleGoogleConnection)
            }

            if let calendarError = calendarService.connectionError, !calendarError.isEmpty {
                Text(calendarError)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyError)
            }
        }
        .padding(FocallySpacing.large)
        .focallyGlassCard()
    }

    private var focusIntegrationCard: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.medium) {
            HStack(spacing: FocallySpacing.medium) {
                iconTile(systemImage: "moon.circle.fill", color: .purple)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus Integration")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)

                    Text("Focally handles quiet mode automatically. It turns on Do Not Disturb first and only uses the bundled shortcuts as a backup detail if needed.")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOutline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            soundPreviewSection

            VStack(alignment: .leading, spacing: 12) {
                focusStatusRow(
                    title: "Direct Do Not Disturb",
                    subtitle: "Always attempted when a focus block starts or resumes.",
                    isReady: true
                )

                focusStatusRow(
                    title: "Bundled shortcut backup",
                    subtitle: managedShortcutsService.allManagedShortcutsInstalled
                        ? "Installed and ready if Apple needs the visual Add step."
                        : "Optional: open once so Apple can show the visual Add step.",
                    isReady: managedShortcutsService.allManagedShortcutsInstalled
                )

                if let warning = focusIntegrationService.lastShortcutIssue, !warning.isEmpty {
                    Text(warning)
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }

                HStack(spacing: FocallySpacing.small) {
                    primaryButton("Stage Shortcut Files") {
                        managedShortcutsService.prepareAndOpenForImport()
                    }

                    secondaryButton("Refresh Status") {
                        managedShortcutsService.refreshInstallationState()
                    }
                }

                Text(focusIntegrationService.statusText)
                    .font(.focallyCaption)
                    .foregroundStyle(focusIntegrationService.lastError == nil ? Color.focallyOnSurfaceVariant : Color.focallyError)
            }
            .padding(FocallySpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: FocallyRadius.medium)
                    .fill(Color.focallySurfaceContainerLow)
            )
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

    private func focusStatusRow(title: String, subtitle: String, isReady: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isReady ? Color.focallyPrimary : Color.focallyOutline)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)
                Text(subtitle)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Spacer()
        }
    }

    private var soundPreviewSection: some View {
        let soundPlayer = SoundPlayerService.shared

        return VStack(alignment: .leading, spacing: FocallySpacing.small) {
            Text("Completion Sound Preview")
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)

            Text("Choose a completion sound and preview it instantly.")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)

            HStack(spacing: FocallySpacing.small) {
                Picker("Completion Sound", selection: completionSoundBinding(for: soundPlayer)) {
                    ForEach(SoundPlayerService.CompletionSoundVariant.allCases) { variant in
                        Text(variant.rawValue).tag(variant.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 240)

                Button("Preview") {
                    soundPlayer.previewSound(named: soundPlayer.completionSoundName)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(FocallySpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: FocallyRadius.medium)
                .fill(Color.focallySurfaceContainerLow)
        )
    }

    private func completionSoundBinding(for soundPlayer: SoundPlayerService) -> Binding<String> {
        Binding(
            get: { soundPlayer.completionSoundName },
            set: { newValue in
                soundPlayer.completionSoundName = newValue
                settingsStore.completionSoundName = newValue
                settingsStore.saveSoundSettings()
            }
        )
    }

    private func connectionBadge(connected: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connected ? Color.focallyPrimary : Color.focallyOutline)
                .frame(width: 6, height: 6)

            Text(connected ? "Connected" : "Not Connected")
                .font(.focallyCaption)
                .foregroundStyle(connected ? Color.focallyPrimary : Color.focallyOutline)
        }
        .padding(.horizontal, FocallySpacing.small)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: FocallyRadius.extraSmall)
                .fill(connected ? Color.focallyPrimary.opacity(0.1) : Color.focallySurfaceContainer)
        )
    }

    private func credentialField(title: String, prompt: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: FocallySpacing.extraSmall) {
            Text(title)
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)

            Group {
                if isSecure {
                    SecureField(prompt, text: text)
                } else {
                    TextField(prompt, text: text)
                        .textFieldStyle(.plain)
                }
            }
            .font(.focallyBody)
            .foregroundStyle(Color.focallyOnSurface)
            .padding(.horizontal, FocallySpacing.medium)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: FocallyRadius.small)
                    .fill(Color.focallySurfaceContainerLowest.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FocallyRadius.small)
                    .stroke(Color.focallyOutline.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.focallyButton)
                .foregroundStyle(Color.focallyOnPrimary)
                .padding(.horizontal, FocallySpacing.medium)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: FocallyRadius.small)
                        .fill(Color.focallyPrimary)
                )
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.focallyButton)
                .foregroundStyle(Color.focallyOnSurface)
                .padding(.horizontal, FocallySpacing.medium)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: FocallyRadius.small)
                        .fill(Color.focallySurfaceContainerHigh)
                )
        }
        .buttonStyle(.plain)
    }

    private var slackEnabledBinding: Binding<Bool> {
        Binding(get: { slackService.isEnabled }, set: { slackService.isEnabled = $0 })
    }

    private var calendarEnabledBinding: Binding<Bool> {
        Binding(get: { calendarService.isEnabled }, set: { calendarService.isEnabled = $0 })
    }

    private func loadCredentials() {
        slackToken = slackService.token ?? ""
        googleClientID = calendarService.clientID ?? ""
        googleClientSecret = calendarService.clientSecret ?? ""
    }

    private func saveSlackToken() {
        let trimmedToken = slackToken.trimmingCharacters(in: .whitespacesAndNewlines)
        slackService.token = trimmedToken.isEmpty ? nil : trimmedToken
        slackService.connectionError = nil
        // Auto-enable Slack when a token is saved
        if !trimmedToken.isEmpty && !slackService.isEnabled {
            slackService.isEnabled = true
        }
        slackService.isConnected = !trimmedToken.isEmpty && slackService.isEnabled
        // Refresh emoji catalog after saving token
        slackService.refreshEmojiCatalogIfPossible()
    }

    func testSlackConnection() {
        saveSlackToken()
        slackService.testConnection()
    }

    func testSlackFocusIntegration() {
        saveSlackToken()
        focusIntegrationService.runSlackTest { success, message in
            slackTestFeedback = message
            if success { slackService.connectionError = nil }
        }
    }

    private func saveGoogleCredentials() {
        calendarService.saveClientCredentials(clientID: googleClientID, clientSecret: googleClientSecret)
        calendarService.connectionError = nil
    }

    private func toggleGoogleConnection() {
        saveGoogleCredentials()
        if calendarService.isSignedIn {
            calendarService.signOut()
        } else {
            calendarService.signIn()
        }
    }
}
