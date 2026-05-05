import SwiftUI

struct IntegrationsSettingsView: View {
    @EnvironmentObject private var slackService: SlackService
    @EnvironmentObject private var calendarService: GoogleCalendarService

    @State private var slackToken = ""
    @State private var googleClientID = ""
    @State private var googleClientSecret = ""

    var body: some View {
        VStack(spacing: FocallySpacing.lg) {
            // Slack Card
            VStack(alignment: .leading, spacing: FocallySpacing.md) {
                HStack(spacing: FocallySpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: FocallyRadius.sm)
                            .fill(Color.focallyPrimary.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: "message.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.focallyPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Slack Integration")
                            .font(.focallyBodyBold)
                            .foregroundStyle(Color.focallyOnSurface)

                        Text("Post focus status updates to Slack channels.")
                            .font(.focallyBody)
                            .foregroundStyle(Color.focallyOutline)
                    }

                    Spacer()

                    // Connection status badge
                    connectionBadge(connected: slackService.isConnected)

                    FocallyToggleButton(isOn: slackEnabledBinding)
                }

                credentialField(
                    title: "User Token",
                    prompt: "xoxp-...",
                    text: $slackToken,
                    isSecure: true
                )

                HStack(spacing: FocallySpacing.sm) {
                    Button(action: saveSlackToken) {
                        Text("Save Token")
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

                    Button(action: testSlackConnection) {
                        Text("Test Connection")
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
                    .disabled(slackToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let slackError = slackService.connectionError, !slackError.isEmpty {
                    Text(slackError)
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyError)
                }
            }
            .padding(FocallySpacing.lg)
            .focallyCard()

            // Google Calendar Card
            VStack(alignment: .leading, spacing: FocallySpacing.md) {
                HStack(spacing: FocallySpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: FocallyRadius.sm)
                            .fill(Color.focallyTertiaryContainer.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: "calendar")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.focallyTertiary)
                    }

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

                credentialField(
                    title: "Client ID",
                    prompt: "Google OAuth client ID",
                    text: $googleClientID
                )

                credentialField(
                    title: "Client Secret",
                    prompt: "Google OAuth client secret",
                    text: $googleClientSecret,
                    isSecure: true
                )

                HStack(spacing: FocallySpacing.sm) {
                    Button(action: saveGoogleCredentials) {
                        Text("Save Credentials")
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

                    Button(action: toggleGoogleConnection) {
                        Text(calendarService.isSignedIn ? "Disconnect" : "Connect")
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

                if let calendarError = calendarService.connectionError, !calendarError.isEmpty {
                    Text(calendarError)
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyError)
                }
            }
            .padding(FocallySpacing.lg)
            .focallyCard()
        }
        .onAppear(perform: loadCredentials)
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

    private func credentialField(
        title: String,
        prompt: String,
        text: Binding<String>,
        isSecure: Bool = false
    ) -> some View {
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

    private var slackEnabledBinding: Binding<Bool> {
        Binding(
            get: { slackService.isEnabled },
            set: { slackService.isEnabled = $0 }
        )
    }

    private var calendarEnabledBinding: Binding<Bool> {
        Binding(
            get: { calendarService.isEnabled },
            set: { calendarService.isEnabled = $0 }
        )
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
        slackService.isConnected = !trimmedToken.isEmpty && slackService.isEnabled
    }

    private func testSlackConnection() {
        saveSlackToken()
        slackService.testConnection()
    }

    private func saveGoogleCredentials() {
        calendarService.saveClientCredentials(
            clientID: googleClientID,
            clientSecret: googleClientSecret
        )
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
