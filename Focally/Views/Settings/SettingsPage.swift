import SwiftUI

enum SettingsSubpage: String, CaseIterable, Identifiable {
    case general = "General"
    case automation = "Automation"
    case integrations = "Integrations"
    case appearance = "Appearance"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .automation: return "wand.and.stars"
        case .integrations: return "puzzlepiece.extension"
        case .appearance: return "paintbrush"
        case .about: return "info.circle"
        }
    }
}

struct SettingsPage: View {
    @EnvironmentObject var shortcutDropHandler: ShortcutDropHandler
    @EnvironmentObject var focusIntegrationService: FocusIntegrationService
    @State private var selectedSubpage: SettingsSubpage = .general

    var body: some View {
        HStack(spacing: 0) {
                // Sub-navigation sidebar
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(SettingsSubpage.allCases) { subpage in
                        Button(action: {
                            selectedSubpage = subpage
                        }) {
                            HStack(spacing: FocallySpacing.sm) {
                                Image(systemName: subpage.icon)
                                    .font(.system(size: 13))
                                    .frame(width: 18)

                                Text(subpage.rawValue)
                                    .font(selectedSubpage == subpage ? .focallyBodyBold : .focallyBody)
                            }
                            .foregroundStyle(selectedSubpage == subpage ? Color.focallyOnSurface : Color.focallyOutline)
                            .padding(.horizontal, FocallySpacing.sm)
                            .padding(.vertical, FocallySpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: FocallyRadius.sm)
                                    .fill(selectedSubpage == subpage ? Color.focallySurfaceContainerHigh : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(FocallySpacing.sm)
                .frame(width: 160)
                .background(Color.focallySurfaceContainerLow)

                // Content area
                VStack(spacing: 0) {
                    // Breadcrumb
                    HStack(spacing: 4) {
                        Text("Settings")
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyOutline)
                        Text("›")
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyOutline)
                        Text(selectedSubpage.rawValue)
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                    }
                    .padding(.horizontal, FocallySpacing.lg)
                    .padding(.top, FocallySpacing.md)
                    .padding(.bottom, FocallySpacing.sm)

                    // Content
                    ScrollView {
                        subpageContent
                            .padding(.horizontal, FocallySpacing.lg)
                            .padding(.bottom, FocallySpacing.lg)
                    }
                    .scrollContentBackground(.hidden)

                    // Footer
                    HStack {
                        Text("Changes are saved automatically.")
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyOutline)

                        Spacer()

                        Button(action: openShortcutSetup) {
                            Text("Manage Focus Integration")
                                .font(.focallyButton)
                                .foregroundStyle(Color.focallyOnPrimary)
                                .padding(.horizontal, FocallySpacing.md)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: FocallyRadius.sm)
                                        .fill(Color.focallyPrimary)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Manage Focus Integration")
                    }
                    .padding(.horizontal, FocallySpacing.lg)
                    .padding(.vertical, FocallySpacing.md)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundStyle(Color.focallyOutlineVariant)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.focallyBackground)
        }
    }

    @ViewBuilder
    private var subpageContent: some View {
        switch selectedSubpage {
        case .general:
            GeneralSettingsView()
        case .automation:
            AutomationSettingsView()
        case .integrations:
            IntegrationsSettingsView(shortcutDropHandler: shortcutDropHandler)
        case .appearance:
            AppearanceSettingsView()
        case .about:
            AboutSettingsView()
        }
    }

    private func openShortcutSetup() {
        selectedSubpage = .integrations
        NotificationCenter.default.post(name: .focusOpenShortcutOnboarding, object: nil)
    }
}
