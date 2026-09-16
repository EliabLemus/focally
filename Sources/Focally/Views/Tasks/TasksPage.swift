import SwiftUI

struct TasksPage: View {
    @Environment(TaskService.self) private var taskService
    @Environment(FocusTimerService.self) private var timerService
    @State private var newTaskTitle = ""
    @State private var newTaskDueDate: Date?
    @State private var hasDueDate = false
    @State private var pomodoroTask: TaskItem?
    @State private var showCompleted = false

    var body: some View {
        ScrollView {
            VStack(spacing: FocallySpacing.medium) {
                addTaskCard

                if timerService.hasSession {
                    activeSessionCard
                }

                if taskService.overdueTasks.isEmpty {
                    EmptyView()
                } else {
                    overdueCard
                }

                openTasksCard

                if !taskService.completedTasks.isEmpty {
                    completedCard
                }
            }
            .padding(FocallySpacing.large)
        }
        .background(Color.focallyBackground)
        .sheet(item: $pomodoroTask) { task in
            StartPomodoroSheet(task: task)
        }
    }

    // MARK: - Add task

    private var addTaskCard: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.small) {
            HStack(spacing: FocallySpacing.small) {
                TextField(
                    "tasks_new_task_placeholder",
                    text: $newTaskTitle,
                    axis: .horizontal
                )
                .textFieldStyle(.plain)
                .padding(FocallySpacing.small)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.focallySurfaceContainer)
                )
                .onSubmit(addTask)

                Button(action: addTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.focallyPrimary)
                }
                .buttonStyle(.plain)
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("tasks_add_accessibility")
            }

            Toggle(isOn: $hasDueDate) {
                LocalizedText("tasks_has_due_date")
                    .font(.focallyCaption)
            }
            .toggleStyle(.checkbox)
            .font(.focallyCaption)

            if hasDueDate {
                DatePicker(
                    "tasks_due_date",
                    selection: Binding(
                        get: { newTaskDueDate ?? Date().addingTimeInterval(3600) },
                        set: { newTaskDueDate = $0 }
                    )
                )
                .labelsHidden()
                .font(.focallyCaption)
            }
        }
        .padding(FocallySpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.focallySurface)
        )
    }

    private func addTask() {
        let title = newTaskTitle
        let due = hasDueDate ? (newTaskDueDate ?? Date().addingTimeInterval(3600)) : nil
        taskService.addTask(title: title, dueDate: due)
        newTaskTitle = ""
        newTaskDueDate = nil
        hasDueDate = false
    }

    // MARK: - Active session

    private var activeSessionCard: some View {
        HStack(spacing: FocallySpacing.small) {
            Image(systemName: "timer")
                .foregroundStyle(Color.focallyPrimary)
            LocalizedText("tasks_session_in_progress")
                .font(.focallyBody)
            Spacer()
            Text(timerService.remainingTimeString)
                .font(.focallyBody.monospacedDigit())
        }
        .padding(FocallySpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.focallySurfaceContainer)
        )
    }

    // MARK: - Overdue

    private var overdueCard: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.small) {
            Label {
                LocalizedText("tasks_overdue_section")
            } icon: {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .font(.focallyBody)

            ForEach(taskService.overdueTasks) { task in
                TaskRowView(task: task) {
                    pomodoroTask = task
                }
            }
        }
        .padding(FocallySpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.focallySurface)
        )
    }

    // MARK: - Open tasks

    private var openTasksCard: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.small) {
            if taskService.openTasks.isEmpty {
                LocalizedText("tasks_empty_state")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, FocallySpacing.large)
            } else {
                ForEach(taskService.openTasks) { task in
                    TaskRowView(task: task) {
                        pomodoroTask = task
                    }
                }
            }
        }
        .padding(FocallySpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.focallySurface)
        )
    }

    // MARK: - Completed

    private var completedCard: some View {
        VStack(alignment: .leading, spacing: FocallySpacing.small) {
            Button(action: { showCompleted.toggle() }) {
                HStack(spacing: FocallySpacing.small) {
                    Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                    LocalizedText("tasks_completed_section")
                        .font(.focallyBody)
                    Spacer()
                    Text("\(taskService.completedTasks.count)")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                }
            }
            .buttonStyle(.plain)

            if showCompleted {
                ForEach(taskService.completedTasks) { task in
                    TaskRowView(task: task) {
                        pomodoroTask = task
                    }
                }
            }
        }
        .padding(FocallySpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.focallySurface)
        )
    }
}
