import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var slackService: SlackService
    @State private var slackToken: String = ""
    @AppStorage("customDurations") private var customDurationsData = "[25, 45, 60, 90]"
    @AppStorage("lastActivity") private var lastActivity = ""
    @AppStorage("lastEmoji") private var lastEmoji = "📝"
    @AppStorage("lastDuration") private var lastDuration = 25
    @AppStorage("useSystemTheme") private var useSystemTheme = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("soundName") private var soundName = "Bell"
    @AppStorage("soundRepeatCount") private var soundRepeatCount = 5

    @State private var newDuration = ""
    @State private var predefinedTasks: [PredefinedTask] = []
    @State private var newTaskName = ""
    @State private var newTaskEmoji = "📝"

    let sounds = ["Bell", "Ping", "Tink", "Pop", "Purr", "Hero", "Morse", "Submarine", "Glass"]

    var body: some View {
        TabView {
            durationsTab
                .tabItem { Label("Timer", systemImage: "timer") }
            tasksTab
                .tabItem { Label("Tasks", systemImage: "checklist") }
            connectionsTab
                .tabItem { Label("Connections", systemImage: "link") }
            secretsTab
                .tabItem { Label("Secrets", systemImage: "key.fill") }
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
        }
        .frame(width: 400, height: 350)
        .onAppear {
            slackToken = slackService.token ?? ""
        }
    }

    // MARK: - Durations

    private var durationsTab: some View {
        VStack(spacing: 16) {
            Text("Focus Durations")
                .font(.headline)

            HStack(spacing: 8) {
                TextField("Minutes", text: $newDuration)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Button("Add") {
                    if let minutes = Int(newDuration), minutes > 0 {
                        var durations = currentDurations
                        if !durations.contains(minutes) {
                            durations.append(minutes)
                            durations.sort()
                            customDurationsData = encode(durations)
                        }
                        newDuration = ""
                    }
                }
                .disabled(newDuration.isEmpty || Int(newDuration) == nil)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(70), spacing: 8), count: 4), spacing: 8) {
                ForEach(currentDurations, id: \.self) { duration in
                    HStack {
                        Text("\(duration)m")
                            .font(.caption)
                        Spacer()
                        Button {
                            removeDuration(duration)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Divider()

            // Sound settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Alert Sound")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Toggle("Enable sound", isOn: $soundEnabled)

                if soundEnabled {
                    Picker("Sound", selection: $soundName) {
                        ForEach(sounds, id: \.self) { sound in
                            Text(sound).tag(sound)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)

                    HStack {
                        Stepper("Repeat: \(soundRepeatCount)", value: $soundRepeatCount, in: 1...20)
                    }
                }
            }
        }
        .padding(16)
    }

    // MARK: - Predefined Tasks

    private var tasksTab: some View {
        VStack(spacing: 16) {
            Text("Predefined Tasks")
                .font(.headline)

            HStack(spacing: 8) {
                TextField("Task name", text: $newTaskName)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $newTaskEmoji) {
                    ForEach(["📝","💻","📖","🎨","📊","🔧","📞","🧠","📌","🎯","🎧","💬"], id: \.self) { e in
                        Text(e).tag(e)
                    }
                }
                .frame(width: 50)
                Button("Add") {
                    if !newTaskName.trimmingCharacters(in: .whitespaces).isEmpty {
                        predefinedTasks.append(PredefinedTask(name: newTaskName.trimmingCharacters(in: .whitespaces), emoji: newTaskEmoji))
                        newTaskName = ""
                        saveTasks()
                    }
                }
                .disabled(newTaskName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if predefinedTasks.isEmpty {
                Text("No predefined tasks yet")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            List {
                ForEach(predefinedTasks) { task in
                    HStack {
                        Text(task.emoji)
                        Text(task.name)
                        Spacer()
                        Button {
                            removeTask(task)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .onAppear { loadTasks() }
    }

    // MARK: - Connections

    private var connectionsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connections")
                .font(.headline)

            // Slack
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundStyle(.secondary)
                    Text("Slack Status")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Toggle("", isOn: $slackService.isEnabled)
                }

                HStack {
                    if slackService.isConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connected")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if let error = slackService.connectionError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("Configure token in Secrets tab")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Google Calendar (Iteración 3)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text("Google Calendar")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("Coming soon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // n8n (Iteración 5)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.secondary)
                    Text("n8n WebSocket")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("Coming soon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Secrets

    private var secretsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Secrets")
                .font(.headline)

            Text("Tokens and credentials are stored securely in macOS Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Slack Token
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundStyle(.secondary)
                    Text("Slack User Token")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                SecureField("xoxp-...", text: $slackToken)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: slackToken) { _, newValue in
                        slackService.token = newValue.isEmpty ? nil : newValue
                    }

                HStack {
                    Button("Save & Test") {
                        slackService.testConnection()
                    }
                    .disabled(slackService.token == nil || slackService.token?.isEmpty == true)

                    if slackService.isConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Spacer()
                }

                Text("Create a Slack app at api.slack.com → OAuth & Permissions → users.profile:write")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Google Calendar (Iteración 3)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text("Google Calendar")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("Coming soon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        VStack(spacing: 16) {
            Text("Appearance")
                .font(.headline)

            Toggle("Use system theme", isOn: $useSystemTheme)

            Text("Colors adapt automatically to your macOS appearance (Light/Dark mode).")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Helpers

    private var currentDurations: [Int] {
        (try? JSONDecoder().decode([Int].self, from: customDurationsData.data(using: .utf8) ?? Data())) ?? [25, 45, 60, 90]
    }

    private func encode(_ durations: [Int]) -> String {
        (try? JSONEncoder().encode(durations)).flatMap { String(data: $0, encoding: .utf8) } ?? "[25, 45, 60, 90]"
    }

    private func removeDuration(_ duration: Int) {
        var durations = currentDurations
        durations.removeAll { $0 == duration }
        customDurationsData = encode(durations)
    }

    // Predefined tasks persistence
    private struct PredefinedTask: Identifiable, Codable {
        let id = UUID()
        let name: String
        let emoji: String
    }

    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: "predefinedTasks"),
           let tasks = try? JSONDecoder().decode([PredefinedTask].self, from: data) {
            predefinedTasks = tasks
        }
    }

    private func saveTasks() {
        if let data = try? JSONEncoder().encode(predefinedTasks) {
            UserDefaults.standard.set(data, forKey: "predefinedTasks")
        }
    }

    private func removeTask(_ task: PredefinedTask) {
        predefinedTasks.removeAll { $0.id == task.id }
        saveTasks()
    }
}
