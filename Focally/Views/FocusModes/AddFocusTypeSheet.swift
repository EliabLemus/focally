import AppKit
import SwiftUI

struct AddFocusTypeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var typesService = FocusTypesService.shared
    @State private var name: String
    @State private var emoji: String
    @State private var color: Color

    private let existingType: FocusType?

    init(type: FocusType? = nil) {
        existingType = type
        _name = State(initialValue: type?.name ?? "")
        _emoji = State(initialValue: type?.emoji ?? "")
        _color = State(initialValue: Color(hex: type?.color ?? "#3478F6"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.large) {
            LocalizedText(existingType == nil ? "focus_type_new_header" : "focus_type_edit_header")
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)

            VStack(alignment: .leading, spacing: FocallySpacing.medium) {
                TextField(AppLanguage.shared.localizedString("focus_type_name"), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(AppLanguage.shared.localizedString("focus_type_name"))

                TextField(AppLanguage.shared.localizedString("focus_type_emoji"), text: $emoji)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(AppLanguage.shared.localizedString("focus_type_emoji"))

                ColorPicker(
                    AppLanguage.shared.localizedString("focus_type_color"),
                    selection: $color,
                    supportsOpacity: false
                )
            }

            HStack {
                Spacer()
                Button("general_cancel") {
                    dismiss()
                }
                Button(existingType == nil ? "focus_type_create" : "general_save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(FocallySpacing.large)
        .frame(width: 380)
        .background(Color.focallyBackground)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = NSColor(color).hexRGB ?? "#3478F6"

        if let existingType {
            typesService.updateCustomType(
                FocusType(
                    id: existingType.id,
                    name: trimmedName,
                    emoji: trimmedEmoji,
                    color: hex
                )
            )
        } else {
            typesService.addCustomType(
                FocusType(name: trimmedName, emoji: trimmedEmoji, color: hex)
            )
        }
        dismiss()
    }
}

private extension NSColor {
    var hexRGB: String? {
        guard let rgb = usingColorSpace(.deviceRGB) else { return nil }
        return String(
            format: "#%02X%02X%02X",
            Int(round(rgb.redComponent * 255)),
            Int(round(rgb.greenComponent * 255)),
            Int(round(rgb.blueComponent * 255))
        )
    }
}
