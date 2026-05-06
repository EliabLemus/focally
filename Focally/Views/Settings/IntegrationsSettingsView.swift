import SwiftUI
import UniformTypeIdentifiers

struct IntegrationsSettingsView: View {
    @EnvironmentObject private var slackService: SlackService
    @EnvironmentObject private var calendarService: GoogleCalendarService
    @EnvironmentObject private var focusIntegrationService: FocusIntegrationService
    @ObservedObject var shortcutDropHandler: ShortcutDropHandler

    @State private var slackToken = ""
    @State private var googleClientID = ""
    @State private var googleClientSecret = ""
    @State private var isTargetingDropZone = false

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

            // Focus Integration Card
        VStack(alignment: .leading, spacing: FocallySpacing.md) {
            HStack(spacing: FocallySpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: FocallyRadius.sm)
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "moon.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Focus Integration")
                            .font(.focallyBodyBold)
                            .foregroundStyle(Color.focallyOnSurface)
                        if focusIntegrationService.isEnabled {
                            Text("Recommended")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.purple))
                        }
                    }
                    Text("Activate a real macOS Focus mode when your timer starts.")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOutline)
                }

                Spacer()

                FocallyToggleButton(isOn: $focusIntegrationService.isEnabled)
            }

            if focusIntegrationService.isEnabled {
                VStack(alignment: .leading, spacing: FocallySpacing.md) {
                    // Mode picker
                    VStack(alignment: .leading, spacing: FocallySpacing.xs) {
                        Text("Mode")
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyOnSurfaceVariant)

                        Picker("Integration Mode", selection: $focusIntegrationService.mode) {
                            ForEach(FocusIntegrationMode.allCases) { mode in
                                HStack {
                                    Text(mode.displayName)
                                    if mode.isRecommended {
                                        Text("(Recommended)")
                                            .foregroundStyle(Color.purple)
                                    }
                                }
                                .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Shortcuts config (only in shortcuts mode)
                    if focusIntegrationService.mode == .shortcuts {
                        VStack(alignment: .leading, spacing: FocallySpacing.md) {
                            credentialField(
                                title: "Start Shortcut",
                                prompt: "e.g. Focally Start Focus",
                                text: $focusIntegrationService.startShortcutName
                            )

                            credentialField(
                                title: "End Shortcut",
                                prompt: "e.g. Focally End Focus",
                                text: $focusIntegrationService.endShortcutName
                            )

                            // Helper text
                            VStack(alignment: .leading, spacing: 4) {
                                Label {
                                    Text("Create these shortcuts in the Shortcuts app to set/unset a Focus mode.")
                                        .font(.focallyCaption)
                                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                                } icon: {
                                    Image(systemName: "lightbulb")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.focallyPrimary)
                                }

                                Label {
                                    Text("For global visual confirmation, pin the Focus icon to your menu bar in System Settings.")
                                        .font(.focallyCaption)
                                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                                } icon: {
                                    Image(systemName: "menubar.rectangle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.focallyPrimary)
                                }
                            }
                            .padding(.horizontal, FocallySpacing.sm)

                            // Test buttons
                            HStack(spacing: FocallySpacing.sm) {
                                Button(action: { focusIntegrationService.testActivation() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 10))
                                        Text("Test Activate")
                                            .font(.focallyButton)
                                    }
                                    .foregroundStyle(Color.focallyOnPrimary)
                                    .padding(.horizontal, FocallySpacing.md)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: FocallyRadius.sm)
                                            .fill(Color.purple)
                                    )
                                }
                                .buttonStyle(.plain)

                                Button(action: { focusIntegrationService.testDeactivation() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 10))
                                        Text("Test Deactivate")
                                            .font(.focallyButton)
                                    }
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

                            // Status / Error
                            if let error = focusIntegrationService.lastError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.focallyError)
                                    Text(error.localizedDescription)
                                        .font(.focallyCaption)
                                        .foregroundStyle(Color.focallyError)
                                }
                                .padding(.horizontal, FocallySpacing.sm)
                            }
                        }
                    }

                    // Legacy DND info
                    if focusIntegrationService.mode == .legacyDND {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.focallyOnSurfaceVariant)
                            Text("Uses the built-in DND mechanism. For better visual feedback, switch to Shortcuts mode.")
                                .font(.focallyCaption)
                                .foregroundStyle(Color.focallyOnSurfaceVariant)
                        }
                        .padding(.horizontal, FocallySpacing.sm)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(FocallySpacing.lg)
        .focallyCard()

        // Shortcut Drop Zone Card
        ShortcutDropZone(
            isTargeted: $isTargetingDropZone,
            isProcessing: shortcutDropHandler.isProcessing,
            message: shortcutDropHandler.lastMessage,
            error: shortcutDropHandler.lastError
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargetingDropZone) { providers in
            handleShortcutDrop(providers: providers)
        }
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

    // MARK: - Shortcut Drop Handling

    private func handleShortcutDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  self.shortcutDropHandler.isValidShortcutFile(url) else {
                return
            }

            DispatchQueue.main.async {
                self.shortcutDropHandler.importShortcut(from: url)
            }
        }

        return true
    }
}

// MARK: - Shortcut Drop Zone

struct ShortcutDropZone: View {
    @Binding var isTargeted: Bool
    let isProcessing: Bool
    let message: String
    let error: String?

    var body: some View {
        VStack(spacing: FocallySpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FocallyRadius.md)
                    .fill(
                        isTargeted
                            ? Color.focallyPrimary.opacity(0.1)
                            : Color.focallySurfaceContainerLowest
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: FocallyRadius.md)
                            .stroke(
                                isTargeted
                                    ? Color.focallyPrimary
                                    : Color.focallyOutline.opacity(0.3),
                                lineWidth: isTargeted ? 2 : 1
                            )
                    )

                VStack(spacing: FocallySpacing.sm) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if error != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.focallyError)
                    } else if !message.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.focallyPrimary)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 32))
                            .foregroundStyle(isTargeted ? Color.focallyPrimary : Color.focallyOutline)
                    }

                    Text(isTargeted ? "Drop shortcut here" : "Drag & Drop .shortcut file")
                        .font(.focallyBody)
                        .foregroundStyle(isTargeted ? Color.focallyPrimary : Color.focallyOnSurfaceVariant)

                    if let errorMessage = error {
                        Text(errorMessage)
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyError)
                            .multilineTextAlignment(.center)
                    } else if !message.isEmpty {
                        Text(message)
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyPrimary)
                    }
                }
                .padding(FocallySpacing.xl)
            }
            .frame(height: 140)
            .animation(.easeInOut(duration: 0.2), value: isTargeted)

            // Helper text
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("Drop shortcuts here to install them in the Shortcuts app.")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                } icon: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.focallyPrimary)
                }
            }
            .padding(.horizontal, FocallySpacing.md)
        }
        .padding(FocallySpacing.lg)
        .focallyCard()
    }
}
