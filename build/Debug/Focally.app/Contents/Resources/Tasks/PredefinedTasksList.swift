import SwiftUI

struct PredefinedTasksList: View {
    @State private var tasks: [PredefinedTask] = [
        PredefinedTask(name: "Deep Coding", emoji: "💻", icon: "chevron.left.forwardslash.chevron.right", iconBgColor: "DBEAFE", iconFgColor: "2563EB", durationMinutes: 25, cycles: 4),
        PredefinedTask(name: "Technical Documentation", emoji: "📚", icon: "doc.text", iconBgColor: "FFEDD5", iconFgColor: "EA580C", durationMinutes: 50, cycles: 2),
        PredefinedTask(name: "Inbox Clearing", emoji: "📧", icon: "envelope", iconBgColor: "F3E8FF", iconFgColor: "9333EA", durationMinutes: 15, cycles: 1),
        PredefinedTask(name: "Quick Workout", emoji: "💪", icon: "dumbbell", iconBgColor: "DCFCE7", iconFgColor: "16A34A", durationMinutes: 10, cycles: 1)
    ]

    @State private var showingAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.md) {
            HStack {
                Image(systemName: "checklist")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.focallyPrimary)
                Text("Predefined Tasks")
                    .font(.focallyH2)
                    .foregroundStyle(Color.focallyOnSurface)

                Spacer()

                Button(action: {
                    showingAddSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add New")
                            .font(.focallyCaption)
                    }
                    .padding(.horizontal, FocallySpacing.md)
                    .padding(.vertical, FocallySpacing.sm)
                    .background(Color.focallyPrimary)
                    .foregroundStyle(Color.focallyOnPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: FocallyRadius.sm))
                }
                .buttonStyle(.plain)
            }

            ForEach(tasks, id: \.id) { task in
                TaskRowView(task: task)
                    .transition(.opacity)
            }
        }
        .padding(FocallySpacing.lg)
        .focallyCard()
    }
}
