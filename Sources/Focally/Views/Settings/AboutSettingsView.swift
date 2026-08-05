import SwiftUI

struct AboutSettingsView: View {
    @Environment(UpdateCheckerService.self) private var updateChecker

    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

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

                        HStack(spacing: 8) {
                            Text(String(format: AppLanguage.shared.localizedString("about_version"), version))
                            Text(String(format: AppLanguage.shared.localizedString("about_build"), build))
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                        if updateChecker.isNewVersionAvailable, let newVersion = updateChecker.latestVersion {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundStyle(.secondary)
                                LocalizedText("about_update_available")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Text(String(format: AppLanguage.shared.localizedString("update_version"), newVersion))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Button(AppLanguage.shared.localizedString("about_get_update")) {
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
                    LocalizedText("about_tagline")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)

                    LocalizedText("about_description")
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
                                LocalizedText("about_github_link")
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
                    LocalizedText("about_copyright")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    LocalizedText("about_license")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(32)
        }
    }
}
