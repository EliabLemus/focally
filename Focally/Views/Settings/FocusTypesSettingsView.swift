import SwiftUI

struct FocusTypesSettingsView: View {
    @State private var typesService = FocusTypesService.shared
    @State private var showAddSheet = false
    @State private var editingType: FocusType?

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.large) {
            settingsSection(
                title: AppLanguage.shared.localizedString("focus_types_built_in_header")
            ) {
                ForEach(FocusModeType.allCases.filter { $0 != .userCustom }, id: \.self) { type in
                    HStack {
                        Text(AppLanguage.shared.localizedString(type.localizedLabel))
                            .font(.focallyBody)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyOutline)
                            .accessibilityLabel(
                                AppLanguage.shared.localizedString("focus_type_read_only")
                            )
                    }
                }
            }

            settingsSection(
                title: AppLanguage.shared.localizedString("focus_types_my_types_header")
            ) {
                if typesService.customTypes.isEmpty {
                    LocalizedText("focus_types_empty")
                        .font(.focallyBody)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }

                ForEach(typesService.customTypes) { type in
                    HStack(spacing: FocallySpacing.small) {
                        Circle()
                            .fill(Color(hex: type.color))
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                        Text(type.emoji)
                        Text(type.name)
                            .font(.focallyBody)
                        Spacer()
                        Button {
                            editingType = type
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            String(
                                format: AppLanguage.shared.localizedString("focus_type_edit_accessibility"),
                                type.name
                            )
                        )

                        Button(role: .destructive) {
                            typesService.deleteCustomType(id: type.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.focallyError)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            String(
                                format: AppLanguage.shared.localizedString("focus_type_delete_accessibility"),
                                type.name
                            )
                        )
                    }
                }
            }

            Button {
                showAddSheet = true
            } label: {
                Label("focus_types_add_new", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(AppLanguage.shared.localizedString("focus_types_add_new"))
        }
        .sheet(isPresented: $showAddSheet) {
            AddFocusTypeSheet()
        }
        .sheet(item: $editingType) { type in
            AddFocusTypeSheet(type: type)
        }
    }

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FocallySpacing.medium) {
            Text(title)
                .font(.focallyBodyBold)
                .foregroundStyle(Color.focallyOnSurface)
            content()
        }
        .padding(FocallySpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .focallyGlassCard()
    }
}
