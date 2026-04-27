import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var slackService: SlackService
    @EnvironmentObject var calendarService: GoogleCalendarService

    @AppStorage("customDurations") private var customDurationsData = "[25, 45, 60, 90]"
    @AppStorage("useSystemTheme") private var useSystemTheme = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("soundName") private var soundName = "Bell"
    @AppStorage("soundRepeatCount") private var soundRepeatCount = 5
    @AppStorage(SlackService.statusEmojiDefaultsKey) private var slackStatusEmoji = SlackService.defaultStatusEmoji

    @State private var draftSlackToken = ""
    @State private var draftGoogleClientID = ""
    @State private var draftGoogleClientSecret = ""
    @State private var draftSlackEnabled = false
    @State private var draftGoogleCalendarEnabled = false
    @State private var draftSlackEmoji = SlackService.defaultStatusEmoji
    @State private var draftDurations: [Int] = [25, 45, 60, 90]
    @State private var draftPredefinedTasks: [PredefinedTask] = []
    @State private var draftUseSystemTheme = true
    @State private var draftSoundEnabled = true
    @State private var draftSoundName = "Bell"
    @State private var draftSoundRepeatCount = 5

    @State private var newDuration = ""
    @State private var newTaskName = ""
    @State private var newTaskEmoji = "📝"
    @State private var previewSound: NSSound?
    @State private var saveButtonTitle = "Save Changes"
    @FocusState private var focusedField: Field?

    private enum Field {
        case slackToken
        case slackEmoji
        case googleClientID
        case googleClientSecret
    }

    private let sounds = ["Bell", "Ping", "Tink", "Pop", "Purr", "Hero", "Morse", "Submarine", "Glass"]
    private let slackEmojiSuggestions: [EmojiSuggestion] = [
        .init(symbol: "⏳", value: SlackService.defaultStatusEmoji),
        .init(symbol: "🎧", value: ":headphones:"),
        .init(symbol: "☕", value: ":coffee:"),
        .init(symbol: "🔥", value: ":fire:"),
        .init(symbol: "🎯", value: ":dart:"),
        .init(symbol: "📚", value: ":books:"),
        .init(symbol: "💻", value: ":computer:"),
        .init(symbol: "🚫", value: ":no_entry_sign:")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                tabScrollView {
                    durationsTab
                }
                    .tabItem { Label("Timer", systemImage: "timer") }
                tabScrollView {
                    tasksTab
                }
                    .tabItem { Label("Tasks", systemImage: "checklist") }
                tabScrollView {
                    connectionsTab
                }
                    .tabItem { Label("Connections", systemImage: "link") }
                tabScrollView {
                    secretsTab
                }
                    .tabItem { Label("Secrets", systemImage: "key.fill") }
                tabScrollView {
                    appearanceTab
                }
                    .tabItem { Label("Appearance", systemImage: "paintbrush") }
            }
            .frame(maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)

            Divider()

            HStack {
                Spacer()
                Button(saveButtonTitle) {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!hasUnsavedChanges)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 420, minHeight: 430)
        .onAppear(perform: loadSettings)
        .onChange(of: focusedField) { previous, current in
            if previous == .slackToken, current != .slackToken {
                commitSlackTokenDraft()
            }
            if previous == .slackEmoji, current != .slackEmoji {
                draftSlackEmoji = normalizedSlackEmoji(draftSlackEmoji)
            }
            if previous == .googleClientID, current != .googleClientID {
                draftGoogleClientID = draftGoogleClientID.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if previous == .googleClientSecret, current != .googleClientSecret {
                draftGoogleClientSecret = draftGoogleClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    private var durationsTab: some View {
        VStack(spacing: 16) {
            Text("Focus Durations")
                .font(.headline)

            HStack(spacing: 8) {
                TextField("Minutes", text: $newDuration)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Button("Add") {
                    addDuration()
                }
                .disabled(newDuration.isEmpty || Int(newDuration) == nil)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(70), spacing: 8), count: 4), spacing: 8) {
                ForEach(draftDurations, id: \.self) { duration in
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Alert Sound")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Toggle("Enable sound", isOn: $draftSoundEnabled)

                if draftSoundEnabled {
                    VStack(spacing: 6) {
                        ForEach(sounds, id: \.self) { soundOption in
                            soundRow(soundOption)
                        }
                    }

                    Stepper("Repeat: \(draftSoundRepeatCount)", value: $draftSoundRepeatCount, in: 1...20)
                }
            }

            Spacer()
        }
    }

    private var tasksTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Predefined Tasks")
                .font(.headline)

            HStack(spacing: 8) {
                TextField("Task name", text: $newTaskName)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $newTaskEmoji) {
                    ForEach(["📝", "💻", "📖", "🎨", "📊", "🔧", "📞", "🧠", "📌", "🎯", "🎧", "💬"], id: \.self) { emoji in
                        Text(emoji).tag(emoji)
                    }
                }
                .frame(width: 50)
                Button("Add") {
                    let trimmedName = newTaskName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else { return }
                    draftPredefinedTasks.append(PredefinedTask(name: trimmedName, emoji: newTaskEmoji))
                    newTaskName = ""
                }
                .disabled(newTaskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if draftPredefinedTasks.isEmpty {
                Text("No predefined tasks yet")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                VStack(spacing: 8) {
                    ForEach(draftPredefinedTasks) { task in
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var connectionsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connections")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundStyle(.secondary)
                    Text("Slack Status")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Toggle("", isOn: $draftSlackEnabled)
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

                if draftSlackEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Focus status emoji")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Custom emoji", text: $draftSlackEmoji)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .slackEmoji)
                            .onSubmit {
                                draftSlackEmoji = normalizedSlackEmoji(draftSlackEmoji)
                            }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                            ForEach(slackEmojiSuggestions) { suggestion in
                                emojiSuggestionChip(suggestion)
                            }
                        }

                        Text("Default: ⏳ \(SlackService.defaultStatusEmoji)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(.secondary)
                            Text("Google Calendar")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Toggle("", isOn: $draftGoogleCalendarEnabled)
                        }

                        HStack {
                            if calendarService.isSignedIn {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else if let error = calendarService.connectionError,
                                      calendarService.isEnabled || !savedGoogleClientID.isEmpty {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Text("Configure credentials in Secrets tab")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        HStack(spacing: 10) {
                            Button(calendarService.isSignedIn ? "Sign Out" : "Sign in with Google") {
                                if calendarService.isSignedIn {
                                    calendarService.signOut()
                                } else {
                                    calendarService.signIn()
                                }
                            }
                            .disabled(!isGoogleCalendarReadyForSignIn)

                            if calendarService.isSignedIn {
                                Button("Refresh Events") {
                                    calendarService.fetchTodayEvents()
                                }
                            }
                        }

                        if hasPendingGoogleSettingsChanges {
                            Text("Save Changes before signing in or refreshing Google Calendar.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

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
    }

    private var secretsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Secrets")
                .font(.headline)

            Text("Tokens and credentials are stored securely in macOS Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "message.fill")
                        .foregroundStyle(.secondary)
                    Text("Slack User Token")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                SecureField("xoxp-...", text: $draftSlackToken)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .slackToken)
                    .onSubmit {
                        commitSlackTokenDraft()
                    }

                if savedSlackToken != draftSlackToken {
                    Text("Save Changes to persist the updated token.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if slackService.isConnected {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Slack token verified")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Text("Create a Slack app at api.slack.com → OAuth & Permissions → users.profile:write")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text("Google Calendar")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                TextField("Google Client ID", text: $draftGoogleClientID)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .googleClientID)

                SecureField("Google Client Secret", text: $draftGoogleClientSecret)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .googleClientSecret)

                if savedGoogleClientID != draftGoogleClientID || savedGoogleClientSecret != draftGoogleClientSecret {
                    Text("Save Changes to persist the updated Google credentials.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Link("Open Google Cloud Console", destination: URL(string: "https://console.cloud.google.com/apis/credentials")!)
                    .font(.caption)

                Text("Create an OAuth client with redirect URI http://localhost and scope calendar.readonly.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                .padding(12)
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
    }

    private var appearanceTab: some View {
        VStack(spacing: 16) {
            Text("Appearance")
                .font(.headline)

            Toggle("Use system theme", isOn: $draftUseSystemTheme)

            Text("Colors adapt automatically to your macOS appearance (Light/Dark mode).")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private func tabScrollView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(16)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var savedSlackToken: String {
        slackService.token ?? ""
    }

    private var savedGoogleClientID: String {
        calendarService.clientID ?? ""
    }

    private var savedGoogleClientSecret: String {
        calendarService.clientSecret ?? ""
    }

    private var hasPendingGoogleSettingsChanges: Bool {
        draftGoogleCalendarEnabled != calendarService.isEnabled ||
        draftGoogleClientID != savedGoogleClientID ||
        draftGoogleClientSecret != savedGoogleClientSecret
    }

    private var isGoogleCalendarReadyForSignIn: Bool {
        if calendarService.isSignedIn {
            return true
        }

        if hasPendingGoogleSettingsChanges {
            return false
        }

        return calendarService.isEnabled && !savedGoogleClientID.isEmpty && !savedGoogleClientSecret.isEmpty
    }

    private var hasUnsavedChanges: Bool {
        if draftUseSystemTheme != useSystemTheme { return true }
        if draftSoundEnabled != soundEnabled { return true }
        if draftSoundName != soundName { return true }
        if draftSoundRepeatCount != soundRepeatCount { return true }
        if draftSlackEnabled != slackService.isEnabled { return true }
        if draftGoogleCalendarEnabled != calendarService.isEnabled { return true }
        if normalizedSlackEmoji(draftSlackEmoji) != normalizedSlackEmoji(slackStatusEmoji) { return true }
        if draftSlackToken != savedSlackToken { return true }
        if draftGoogleClientID != savedGoogleClientID { return true }
        if draftGoogleClientSecret != savedGoogleClientSecret { return true }
        if draftDurations != decodedDurations(from: customDurationsData) { return true }
        if draftPredefinedTasks != loadTasks() { return true }
        return false
    }

    private func addDuration() {
        guard let minutes = Int(newDuration), minutes > 0 else { return }
        if !draftDurations.contains(minutes) {
            draftDurations.append(minutes)
            draftDurations.sort()
        }
        newDuration = ""
    }

    private func removeDuration(_ duration: Int) {
        draftDurations.removeAll { $0 == duration }
    }

    private func loadSettings() {
        draftSlackToken = savedSlackToken
        draftGoogleClientID = savedGoogleClientID
        draftGoogleClientSecret = savedGoogleClientSecret
        draftSlackEnabled = slackService.isEnabled
        draftGoogleCalendarEnabled = calendarService.isEnabled
        draftSlackEmoji = normalizedSlackEmoji(slackStatusEmoji)
        draftDurations = decodedDurations(from: customDurationsData)
        draftPredefinedTasks = loadTasks()
        draftUseSystemTheme = useSystemTheme
        draftSoundEnabled = soundEnabled
        draftSoundName = soundName
        draftSoundRepeatCount = soundRepeatCount
        saveButtonTitle = "Save Changes"
    }

    private func saveSettings() {
        commitSlackTokenDraft()
        draftGoogleClientID = draftGoogleClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        draftGoogleClientSecret = draftGoogleClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        useSystemTheme = draftUseSystemTheme
        soundEnabled = draftSoundEnabled
        soundName = draftSoundName
        soundRepeatCount = draftSoundRepeatCount
        customDurationsData = encode(draftDurations)
        slackStatusEmoji = normalizedSlackEmoji(draftSlackEmoji)
        saveTasks(draftPredefinedTasks)

        slackService.isEnabled = draftSlackEnabled
        slackService.token = draftSlackToken.isEmpty ? nil : draftSlackToken
        calendarService.isEnabled = draftGoogleCalendarEnabled
        calendarService.saveClientCredentials(
            clientID: draftGoogleClientID,
            clientSecret: draftGoogleClientSecret
        )

        if draftSlackToken.isEmpty {
            slackService.isConnected = false
            slackService.connectionError = draftSlackEnabled ? "No token configured" : nil
        } else if draftSlackEnabled {
            slackService.testConnection()
        } else {
            slackService.connectionError = nil
        }

        if !calendarService.isEnabled {
            calendarService.connectionError = nil
            calendarService.events = []
        } else if draftGoogleClientID.isEmpty || draftGoogleClientSecret.isEmpty {
            calendarService.connectionError = "Missing Google Client ID or Client Secret"
        } else if calendarService.isSignedIn {
            calendarService.fetchTodayEvents()
        } else {
            calendarService.connectionError = nil
        }

        saveButtonTitle = "Saved ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if !hasUnsavedChanges {
                saveButtonTitle = "Save Changes"
            }
        }
    }

    private func commitSlackTokenDraft() {
        draftSlackToken = draftSlackToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedSlackEmoji(_ emoji: String) -> String {
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? SlackService.defaultStatusEmoji : trimmed
    }

    private func decodedDurations(from rawValue: String) -> [Int] {
        (try? JSONDecoder().decode([Int].self, from: rawValue.data(using: .utf8) ?? Data())) ?? [25, 45, 60, 90]
    }

    private func encode(_ durations: [Int]) -> String {
        (try? JSONEncoder().encode(durations)).flatMap { String(data: $0, encoding: .utf8) } ?? "[25, 45, 60, 90]"
    }

    private func previewSoundSelection(named soundName: String) {
        previewSound?.stop()

        guard let url = soundURL(for: soundName) else { return }
        let sound = NSSound(contentsOf: url, byReference: true)
        previewSound = sound
        sound?.play()
    }

    @ViewBuilder
    private func soundRow(_ soundOption: String) -> some View {
        let isSelected = draftSoundName == soundOption

        Button {
            draftSoundName = soundOption
            previewSoundSelection(named: soundOption)
        } label: {
            HStack {
                Text(soundOption)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(isSelected ? 0.16 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func emojiSuggestionChip(_ suggestion: EmojiSuggestion) -> some View {
        let isSelected = normalizedSlackEmoji(draftSlackEmoji) == suggestion.value

        Button {
            draftSlackEmoji = suggestion.value
        } label: {
            HStack(spacing: 6) {
                Text(suggestion.symbol)
                Text(suggestion.value)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(isSelected ? 0.16 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func soundURL(for soundName: String) -> URL? {
        if soundName == "Bell",
           let bundledURL = Bundle.main.url(forResource: "bell", withExtension: "aiff") {
            return bundledURL
        }

        let systemSoundURL = URL(fileURLWithPath: "/System/Library/Sounds")
            .appendingPathComponent(soundName)
            .appendingPathExtension("aiff")

        if FileManager.default.fileExists(atPath: systemSoundURL.path) {
            return systemSoundURL
        }

        return nil
    }

    private func loadTasks() -> [PredefinedTask] {
        guard let data = UserDefaults.standard.data(forKey: "predefinedTasks"),
              let tasks = try? JSONDecoder().decode([PredefinedTask].self, from: data) else {
            return []
        }
        return tasks
    }

    private func saveTasks(_ tasks: [PredefinedTask]) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: "predefinedTasks")
    }

    private func removeTask(_ task: PredefinedTask) {
        draftPredefinedTasks.removeAll { $0.id == task.id }
    }
}

private struct EmojiSuggestion: Identifiable {
    let symbol: String
    let value: String

    var id: String { value }
}

private struct PredefinedTask: Identifiable, Codable, Equatable {
    var id = UUID()
    let name: String
    let emoji: String
}
