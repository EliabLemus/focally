import SwiftUI

struct GeneralSettingsView: View {
    @State private var launchAtLogin: Bool = false
    @State private var soundEnabled: Bool = true
    @State private var selectedSound: String = "Crystal"
    @State private var showInMenuBar: Bool = true

    private let soundOptions = ["Crystal", "Breeze", "Minimal"]

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
                toggle: $soundEnabled
            )

            if soundEnabled {
                HStack(spacing: FocallySpacing.sm) {
                    Spacer()
                    Menu {
                        ForEach(soundOptions, id: \.self) { sound in
                            Button(action: {
                                selectedSound = sound
                            }) {
                                HStack {
                                    Text(sound)
                                    if selectedSound == sound {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: FocallySpacing.xs) {
                            Text(selectedSound)
                                .font(.focallyCaption)
                                .foregroundStyle(Color.focallyOutline)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.focallyOutline)
                        }
                        .padding(.horizontal, FocallySpacing.sm)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: FocallyRadius.sm)
                                .fill(Color.focallySurfaceContainer)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.horizontal, FocallySpacing.lg)
                .padding(.bottom, FocallySpacing.md)
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
        .padding(.top, FocallySpacing.xs)
        .padding(.bottom, FocallySpacing.xs)
        .animation(.easeInOut(duration: 0.2), value: soundEnabled)
    }

    private func settingsRow(icon: String, label: String, toggle: Binding<Bool>) -> some View {
        HStack(spacing: FocallySpacing.md) {
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
        .padding(.horizontal, FocallySpacing.lg)
        .padding(.vertical, FocallySpacing.md)
    }
}
