import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(SoundPlayerService.self) private var soundPlayer

    @State private var launchAtLogin = false
    @State private var showInMenuBar = true

    var body: some View {
        VStack(spacing: FocallySpacing.large) {
            generalSettingsCard
        }
        .animation(.easeInOut(duration: 0.2), value: soundPlayer.isEnabled)
    }

    private var generalSettingsCard: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "arrow.right.circle", label: "Launch Focally at login", toggle: $launchAtLogin)

            Divider()
                .background(Color.focallyOutlineVariant)

            settingsRow(icon: "bell.fill", label: "Enable sound notifications", toggle: soundEnabledBinding)

            if soundPlayer.isEnabled {
                soundConfiguration
            }

            Divider()
                .background(Color.focallyOutlineVariant)

            settingsRow(icon: "menubar.rectangle", label: "Show timer in Menu Bar", toggle: $showInMenuBar)
        }
        .padding(.top, FocallySpacing.extraSmall)
        .padding(.bottom, FocallySpacing.extraSmall)
        .focallyGlassCard()
    }

    private var soundConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                pickerRow(title: "Work sound", selection: workSoundBinding)
                soundPreviewButton(for: soundPlayer.workSoundName)
            }
            HStack {
                pickerRow(title: "Break sound", selection: breakSoundBinding)
                soundPreviewButton(for: soundPlayer.breakSoundName)
            }
            HStack {
                pickerRow(title: "Completion sound", selection: completionSoundBinding)
                soundPreviewButton(for: soundPlayer.completionSoundName)
            }
        }
        .padding(.horizontal, FocallySpacing.large)
        .padding(.vertical, FocallySpacing.medium)
    }

    private var soundOptions: [String] {
        soundPlayer.sounds.filter { SoundPlayerService.CompletionSoundVariant(rawValue: $0) == nil }
    }

    private var completionOptions: [String] {
        SoundPlayerService.CompletionSoundVariant.allCases.map(\.rawValue)
    }

    private var soundEnabledBinding: Binding<Bool> {
        Binding(
            get: { soundPlayer.isEnabled },
            set: { newValue in
                soundPlayer.isEnabled = newValue
                settingsStore.soundEnabled = newValue
                soundPlayer.syncFromSettingsStore(settingsStore)
                settingsStore.saveSoundSettings()
            }
        )
    }

    private var workSoundBinding: Binding<String> {
        Binding(
            get: { soundPlayer.workSoundName },
            set: { newValue in
                settingsStore.workSoundName = newValue
                soundPlayer.syncFromSettingsStore(settingsStore)
                settingsStore.saveSoundSettings()
            }
        )
    }

    private var breakSoundBinding: Binding<String> {
        Binding(
            get: { soundPlayer.breakSoundName },
            set: { newValue in
                settingsStore.breakSoundName = newValue
                soundPlayer.syncFromSettingsStore(settingsStore)
                settingsStore.saveSoundSettings()
            }
        )
    }

    private var completionSoundBinding: Binding<String> {
        Binding(
            get: { soundPlayer.completionSoundName },
            set: { newValue in
                settingsStore.completionSoundName = newValue
                soundPlayer.syncFromSettingsStore(settingsStore)
                settingsStore.saveSoundSettings()
            }
        )
    }

    private func settingsRow(icon: String, label: String, toggle: Binding<Bool>) -> some View {
        HStack(spacing: FocallySpacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.focallyOnSurfaceVariant)
                .frame(width: 20)

            Text(label)
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurface)

            Spacer()

            FocallyToggleButton(isOn: toggle)
        }
        .padding(.horizontal, FocallySpacing.large)
        .padding(.vertical, FocallySpacing.medium)
    }

    private func actionRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: FocallySpacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .frame(width: 20)

                Text(label)
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, FocallySpacing.large)
            .padding(.vertical, FocallySpacing.medium)
        }
        .buttonStyle(.plain)
    }

    private func pickerRow(title: String, selection: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(.focallyBody)
                .foregroundStyle(Color.focallyOnSurface)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(title == "Completion sound" ? completionOptions : soundOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)
        }
    }

    private func soundPreviewButton(for soundName: String) -> some View {
        Button {
            soundPlayer.previewSound(named: soundName)
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.focallyPrimary)
                .padding(6)
                .background(Color.focallySurfaceContainerHighest)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Preview sound")
    }
}
