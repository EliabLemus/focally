import SwiftUI

struct ActivityInputView: View {
    @State private var activity: String = ""
    @State private var selectedEmoji: String = "📝"
    @State private var selectedDuration: Int = 25
    @State private var customMinutes: String = ""

    let onStart: (String, String, Int) -> Void
    let onCancel: () -> Void

    let emojis = ["📝", "💻", "📖", "🎨", "📊", "🔧", "📞", "🧠", "📌", "🎯", "🎧"]
    let durations = [25, 45, 60, 90]

    var body: some View {
        VStack(spacing: 14) {
            Text("Start Focus Session")
                .font(.headline)

            // Activity name
            VStack(alignment: .leading, spacing: 4) {
                Text("What are you working on?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. Creating monthly reports", text: $activity)
                    .textFieldStyle(.roundedBorder)
            }

            // Emoji picker
            VStack(alignment: .leading, spacing: 4) {
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
                    }
                }
            }

            // Duration picker
            VStack(alignment: .leading, spacing: 4) {
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
                    }
                }
                TextField("Custom (min)", text: $customMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .onChange(of: customMinutes) { _, newValue in
                        if let minutes = Int(newValue), minutes > 0 {
                            selectedDuration = minutes
                        }
                    }
            }

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

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
        }
    }
}
