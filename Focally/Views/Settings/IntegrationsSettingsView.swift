import SwiftUI
import UniformTypeIdentifiers

struct IntegrationsSettingsView: View {
    @EnvironmentObject private var slackService: SlackService
    @EnvironmentObject private var calendarService: GoogleCalendarService
    @EnvironmentObject private var focusIntegrationService: FocusIntegrationService
    @EnvironmentObject private var managedShortcutsService: ManagedFocusShortcutsService
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
                        if focusIntegrationService.mode.isRecommended {
                            Text("Recommended")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.purple))
                        }
                    }
                    Text("Turn on system Do Not Disturb directly when your timer starts. Managed Shortcuts stay available as an optional Apple-visible Add/import extra with Focally's bundled signed files.")
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

                    if focusIntegrationService.mode == .directDND {
                        VStack(alignment: .leading, spacing: FocallySpacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Recommended default")
                                    .font(.focallyCaption)
                                    .foregroundStyle(Color.focallyOnSurfaceVariant)

                                VStack(alignment: .leading, spacing: 8) {
                                    shortcutActionRow(title: "System DND turns on automatically", subtitle: "Focally writes the Notification Center preference directly when your timer starts")
                                    shortcutActionRow(title: "No extra setup required", subtitle: "No .shortcut imports or Shortcuts automation needed for the main flow")
                                }
                                .padding(FocallySpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: FocallyRadius.md)
                                        .fill(Color.focallySurfaceContainerLow)
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Label {
                                    Text("This is the install-and-it-just-works path: enable Focus Integration and start a session.")
                                        .font(.focallyCaption)
                                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                                } icon: {
                                    Image(systemName: "checkmark.seal")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.focallyPrimary)
                                }

                                Label {
                                    Text("If you want visual confirmation from macOS, pin the Focus icon in your menu bar from System Settings.")
                                        .font(.focallyCaption)
                                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                                } icon: {
                                    Image(systemName: "menubar.rectangle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.focallyPrimary)
                                }
                            }
                            .padding(.horizontal, FocallySpacing.sm)

                            HStack(spacing: FocallySpacing.sm) {
                                Button(action: { focusIntegrationService.runNativeShortcutTest(.start) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 10))
                                        Text("Test Turn On DND")
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

                                Button(action: { focusIntegrationService.runNativeShortcutTest(.end) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 10))
                                        Text("Test Turn Off DND")
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

                            Text(focusIntegrationService.statusText)
                                .font(.focallyCaption)
                                .foregroundStyle(focusIntegrationService.lastError == nil ? Color.focallyOnSurfaceVariant : Color.focallyError)
                                .padding(.horizontal, FocallySpacing.sm)
                        }
                    }

                    if focusIntegrationService.mode == .appShortcuts {
                        VStack(alignment: .leading, spacing: FocallySpacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Managed Apple shortcuts")
                                    .font(.focallyCaption)
                                    .foregroundStyle(Color.focallyOnSurfaceVariant)

                                VStack(alignment: .leading, spacing: 8) {
                                    shortcutActionRow(title: "Stage bundled signed files", subtitle: "Focally ships the Focus On/Off .shortcut files already signed and copies them to an easy-to-open folder")
                                    shortcutActionRow(title: "Open Apple Add screens once", subtitle: "Each bundled signed file opens in Shortcuts so the user can press Add")
                                    shortcutActionRow(title: "Run automatically after import", subtitle: "After you press Add once per shortcut, Focally uses shortcuts run on the installed signed names instead of direct DND in this mode")
                                }
                                .padding(FocallySpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: FocallyRadius.md)
                                        .fill(Color.focallySurfaceContainerLow)
                                )
                            }

                            VStack(alignment: .leading, spacing: FocallySpacing.sm) {
                                managedShortcutStatusRow(
                                    title: "Signed files ready",
                                    subtitle: managedShortcutsService.allSignedShortcutsExist ? "Copied from the app bundle to Application Support/Focally/ManagedShortcuts/BundledSigned" : "Stage the bundled signed files first",
                                    isComplete: managedShortcutsService.allSignedShortcutsExist
                                )
                                managedShortcutStatusRow(
                                    title: "Imported in Shortcuts",
                                    subtitle: managedShortcutsService.allManagedShortcutsInstalled ? "Both bundled shortcut names were detected by shortcuts list" : "Open both bundled signed files and press Add in Shortcuts",
                                    isComplete: managedShortcutsService.allManagedShortcutsInstalled
                                )
                            }
                            .padding(FocallySpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: FocallyRadius.md)
                                    .fill(Color.focallySurfaceContainerLowest.opacity(0.6))
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Label {
                                    Text("Direct System DND is still the recommended default. Choose Managed Shortcuts only if you specifically want Apple's visible Add/import flow after Focally stages the bundled signed files for you.")
                                        .font(.focallyCaption)
                                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                                } icon: {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.focallyPrimary)
                                }

                                Label {
                                    Text("If the bundled signed files are missing, not imported, or shortcuts run fails, Focally will show that clearly instead of pretending this path is ready or silently imported.")
                                        .font(.focallyCaption)
                                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                                } icon: {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.focallyPrimary)
                                }
                            }
                            .padding(.horizontal, FocallySpacing.sm)

                            HStack(spacing: FocallySpacing.sm) {
                                Button(action: { managedShortcutsService.prepareSignedShortcuts() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "wand.and.stars")
                                            .font(.system(size: 10))
                                        Text("Stage Bundled Files")
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

                                Button(action: { managedShortcutsService.prepareAndOpenForImport() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 10))
                                        Text("Stage + Open")
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

                            HStack(spacing: FocallySpacing.sm) {
                                Button(action: { managedShortcutsService.openSignedShortcutsForImport() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 10))
                                        Text("Open Bundled Files")
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
                                .disabled(!managedShortcutsService.allSignedShortcutsExist)

                                Button(action: { managedShortcutsService.refreshInstallationState() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.magnifyingglass")
                                            .font(.system(size: 10))
                                        Text("Verify Install")
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

                                Button(action: { managedShortcutsService.revealSignedShortcutsInFinder() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder")
                                            .font(.system(size: 10))
                                        Text("Reveal")
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
                                .disabled(!managedShortcutsService.allSignedShortcutsExist)
                            }

                            HStack(spacing: FocallySpacing.sm) {
                                Button(action: { focusIntegrationService.runNativeShortcutTest(.start) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 10))
                                        Text("Run Focus On")
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
                                .disabled(!managedShortcutsService.allManagedShortcutsInstalled)

                                Button(action: { focusIntegrationService.runNativeShortcutTest(.end) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 10))
                                        Text("Run Focus Off")
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
                                .disabled(!managedShortcutsService.allManagedShortcutsInstalled)
                            }

                            if let warning = managedShortcutsService.lastWarning, !warning.isEmpty {
                                Text(warning)
                                    .font(.focallyCaption)
                                    .foregroundStyle(Color.focallyPrimary)
                                    .padding(.horizontal, FocallySpacing.sm)
                            }

                            Text(focusIntegrationService.statusText)
                                .font(.focallyCaption)
                                .foregroundStyle(focusIntegrationService.lastError == nil ? Color.focallyOnSurfaceVariant : Color.focallyError)
                                .padding(.horizontal, FocallySpacing.sm)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(FocallySpacing.lg)
        .focallyCard()

        // Legacy shortcut import card
        ShortcutDropZone(
            isTargeted: $isTargetingDropZone,
            isProcessing: shortcutDropHandler.isProcessing,
            message: shortcutDropHandler.lastMessage,
            error: shortcutDropHandler.lastError
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargetingDropZone) { providers in
            handleShortcutDrop(providers: providers)
        }

        // Reset Onboarding Card
        VStack(alignment: .leading, spacing: FocallySpacing.md) {
            HStack(spacing: FocallySpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: FocallyRadius.sm)
                        .fill(Color.focallyErrorContainer.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.focallyError)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reset Focus Integration Onboarding")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)

                    Text("Show the onboarding wizard again to review the direct DND setup and optional Managed Shortcuts Add flow.")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOutline)
                }

                Spacer()

                Button(action: resetOnboarding) {
                    Text("Reset")
                        .font(.focallyButton)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, FocallySpacing.md)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: FocallyRadius.sm)
                                .fill(Color.focallyError)
                        )
                }
                .buttonStyle(.plain)
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

    private func shortcutActionRow(title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: FocallySpacing.sm) {
            Image(systemName: "bolt.circle.fill")
                .foregroundStyle(Color.focallyPrimary)

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

    private func managedShortcutStatusRow(title: String, subtitle: String, isComplete: Bool) -> some View {
        HStack(alignment: .top, spacing: FocallySpacing.sm) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? Color.focallyPrimary : Color.focallyOutline)

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

    // MARK: - Reset Onboarding

    private func resetOnboarding() {
        ShortcutOnboardingViewModel.resetOnboarding()
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

                    Text(isTargeted ? "Drop legacy shortcut here" : "Legacy manual import (advanced fallback only)")
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
                    Text("Legacy-only fallback: use this only for older manual workflows. The supported managed flow lives above and stages Focally's bundled signed files for you.")
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
