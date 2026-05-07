import SwiftUI

struct TaskRowView: View {
    let task: PredefinedTask
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Text(task.emoji)
                .font(.system(size: 18))
                .frame(width: 40, height: 40)
                .background(Color(hex: task.iconBgColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: task.iconFgColor).opacity(0.24), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)

                Text("\(task.durationMinutes)m • \(task.cycles) cycle\(task.cycles == 1 ? "" : "s")")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Spacer()

            Button(action: onStart) {
                Text("Start")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.focallyPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
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
