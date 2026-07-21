import Foundation
import Observation

struct FocusMode: Identifiable, Codable, Equatable {
    static let defaultsKey = "focusModes"

    static let focusTimeID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let meetingID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let inboxID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    let id: UUID
    var name: String
    var emoji: String
    var statusText: String
    var durationMinutes: Int
    var enableDND: Bool
    var enablePomodoro: Bool
    var pomodoroWorkMinutes: Int
    var pomodoroBreakMinutes: Int
    var pomodoroLongBreakMinutes: Int
    var pomodoroRounds: Int

    init(id: UUID = UUID(),
         name: String = "",
         emoji: String = ":brain:",
         statusText: String = "",
         durationMinutes: Int = 25,
         enableDND: Bool = false,
         enablePomodoro: Bool = false,
         pomodoroWorkMinutes: Int = 25,
         pomodoroBreakMinutes: Int = 5,
         pomodoroLongBreakMinutes: Int = 15,
         pomodoroRounds: Int = 4) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.statusText = statusText
        self.durationMinutes = durationMinutes
        self.enableDND = enableDND
        self.enablePomodoro = enablePomodoro
        self.pomodoroWorkMinutes = pomodoroWorkMinutes
        self.pomodoroBreakMinutes = pomodoroBreakMinutes
        self.pomodoroLongBreakMinutes = pomodoroLongBreakMinutes
        self.pomodoroRounds = pomodoroRounds
    }

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, statusText, durationMinutes, enableDND, enablePomodoro
        case pomodoroWorkMinutes, pomodoroBreakMinutes, pomodoroLongBreakMinutes, pomodoroRounds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ":brain:"
        statusText = try c.decodeIfPresent(String.self, forKey: .statusText) ?? ""
        durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 25
        enableDND = try c.decodeIfPresent(Bool.self, forKey: .enableDND) ?? false
        enablePomodoro = try c.decodeIfPresent(Bool.self, forKey: .enablePomodoro) ?? false
        pomodoroWorkMinutes = try c.decodeIfPresent(Int.self, forKey: .pomodoroWorkMinutes) ?? 25
        pomodoroBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .pomodoroBreakMinutes) ?? 5
        pomodoroLongBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .pomodoroLongBreakMinutes) ?? 15
        pomodoroRounds = try c.decodeIfPresent(Int.self, forKey: .pomodoroRounds) ?? 4
    }

    static let builtInModes: [FocusMode] = [
        FocusMode(
            id: focusTimeID,
            name: "Focus Time",
            emoji: ":brain:",
            statusText: "In focus mode",
            durationMinutes: 25,
            enableDND: true,
            enablePomodoro: true,
            pomodoroWorkMinutes: 25,
            pomodoroBreakMinutes: 5,
            pomodoroLongBreakMinutes: 15,
            pomodoroRounds: 4
        ),
        FocusMode(
            id: meetingID,
            name: "Meeting",
            emoji: ":calendar:",
            statusText: "In a meeting",
            durationMinutes: 30,
            enableDND: false,
            enablePomodoro: false,
            pomodoroWorkMinutes: 30,
            pomodoroBreakMinutes: 5,
            pomodoroLongBreakMinutes: 15,
            pomodoroRounds: 1
        ),
        FocusMode(
            id: inboxID,
            name: "Inbox",
            emoji: ":email:",
            statusText: "Clearing inbox",
            durationMinutes: 15,
            enableDND: false,
            enablePomodoro: false,
            pomodoroWorkMinutes: 15,
            pomodoroBreakMinutes: 5,
            pomodoroLongBreakMinutes: 15,
            pomodoroRounds: 1
        )
    ]

    var displayEmoji: String {
        EmojiValidator.convertShortcodeToUnicode(emoji, workspaceEmojis: []) ?? emoji
    }

    var isCustomWorkspaceEmoji: Bool {
        EmojiValidator.isCustomWorkspaceEmoji(emoji, workspaceEmojiCodes: [])
    }

    func isCustomWorkspaceEmoji(workspaceEmojiCodes: [String]) -> Bool {
        EmojiValidator.isCustomWorkspaceEmoji(emoji, workspaceEmojiCodes: workspaceEmojiCodes)
    }

    func imageURL(workspaceEmojiImageURLs: [String: String], workspaceEmojiCodes: [String]) -> URL? {
        guard isCustomWorkspaceEmoji(workspaceEmojiCodes: workspaceEmojiCodes) else { return nil }
        let urlString = workspaceEmojiImageURLs[emoji.trimmingCharacters(in: .whitespacesAndNewlines)]
        return urlString.flatMap { URL(string: $0) }
    }

    var sanitizedDurationMinutes: Int {
        min(max(durationMinutes, 5), 120)
    }

    var sanitizedPomodoroWorkMinutes: Int {
        min(max(pomodoroWorkMinutes, 5), 120)
    }

    var sanitizedPomodoroBreakMinutes: Int {
        min(max(pomodoroBreakMinutes, 1), 30)
    }

    var sanitizedPomodoroLongBreakMinutes: Int {
        min(max(pomodoroLongBreakMinutes, 5), 60)
    }

    var sanitizedPomodoroRounds: Int {
        min(max(pomodoroRounds, 1), 12)
    }

    var isBuiltIn: Bool {
        id == FocusMode.focusTimeID || id == FocusMode.meetingID || id == FocusMode.inboxID
    }

    func sanitized() -> FocusMode {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStatus = statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveName = trimmedName.isEmpty ? (trimmedStatus.isEmpty ? "Untitled" : trimmedStatus) : trimmedName
        return FocusMode(
            id: id,
            name: effectiveName,
            emoji: emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ":brain:" : emoji.trimmingCharacters(in: .whitespacesAndNewlines),
            statusText: trimmedStatus.isEmpty ? effectiveName : trimmedStatus,
            durationMinutes: sanitizedDurationMinutes,
            enableDND: enableDND,
            enablePomodoro: enableDND && enablePomodoro,
            pomodoroWorkMinutes: sanitizedPomodoroWorkMinutes,
            pomodoroBreakMinutes: sanitizedPomodoroBreakMinutes,
            pomodoroLongBreakMinutes: sanitizedPomodoroLongBreakMinutes,
            pomodoroRounds: sanitizedPomodoroRounds
        )
    }
}

