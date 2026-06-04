import SwiftUI

struct TaskRowView: View {
    let task: PredefinedTask
    let onStart: (Int) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var selectedDuration: Int

    init(task: PredefinedTask,
         onStart: @escaping (Int) -> Void,
         onEdit: @escaping () -> Void,
         onDelete: @escaping () -> Void) {
        self.task = task
        self.onStart = onStart
        self.onEdit = onEdit
        self.onDelete = onDelete
        _selectedDuration = State(initialValue: task.durationMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.medium) {
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

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: FocallySpacing.small) {
                        Text(task.name)
                            .font(.focallyBodyBold)
                            .foregroundStyle(Color.focallyOnSurface)

                        Text(task.taskType.displayName.uppercased())
                            .font(.focallyCaption)
                            .foregroundStyle(Color.focallyOnSurfaceVariant)
                            .padding(.horizontal, FocallySpacing.small)
                            .padding(.vertical, FocallySpacing.extraSmall)
                            .background(Color.focallySurfaceContainerHigh)
                            .clipShape(RoundedRectangle(cornerRadius: FocallyRadius.small))
                    }

                    Text(metadataText)
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }

                Spacer()

                Button(action: { onStart(selectedDuration) }) {
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

            if task.taskType == .meeting {
                MeetingDurationPicker(
                    selectedDuration: $selectedDuration,
                    availableDurations: task.availableDurations
                ) { duration in
                    selectedDuration = duration
                }
            }
        }
        .padding(FocallySpacing.medium)
        .background(Color.focallySurface)
        .clipShape(RoundedRectangle(cornerRadius: FocallyRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: FocallyRadius.medium)
                .stroke(Color.focallyOutline.opacity(0.1), lineWidth: 0.5)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var metadataText: String {
        if task.taskType == .meeting {
            return "\(selectedDuration)m • blocks all notifications"
        }
        return "\(task.durationMinutes)m • \(task.cycles) cycle\(task.cycles == 1 ? "" : "s")"
    }
}
