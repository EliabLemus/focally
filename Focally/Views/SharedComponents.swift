import SwiftUI

// MARK: - Focally Toggle Button

struct FocallyToggleButton: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(.switch)
            .tint(Color.focallyPrimary)
            .labelsHidden()
    }
}

// MARK: - Focally Segmented Control

struct FocallySegmentedControl: View {
    @Binding var selection: Int
    let options: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<options.count, id: \.self) { index in
                Button(action: {
                    selection = index
                }) {
                    Text(options[index])
                        .font(.focallyCaption)
                        .foregroundStyle(selection == index ? Color.focallyOnSurface : Color.focallyOutline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selection == index ? Color.focallySurfaceContainerHigh : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.focallySurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Focally Pill Button

struct FocallyPillButton: View {
    let title: String
    let icon: String?
    let isPrimary: Bool
    let action: () -> Void

    init(title: String, icon: String? = nil, isPrimary: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isPrimary = isPrimary
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.focallyButton)
            }
            .foregroundStyle(isPrimary ? Color.focallyOnPrimary : Color.focallyOnSurfaceVariant)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPrimary ? Color.focallyPrimary : Color.focallySurfaceContainerHigh)
            )
        }
        .buttonStyle(.plain)
    }
}
