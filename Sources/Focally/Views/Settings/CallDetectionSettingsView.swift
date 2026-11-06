import SwiftUI

/// "Calls" settings section (TASK-057). All four controls persist via
/// `CallDetectionSettingsStore` and take effect on the NEXT call — no restart.
struct CallDetectionSettingsView: View {
    @Environment(AppLanguage.self) private var appLanguage
    @State private var store = CallDetectionSettingsStore()

    @State private var callStatusEnabled = true
    @State private var callStatusMessage = CallDetectionSettings.defaultStatusMessage
    @State private var enableDNDDuringCalls = true
    @State private var pauseFocusDuringCalls = true

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

    private func load() {
        let settings = store.currentSettings()
        callStatusEnabled = settings.callStatusEnabled
        enableDNDDuringCalls = settings.enableDNDDuringCalls
        pauseFocusDuringCalls = settings.pauseFocusDuringCalls
        // Surface the stored (sanitized) message so empty shows the default.
        callStatusMessage = store.currentSettings().callStatusMessage
    }
}
