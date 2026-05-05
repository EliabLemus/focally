import SwiftUI

struct TaskRowView: View {
    let task: PredefinedTask
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: task.iconBgColor))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: task.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: task.iconFgColor))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Text("\(task.durationMinutes)m • \(task.cycles) cycles")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: {}) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.focallyError)
                }
                .buttonStyle(.plain)
            }
            .opacity(isHovered ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .padding(FocallySpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.focallySurfaceContainerLowest.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.focallyOutline.opacity(0.1), lineWidth: 0.5)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
