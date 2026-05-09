import SwiftUI

struct IntegrationsSettingsView: View {
    @EnvironmentObject private var slackService: SlackService
    @EnvironmentObject private var calendarService: GoogleCalendarService
    @EnvironmentObject private var focusIntegrationService: FocusIntegrationService
    @EnvironmentObject private var managedShortcutsService: ManagedFocusShortcutsService
    @ObservedObject var shortcutDropHandler: ShortcutDropHandler

    @State private var slackToken = ""
    @State private var googleClientID = ""
    @State private var googleClientSecret = ""
    @State private var slackTestFeedback: String?

    var body: some View {
        VStack(spacing: FocallySpacing.lg) {
            slackCard
            calendarCard
            focusIntegrationCard
        }
        .onAppear(perform: loadCredentials)
    }

    private var slackCard: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.md) {
            HStack(spacing: FocallySpacing.md) {
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

            HStack(spacing: FocallySpacing.sm) {
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
                    HStack(spacing: FocallySpacing.xs) {
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
        .padding(FocallySpacing.lg)
        .focallyCard()
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.md) {
            HStack(spacing: FocallySpacing.md) {
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

            HStack(spacing: FocallySpacing.sm) {
                primaryButton("Save Credentials", action: saveGoogleCredentials)
                secondaryButton(calendarService.isSignedIn ? "Disconnect" : "Connect", action: toggleGoogleConnection)
            }

            if let calendarError = calendarService.connectionError, !calendarError.isEmpty {
                Text(calendarError)
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyError)
            }
        }
        .padding(FocallySpacing.lg)
        .focallyCard()
    }

    private var focusIntegrationCard: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.md) {
            HStack(spacing: FocallySpacing.md) {
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

                HStack(spacing: FocallySpacing.sm) {
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
            .padding(FocallySpacing.md)
            .background(
                RoundedRectangle(cornerRadius: FocallyRadius.md)
                    .fill(Color.focallySurfaceContainerLow)
            )
        }
        .padding(FocallySpacing.lg)
        .focallyCard()
    }

    private func iconTile(systemImage: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: FocallyRadius.sm)
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

        return VStack(alignment: .leading, spacing: FocallySpacing.sm) {
            Text("Completion Sound Preview")
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)

            Text("Choose a completion sound and preview it instantly.")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)

            HStack(spacing: FocallySpacing.sm) {
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
        .padding(FocallySpacing.md)
        .background(
            RoundedRectangle(cornerRadius: FocallyRadius.md)
                .fill(Color.focallySurfaceContainerLow)
        )
    }

    private func completionSoundBinding(for soundPlayer: SoundPlayerService) -> Binding<String> {
        Binding(
            get: { soundPlayer.completionSoundName },
            set: { newValue in
                soundPlayer.completionSoundName = newValue
                soundPlayer.saveSettings()
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
        .padding(.horizontal, FocallySpacing.sm)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: FocallyRadius.xs)
                .fill(connected ? Color.focallyPrimary.opacity(0.1) : Color.focallySurfaceContainer)
        )
    }

    private func credentialField(title: String, prompt: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: FocallySpacing.xs) {
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
            .padding(.horizontal, FocallySpacing.md)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: FocallyRadius.sm)
                    .fill(Color.focallySurfaceContainerLowest.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FocallyRadius.sm)
                    .stroke(Color.focallyOutline.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.focallyButton)
                .foregroundStyle(Color.focallyOnPrimary)
                .padding(.horizontal, FocallySpacing.md)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: FocallyRadius.sm)
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
                .padding(.horizontal, FocallySpacing.md)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: FocallyRadius.sm)
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

    private func testSlackConnection() {
        saveSlackToken()
        slackService.testConnection()
    }

    private func testSlackFocusIntegration() {
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
