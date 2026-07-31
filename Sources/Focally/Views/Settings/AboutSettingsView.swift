import SwiftUI

struct AboutSettingsView: View {
    @Environment(\.locale) private var locale
    @Environment(UpdateCheckerService.self) private var updateChecker

    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // App Icon + Version
                VStack(spacing: 16) {
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    } else {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 8) {
                        Text("Focally")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("v\(version) · build \(build)")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)

                        if updateChecker.isNewVersionAvailable, let newVersion = updateChecker.latestVersion {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("⚠️ Update available: v\(newVersion)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.orange)
                                Button("Get it") {
                                    if let url = updateChecker.updateUrl {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .font(.system(size: 12))
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding(.top, 24)

                Divider()

                // Description
                VStack(spacing: 12) {
                    Text("Focus Timer & Slack Integration")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("A beautiful focus timer for macOS with Slack status integration, Do Not Disturb automation, and detailed productivity metrics.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 500)
                }

                // Links
                VStack(spacing: 8) {
                    if let url = URL(string: "https://github.com/EliabLemus/focally") {
                        Link(destination: url) {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                Text("GitHub Repository")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                // Footer
                VStack(spacing: 4) {
                    Text("© 2024 Eliab Lemus")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text("MIT License")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(32)
        }
    }
}