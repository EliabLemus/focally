import SwiftUI

struct SidebarItemView: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 20)
                    .foregroundStyle(isActive ? Color.focallyPrimary : Color.focallyOnSurfaceVariant)

                Text(label)
                    .font(.focallyButton)
                    .foregroundStyle(isActive ? Color.focallyOnSurface : Color.focallyOnSurfaceVariant)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: FocallyRadius.sm)
                    .fill(isActive ? Color.focallySurfaceContainerHigh : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering && !isActive {
                // hover highlight — SwiftUI handles this via button style
            }
        }
    }
}
