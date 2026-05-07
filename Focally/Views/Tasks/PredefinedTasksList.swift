import SwiftUI

struct PredefinedTasksList: View {
    @EnvironmentObject private var predefinedTaskStore: PredefinedTaskStore
    @EnvironmentObject private var timerService: FocusTimerService

    @State private var showingEditor = false
    @State private var editingTask: PredefinedTask?

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

                Button(action: addTask) {
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

            Text("These presets are saved and can also be launched from the menu bar.")
                .font(.focallyCaption)
                .foregroundStyle(Color.focallyOnSurfaceVariant)

            if predefinedTaskStore.tasks.isEmpty {
                Text("No predefined tasks yet.")
                    .font(.focallyBody)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, FocallySpacing.md)
            } else {
                VStack(spacing: FocallySpacing.sm) {
                    ForEach(predefinedTaskStore.tasks) { task in
                        TaskRowView(
                            task: task,
                            onStart: { start(task) },
                            onEdit: { edit(task) },
                            onDelete: { predefinedTaskStore.remove(task) }
                        )
                    }
                }
            }
        }
        .padding(FocallySpacing.lg)
        .focallyCard()
        .sheet(isPresented: $showingEditor) {
            PredefinedTaskEditorSheet(task: editingTask) { task in
                if editingTask == nil {
                    predefinedTaskStore.add(task)
                } else {
                    predefinedTaskStore.update(task)
                }
                showingEditor = false
                editingTask = nil
            }
        }
    }

    private func addTask() {
        editingTask = nil
        showingEditor = true
    }

    private func edit(_ task: PredefinedTask) {
        editingTask = task
        showingEditor = true
    }

    private func start(_ task: PredefinedTask) {
        timerService.updateWorkDuration(minutes: task.durationMinutes)
        timerService.startWorkSession(activity: task.name, emoji: task.emoji, durationMinutes: task.durationMinutes)
    }
}

private struct PredefinedTaskEditorSheet: View {
    @EnvironmentObject private var slackService: SlackService
    @Environment(\.dismiss) private var dismiss

    let task: PredefinedTask?
    let onSave: (PredefinedTask) -> Void

    @State private var name: String
    @State private var emoji: String
    @State private var durationMinutes: Int
    @State private var cycles: Int
    @State private var selectedColorID: String

    init(task: PredefinedTask?, onSave: @escaping (PredefinedTask) -> Void) {
        self.task = task
        self.onSave = onSave
        _name = State(initialValue: task?.name ?? "")
        _emoji = State(initialValue: task?.emoji ?? "📝")
        _durationMinutes = State(initialValue: task?.durationMinutes ?? 25)
        _cycles = State(initialValue: task?.cycles ?? 1)
        let defaultColor = TaskColorOption.all.first { $0.backgroundHex == task?.iconBgColor && $0.foregroundHex == task?.iconFgColor } ?? TaskColorOption.all[0]
        _selectedColorID = State(initialValue: defaultColor.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(task == nil ? "New predefined task" : "Edit predefined task")
                .font(.focallyH2)
                .foregroundStyle(Color.focallyOnSurface)

            VStack(alignment: .leading, spacing: 8) {
                Text("Task name")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                TextField("Deep work block", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Status emoji")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
                HStack(spacing: 10) {
                    CompactStatusEmojiButton(selection: $emoji, options: FocusStatusOption.common)
                    TextField("Emoji or :shortcode:", text: $emoji)
                        .textFieldStyle(.roundedBorder)
                }
            }

            DurationControl(minutes: $durationMinutes, range: 5...180, step: 5)

            Stepper(value: $cycles, in: 1...8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cycles")
                        .font(.focallyCaption)
                        .foregroundStyle(Color.focallyOnSurfaceVariant)
                    Text("\(cycles) cycle\(cycles == 1 ? "" : "s")")
                        .font(.focallyBodyBold)
                        .foregroundStyle(Color.focallyOnSurface)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                    ForEach(TaskColorOption.all) { option in
                        Button {
                            selectedColorID = option.id
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: option.backgroundHex))
                                    .overlay {
                                        Circle()
                                            .stroke(Color(hex: option.foregroundHex), lineWidth: 1)
                                    }
                                    .frame(width: 18, height: 18)
                                Text(option.name)
                                    .font(.focallyCaption)
                            }
                            .foregroundStyle(Color.focallyOnSurface)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedColorID == option.id ? Color.focallyPrimary.opacity(0.14) : Color.focallySurfaceContainerLow)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedColorID == option.id ? Color.focallyPrimary : Color.clear, lineWidth: 1.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            previewCard

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Save") {
                    onSave(buildTask())
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear {
            slackService.refreshEmojiCatalogIfPossible()
        }
    }

    private func buildTask() -> PredefinedTask {
        let color = TaskColorOption.all.first(where: { $0.id == selectedColorID }) ?? TaskColorOption.all[0]
        return PredefinedTask(
            id: task?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            emoji: emoji,
            icon: task?.icon ?? "sparkles",
            iconBgColor: color.backgroundHex,
            iconFgColor: color.foregroundHex,
            durationMinutes: durationMinutes,
            cycles: cycles
        )
    }

    private var previewCard: some View {
        let color = TaskColorOption.all.first(where: { $0.id == selectedColorID }) ?? TaskColorOption.all[0]

        return HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 18))
                .frame(width: 40, height: 40)
                .background(Color(hex: color.backgroundHex))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: color.foregroundHex).opacity(0.28), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Task preview" : name.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.focallyBodyBold)
                    .foregroundStyle(Color.focallyOnSurface)
                Text("\(durationMinutes)m • \(cycles) cycle\(cycles == 1 ? "" : "s")")
                    .font(.focallyCaption)
                    .foregroundStyle(Color.focallyOnSurfaceVariant)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.focallySurfaceContainerLowest.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
