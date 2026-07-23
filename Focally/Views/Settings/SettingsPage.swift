import SwiftUI

enum SettingsSubpage: String, CaseIterable, Identifiable {
    case general = "General"
    case integrations = "Integrations"
    case appearance = "Appearance"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .integrations: return "message.fill"
        case .appearance: return "paintbrush"
        case .about: return "info.circle"
        }
    }
}

struct SettingsPage: View {
    @State private var selectedSubpage: SettingsSubpage = .general

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsSubpage.allCases) { subpage in
                    Button(action: {
                        selectedSubpage = subpage
                    }) {
                        HStack(spacing: FocallySpacing.small) {
                            Image(systemName: subpage.icon)
                                .font(.system(size: 13))
                                .frame(width: 18)

                            Text(subpage.rawValue)
                                .font(selectedSubpage == subpage ? .focallyBodyBold : .focallyBody)
                        }
                        .foregroundStyle(selectedSubpage == subpage ? Color.focallyOnSurface : Color.focallyOutline)
                        .padding(.horizontal, FocallySpacing.small)
                        .padding(.vertical, FocallySpacing.small)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: FocallyRadius.small)
                                .fill(selectedSubpage == subpage ? Color.focallySurfaceContainerHigh : Color.clear)
                        )
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(FocallySpacing.small)
            .frame(width: 160)
            .background(Color.focallySurfaceContainerLow)

            VStack(spacing: 0) {
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
                .padding(.horizontal, FocallySpacing.large)
                .padding(.top, FocallySpacing.medium)
                .padding(.bottom, FocallySpacing.small)

                ScrollView {
                    subpageContent
                        .padding(.horizontal, FocallySpacing.large)
                        .padding(.bottom, FocallySpacing.large)
                }
                .scrollContentBackground(.hidden)
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
        case .integrations:
            IntegrationsSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}
