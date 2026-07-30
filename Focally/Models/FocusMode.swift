import Foundation
import Observation

enum FocusModeType: String, Codable, CaseIterable {
    case focusTime = "focus_time"
    case meeting = "meeting"
    case inbox = "inbox"
    case custom = "custom"
    case calendarVideoCall = "calendar_video_call"
    case userCustom = "user_custom"

    var id: UUID {
        switch self {
        case .focusTime: return FocusMode.focusTimeID
        case .meeting: return FocusMode.meetingID
        case .inbox: return FocusMode.inboxID
        case .custom: return UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        case .calendarVideoCall: return UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        case .userCustom: return UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        }
    }

    var localizedLabel: String {
        switch self {
        case .focusTime: return "focus_mode_type_focus_time"
        case .meeting: return "focus_mode_type_meeting"
        case .inbox: return "focus_mode_type_inbox"
        case .custom: return "focus_mode_type_custom"
        case .calendarVideoCall: return "focus_mode_type_calendar_video_call"
        case .userCustom: return "focus_mode_type_user_custom"
        }
    }
}

/// Private CodingKeys for backward-compatible decoding of the pre-0.9.3 "enableDND" field.
private enum LegacyDNDKey: String, CodingKey {
    case enableDND
}

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
    var enableMacOSDND: Bool
    var enableSlackDND: Bool
    var enablePomodoro: Bool
    var pomodoroWorkMinutes: Int
    var pomodoroBreakMinutes: Int
    var pomodoroLongBreakMinutes: Int
    var pomodoroRounds: Int
    var breakLabel: String?
    var typeDescriptor: FocusTypeDescriptor

    var type: FocusModeType {
        get { typeDescriptor.modeType }
        set { typeDescriptor = .builtIn(newValue) }
    }

    init(id: UUID = UUID(),
         name: String = "",
         emoji: String = ":brain:",
         statusText: String = "",
         durationMinutes: Int = 25,
         enableMacOSDND: Bool = false,
         enableSlackDND: Bool = false,
         enablePomodoro: Bool = false,
         pomodoroWorkMinutes: Int = 25,
         pomodoroBreakMinutes: Int = 5,
         pomodoroLongBreakMinutes: Int = 15,
         pomodoroRounds: Int = 4,
         breakLabel: String? = nil,
         type: FocusModeType = .custom,
         typeDescriptor: FocusTypeDescriptor? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.statusText = statusText
        self.durationMinutes = durationMinutes
        self.enableMacOSDND = enableMacOSDND
        self.enableSlackDND = enableSlackDND
        self.enablePomodoro = enablePomodoro
        self.pomodoroWorkMinutes = pomodoroWorkMinutes
        self.pomodoroBreakMinutes = pomodoroBreakMinutes
        self.pomodoroLongBreakMinutes = pomodoroLongBreakMinutes
        self.pomodoroRounds = pomodoroRounds
        self.breakLabel = breakLabel
        self.typeDescriptor = typeDescriptor ?? .builtIn(type)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, statusText, durationMinutes, enableMacOSDND, enableSlackDND, enablePomodoro
        case pomodoroWorkMinutes, pomodoroBreakMinutes, pomodoroLongBreakMinutes, pomodoroRounds
        case breakLabel, type, typeDescriptor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ":brain:"
        statusText = try c.decodeIfPresent(String.self, forKey: .statusText) ?? ""
        durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 25

        // Decode new keys; fall back to legacy "enableDND" if absent (backward compat <0.9.3)
        let legacyContainer = try decoder.container(keyedBy: LegacyDNDKey.self)
        let legacyDND = try legacyContainer.decodeIfPresent(Bool.self, forKey: .enableDND)
        enableMacOSDND = try c.decodeIfPresent(Bool.self, forKey: .enableMacOSDND) ?? legacyDND ?? false
        enableSlackDND = try c.decodeIfPresent(Bool.self, forKey: .enableSlackDND) ?? legacyDND ?? false

        enablePomodoro = try c.decodeIfPresent(Bool.self, forKey: .enablePomodoro) ?? false
        pomodoroWorkMinutes = try c.decodeIfPresent(Int.self, forKey: .pomodoroWorkMinutes) ?? 25
        pomodoroBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .pomodoroBreakMinutes) ?? 5
        pomodoroLongBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .pomodoroLongBreakMinutes) ?? 15
        pomodoroRounds = try c.decodeIfPresent(Int.self, forKey: .pomodoroRounds) ?? 4
        breakLabel = try c.decodeIfPresent(String.self, forKey: .breakLabel)

        // Backward compat: infer type from ID if missing
        if let descriptor = try c.decodeIfPresent(FocusTypeDescriptor.self, forKey: .typeDescriptor) {
            typeDescriptor = descriptor
        } else if let decodedType = try? c.decode(FocusModeType.self, forKey: .type) {
            typeDescriptor = .builtIn(decodedType)
        } else {
            typeDescriptor = .builtIn(Self.inferredType(from: id))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(emoji, forKey: .emoji)
        try c.encode(statusText, forKey: .statusText)
        try c.encode(durationMinutes, forKey: .durationMinutes)
        try c.encode(enableMacOSDND, forKey: .enableMacOSDND)
        try c.encode(enableSlackDND, forKey: .enableSlackDND)
        try c.encode(enablePomodoro, forKey: .enablePomodoro)
        try c.encode(pomodoroWorkMinutes, forKey: .pomodoroWorkMinutes)
        try c.encode(pomodoroBreakMinutes, forKey: .pomodoroBreakMinutes)
        try c.encode(pomodoroLongBreakMinutes, forKey: .pomodoroLongBreakMinutes)
        try c.encode(pomodoroRounds, forKey: .pomodoroRounds)
        try c.encodeIfPresent(breakLabel, forKey: .breakLabel)
        try c.encode(type, forKey: .type)
        try c.encode(typeDescriptor, forKey: .typeDescriptor)
    }

    static let builtInModes: [FocusMode] = [
        FocusMode(
            id: focusTimeID,
            name: "Focus Time",
            emoji: ":brain:",
            statusText: "In focus mode",
            durationMinutes: 25,
            enableMacOSDND: true,
            enableSlackDND: true,
            enablePomodoro: true,
            pomodoroWorkMinutes: 25,
            pomodoroBreakMinutes: 5,
            pomodoroLongBreakMinutes: 15,
            pomodoroRounds: 4,
            type: .focusTime
        ),
        FocusMode(
            id: meetingID,
            name: "Meeting",
            emoji: ":calendar:",
            statusText: "In a meeting",
            durationMinutes: 30,
            enableMacOSDND: false,
            enableSlackDND: false,
            enablePomodoro: false,
            pomodoroWorkMinutes: 30,
            pomodoroBreakMinutes: 5,
            pomodoroLongBreakMinutes: 15,
            pomodoroRounds: 1,
            type: .meeting
        ),
        FocusMode(
            id: inboxID,
            name: "Inbox",
            emoji: ":email:",
            statusText: "Clearing inbox",
            durationMinutes: 15,
            enableMacOSDND: false,
            enableSlackDND: false,
            enablePomodoro: false,
            pomodoroWorkMinutes: 15,
            pomodoroBreakMinutes: 5,
            pomodoroLongBreakMinutes: 15,
            pomodoroRounds: 1,
            type: .inbox
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

    private static func inferredType(from id: UUID) -> FocusModeType {
        switch id {
        case focusTimeID: return .focusTime
        case meetingID: return .meeting
        case inboxID: return .inbox
        default: return .custom
        }
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
            enableMacOSDND: enableMacOSDND,
            enableSlackDND: enableSlackDND,
            enablePomodoro: enableMacOSDND && enablePomodoro,
            pomodoroWorkMinutes: sanitizedPomodoroWorkMinutes,
            pomodoroBreakMinutes: sanitizedPomodoroBreakMinutes,
            pomodoroLongBreakMinutes: sanitizedPomodoroLongBreakMinutes,
            pomodoroRounds: sanitizedPomodoroRounds,
            breakLabel: breakLabel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? breakLabel?.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            type: type,
            typeDescriptor: typeDescriptor
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
    private static let diskDirectory = ".focally"
    private static let diskFilename = "modes.json"

    private static var diskURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(diskDirectory)
            .appendingPathComponent(diskFilename)
    }

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
            newMode = FocusMode(id: UUID(), name: newMode.name, emoji: newMode.emoji, statusText: newMode.statusText, durationMinutes: newMode.durationMinutes, enableMacOSDND: newMode.enableMacOSDND, enableSlackDND: newMode.enableSlackDND, enablePomodoro: newMode.enablePomodoro, pomodoroWorkMinutes: newMode.pomodoroWorkMinutes, pomodoroBreakMinutes: newMode.pomodoroBreakMinutes, pomodoroLongBreakMinutes: newMode.pomodoroLongBreakMinutes, pomodoroRounds: newMode.pomodoroRounds, breakLabel: newMode.breakLabel, typeDescriptor: newMode.typeDescriptor)
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

    static func typeDescriptor(forModeID id: UUID) -> FocusTypeDescriptor? {
        loadModes(from: .standard)
            .first(where: { $0.id == id })?
            .typeDescriptor
    }

    private func saveModes() {
        guard let data = try? JSONEncoder().encode(modes) else { return }
        defaults.set(data, forKey: FocusMode.defaultsKey)
        Self.saveToDisk(data)
    }

    private static func loadModes(from defaults: UserDefaults) -> [FocusMode] {
        // Priority: disk > UserDefaults > builtIn
        if let diskData = loadFromDisk(),
           let decoded = try? JSONDecoder().decode([FocusMode].self, from: diskData) {
            let modes = mergeWithBuiltIns(decoded)
            return orderedModes(from: modes)
        }

        guard let data = defaults.data(forKey: FocusMode.defaultsKey),
              let decoded = try? JSONDecoder().decode([FocusMode].self, from: data) else {
            return FocusMode.builtInModes
        }

        // Migrate from UserDefaults to disk
        if let data = try? JSONEncoder().encode(decoded) {
            saveToDisk(data)
        }

        let sanitized = decoded.map { $0.sanitized() }
        let merged = FocusMode.builtInModes.map { builtInMode in
            sanitized.first(where: { $0.id == builtInMode.id }) ?? builtInMode
        }
        return orderedModes(from: merged)
    }

    // MARK: - Disk persistence

    private static func saveToDisk(_ data: Data) {
        let fm = FileManager.default
        let dir = diskURL.deletingLastPathComponent()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // Write atomically
        let tmpURL = dir.appendingPathComponent("modes.json.tmp")
        try? data.write(to: tmpURL, options: .atomic)
        _ = try? fm.replaceItemAt(diskURL, withItemAt: tmpURL)
    }

    private static func loadFromDisk() -> Data? {
        try? Data(contentsOf: diskURL)
    }

    private static func mergeWithBuiltIns(_ decoded: [FocusMode]) -> [FocusMode] {
        let sanitized = decoded.map { $0.sanitized() }
        return FocusMode.builtInModes.map { builtInMode in
            sanitized.first(where: { $0.id == builtInMode.id }) ?? builtInMode
        } + sanitized.filter { !$0.isBuiltIn }
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
