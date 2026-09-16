import SwiftUI

struct TaskRowView: View {
    @Environment(TaskService.self) private var taskService
    @Environment(FocusMetricsService.self) private var metricsService
    @Environment(FocusTimerService.self) private var timerService

    let task: TaskItem
    let onStartPomodoro: () -> Void

    var body: some View {
        HStack(spacing: FocallySpacing.small) {
            Button(action: { taskService.toggleComplete(task.id) }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(task.isCompleted ? Color.focallyPrimary : Color.focallyOnSurfaceVariant)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("tasks_toggle_complete_accessibility")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.sanitizedTitle)
                    .font(.focallyBody)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? Color.focallyOnSurfaceVariant : Color.focallyOnSurface)

                HStack(spacing: FocallySpacing.small) {
                    let spent = taskService.timeSpent(on: task.id, records: metricsService.records)
                    if spent > 0 {
                        Label(DailyMetrics.formatDuration(spent), systemImage: "clock")
                    }

                    let pomodoros = taskService.completedPomodoros(on: task.id, records: metricsService.records)
                    if pomodoros > 0 {
                        Label("\(pomodoros)", systemImage: "timer")
                    }

                    if let due = task.dueDate, !task.isCompleted {
                        Text(due, style: .time)
                            .foregroundStyle(dueColor(due))
                    }
                }
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Spacer()

            if isActiveTask {
                Label {
                    LocalizedText("tasks_task_running")
                } icon: {
                    Image(systemName: "play.fill")
                        .foregroundStyle(Color.focallyPrimary)
                }
                .font(.focallyCaption)
            } else if !task.isCompleted {
                Button(action: onStartPomodoro) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.focallyPrimary)
                }
                .buttonStyle(.plain)
                .disabled(timerService.hasSession)
                .accessibilityLabel("tasks_start_pomodoro_accessibility")
            }
        }
        .padding(.vertical, FocallySpacing.small)
    }

    private var isActiveTask: Bool {
        guard timerService.hasSession else { return false }
        return task.id == timerService.activeTaskID
    }

    private func dueColor(_ due: Date) -> Color {
        let now = Date()
        if due < now { return .red }
        if due.timeIntervalSince(now) < 3600 { return .orange }
        return Color.focallyOnSurfaceVariant
    }
}
