import SwiftUI

struct GeneralSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(FocusTimerService.self) private var timerService
    @Environment(SoundPlayerService.self) private var soundPlayer

    @State private var launchAtLogin: Bool = false
    @State private var showInMenuBar: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            settingsRow(
                icon: "arrow.right.circle",
                label: "Launch Focally at login",
                toggle: $launchAtLogin
            )

            Divider()
                .background(Color.focallyOutlineVariant)

            settingsRow(
                icon: "bell.fill",
                label: "Enable sound notifications",
                toggle: soundEnabledBinding
            )

            if soundPlayer.isEnabled {
                HStack(spacing: FocallySpacing.small) {
                    Spacer()
                    Menu {
                        ForEach(soundOptions, id: \.self) { sound in
                            Button(action: {
                                selectedSoundBinding.wrappedValue = sound
                            }) {
                                HStack {
                                    Text(sound)
                                    if selectedSoundBinding.wrappedValue == sound {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: FocallySpacing.extraSmall) {
                            Text(selectedSoundBinding.wrappedValue)
                                .font(.focallyCaption)
                                .foregroundStyle(Color.focallyOutline)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.focallyOutline)
                        }
                        .padding(.horizontal, FocallySpacing.small)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: FocallyRadius.small)
                                .fill(Color.focallySurfaceContainer)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.horizontal, FocallySpacing.large)
                .padding(.bottom, FocallySpacing.medium)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()
                .background(Color.focallyOutlineVariant)

            settingsRow(
                icon: "menubar.rectangle",
                label: "Show timer in Menu Bar",
                toggle: $showInMenuBar
            )
        }
        .padding(.top, FocallySpacing.extraSmall)
        .padding(.bottom, FocallySpacing.extraSmall)
        .animation(.easeInOut(duration: 0.2), value: soundPlayer.isEnabled)
    }

    private var soundOptions: [String] {
        soundPlayer.sounds.filter { soundName in
            SoundPlayerService.CompletionSoundVariant(rawValue: soundName) == nil
        }
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

    private var selectedSoundBinding: Binding<String> {
        Binding(
            get: { soundPlayer.workSoundName },
            set: { newValue in
                soundPlayer.workSoundName = newValue
                settingsStore.workSoundName = newValue
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
}
