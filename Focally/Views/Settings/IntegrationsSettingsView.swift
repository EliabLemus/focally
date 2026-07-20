import SwiftUI

struct IntegrationsSettingsView: View {
    @Environment(SlackService.self) private var slackService
    @Environment(FocusIntegrationService.self) private var focusIntegrationService

    @State private var slackToken = ""
    @State private var slackTestFeedback: String?

    var body: some View {
        VStack(spacing: FocallySpacing.large) {
            slackCard
            automationCard
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

                    Text("Focally updates Slack status for all three modes and only enables Slack DND for modes that opt into DND.")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOutline)
                }

                Spacer()

                connectionBadge(connected: slackService.isConnected)
                FocallyToggleButton(isOn: slackEnabledBinding)
            }

            credentialField(title: "User Token", prompt: "xoxp-...", text: $slackToken, isSecure: true)

            Text("Token requires emoji:read scope for the emoji catalog.")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyTertiary)

            if !slackToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !slackToken.hasPrefix("xoxp-") && !slackToken.hasPrefix("xoxb-") {
                Text("Invalid format. Slack tokens should start with xoxp- or xoxb-.")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyError)
            }

            HStack(spacing: FocallySpacing.small) {
                primaryButton("Save Token", action: saveSlackToken)
                secondaryButton("Test Connection", action: testSlackConnection)
                    .disabled(slackToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                secondaryButton("Test Focus Status", action: testSlackFocusIntegration)
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

    private var automationCard: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.medium) {
            HStack(spacing: FocallySpacing.medium) {
                iconTile(systemImage: "moon.circle.fill", color: Color.focallySecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Do Not Disturb Automation")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)

                    Text("macOS DND and Slack DND are driven directly from each mode. Focus Time enables both by default.")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOutline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(focusIntegrationService.statusText)
                .font(.focallyCaption)
                .foregroundStyle(focusIntegrationService.lastError == nil ? Color.focallyOnSurfaceVariant : Color.focallyError)
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
        slackTestFeedback = slackService.isConnected ? "Connected ✓" : "Connection failed: \(slackService.connectionError ?? "Unknown error")"
    }

    private func testSlackFocusIntegration() {
        focusIntegrationService.runSlackTest { _, message in
            slackTestFeedback = message
        }
    }

    private func connectionBadge(connected: Bool) -> some View {
        Text(connected ? "Connected" : "Disconnected")
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