@MainActor
@Observable
final class FocusModeStore {
    private(set) var modes: [FocusMode] = [] {
        didSet { saveModes() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.modes = Self.loadModes(from: defaults)
    }

    func update(_ mode: FocusMode) {
        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else { return }
        modes[index] = mode.sanitized()
        modes = Self.orderedModes(from: modes)
    }

    func add(_ mode: FocusMode) {
        var newMode = mode.sanitized()
        if newMode.id == UUID() {
            newMode = FocusMode(id: UUID(), name: newMode.name, emoji: newMode.emoji, statusText: newMode.statusText, durationMinutes: newMode.durationMinutes, enableDND: newMode.enableDND, enablePomodoro: newMode.enablePomodoro, pomodoroWorkMinutes: newMode.pomodoroWorkMinutes, pomodoroBreakMinutes: newMode.pomodoroBreakMinutes, pomodoroLongBreakMinutes: newMode.pomodoroLongBreakMinutes, pomodoroRounds: newMode.pomodoroRounds)
        }
        modes.append(newMode)
        modes = Self.orderedModes(from: modes)
    }

    func delete(_ mode: FocusMode) {
        // Cannot delete built-in modes
        guard !mode.isBuiltIn else { return }
        modes.removeAll(where: { $0.id == mode.id })
        modes = Self.orderedModes(from: modes)
    }

    func mode(withID id: UUID) -> FocusMode? {
        modes.first(where: { $0.id == id })
    }

    private func saveModes() {
        guard let data = try? JSONEncoder().encode(modes) else { return }
        defaults.set(data, forKey: FocusMode.defaultsKey)
    }

    private static func loadModes(from defaults: UserDefaults) -> [FocusMode] {
        guard let data = defaults.data(forKey: FocusMode.defaultsKey),
              let decoded = try? JSONDecoder().decode([FocusMode].self, from: data) else {
            return FocusMode.builtInModes
        }

        let sanitized = decoded.map { $0.sanitized() }
        let merged = FocusMode.builtInModes.map { builtInMode in
            sanitized.first(where: { $0.id == builtInMode.id }) ?? builtInMode
        }
        return orderedModes(from: merged)
    }

    private static func orderedModes(from modes: [FocusMode]) -> [FocusMode] {
        let order = [FocusMode.focusTimeID, FocusMode.meetingID, FocusMode.inboxID]
        return modes.sorted { left, right in
            let leftIndex = order.firstIndex(of: left.id) ?? Int.max
            let rightIndex = order.firstIndex(of: right.id) ?? Int.max
            return leftIndex < rightIndex
        }
    }
}
