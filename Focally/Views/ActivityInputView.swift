import SwiftUI

struct ActivityInputView: View {
    @State private var activity: String = ""
    @State private var selectedEmoji: String = "📝"
    @State private var selectedDuration: Int = 25
    @State private var customMinutes: String = ""
    @State private var predefinedTasks: [PredefinedTask] = []
    @State private var selectedTaskIndex: Int? = nil

    let onStart: (String, String, Int) -> Void
    let onCancel: () -> Void

    let emojis = ["📝", "💻", "📖", "🎨", "📊", "🔧", "📞", "🧠", "📌", "🎯", "🎧"]
    let durations = [25, 45, 60, 90]

    var body: some View {
        VStack(spacing: 18) {
            Text("Start Focus Session")
                .font(.headline)

            predefinedTaskSection

            VStack(alignment: .leading, spacing: 6) {
                Text("What are you working on?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. Creating monthly reports", text: $activity)
                    .textFieldStyle(.roundedBorder)
                Text("Choose a saved task for one-click fill, or type a custom activity below.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Activity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 6), count: 6), spacing: 6) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                        } label: {
                            Text(emoji)
                                .font(.title2)
                                .frame(width: 36, height: 36)
                                .background(selectedEmoji == emoji ? Color.accentColor.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedEmoji == emoji ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Emoji: \(emoji)")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Duration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(durations, id: \.self) { duration in
                        Button {
                            selectedDuration = duration
                            customMinutes = ""
                        } label: {
                            Text("\(duration)m")
                                .font(.caption)
                                .fontWeight(selectedDuration == duration ? .bold : .regular)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedDuration == duration ? Color.accentColor : Color.gray.opacity(0.2))
                                .foregroundStyle(selectedDuration == duration ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(duration) minutes")
                    }
                }
                HStack {
                    TextField("Custom (min)", text: $customMinutes)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                    Spacer()
                }
                    .onChange(of: customMinutes) { _, newValue in
                        if let minutes = Int(newValue), minutes > 0 {
                            selectedDuration = minutes
                        }
                    }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Cancel")

                Button {
                    let duration = Int(customMinutes) ?? selectedDuration
                    onStart(activity, selectedEmoji, duration)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(activity.trimmingCharacters(in: .whitespaces).isEmpty || selectedDuration <= 0)
                .accessibilityLabel("Start focus session")
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear {
            let defaults = UserDefaults.standard
            activity = defaults.string(forKey: "lastActivity") ?? ""
            selectedEmoji = defaults.string(forKey: "lastEmoji") ?? "📝"
            let savedDuration = defaults.integer(forKey: "lastDuration")
            if savedDuration > 0 {
                selectedDuration = savedDuration
            }
            loadPredefinedTasks()
        }
    }

    private var predefinedTaskSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saved tasks")
                .font(.caption)
                .foregroundStyle(.secondary)

            if predefinedTasks.isEmpty {
                Text("No saved tasks yet. Configure tasks in Settings for one-click starts.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(predefinedTasks.enumerated()), id: \.element.id) { index, task in
                        Button {
                            applyPredefinedTask(at: index)
                        } label: {
                            HStack(spacing: 10) {
                                HStack(spacing: 8) {
                                    Text(task.emoji)
                                    Text(task.name)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if selectedTaskIndex == index {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.semibold))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedTaskIndex == index ? Color.accentColor : Color.gray.opacity(0.15))
                            .foregroundStyle(selectedTaskIndex == index ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Saved task: \(task.name)")
                    }
                }
            }
        }
    }

    private func loadPredefinedTasks() {
        let defaults = UserDefaults.standard

        guard let data = defaults.data(forKey: PredefinedTask.defaultsKey),
              let tasks = try? JSONDecoder().decode([PredefinedTask].self, from: data) else {
            predefinedTasks = []
            selectedTaskIndex = nil
            return
        }

        predefinedTasks = tasks

        guard !tasks.isEmpty else {
            selectedTaskIndex = nil
            return
        }

        applyPredefinedTask(at: 0)
    }

    private func applyPredefinedTask(at index: Int) {
        guard predefinedTasks.indices.contains(index) else { return }
        let task = predefinedTasks[index]
        selectedTaskIndex = index
        activity = task.name
        selectedEmoji = task.emoji
    }
}
