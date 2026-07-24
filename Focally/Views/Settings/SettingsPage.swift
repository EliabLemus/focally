import SwiftUI

enum SettingsSubpage: CaseIterable, Identifiable {
    case general
    case integrations
    case appearance
    case language
    case about

    var id: String { localizationKey }

    var localizationKey: String {
        switch self {
        case .general: return "settings_general"
        case .integrations: return "settings_integrations"
        case .appearance: return "settings_appearance"
        case .language: return "settings_language"
        case .about: return "settings_about"
        }
    }

    var localizedLabel: String {
        String(localized: LocalizedStringResource(stringLiteral: localizationKey))
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .integrations: return "message.fill"
        case .appearance: return "paintbrush"
        case .language: return "globe"
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

                            Text(subpage.localizedLabel)
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
                    Text("settings_title")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOutline)
                    Text("›")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOutline)
                    Text(selectedSubpage.localizedLabel)
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
        case .language:
            LanguageSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}
