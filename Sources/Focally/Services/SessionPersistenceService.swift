import Foundation

@MainActor
protocol FocusSessionPersisting: AnyObject {
    func load() -> PersistedFocusSession?
    func save(_ snapshot: PersistedFocusSession)
    func clear()
}

@MainActor
final class SessionPersistenceService: FocusSessionPersisting {
    static let defaultFileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".focally", isDirectory: true)
        .appendingPathComponent("active_session.json")

    private let fileURL: URL
    private let fileManager: FileManager
    private let now: () -> Date

    init(fileURL: URL? = nil,
         fileManager: FileManager = .default,
         now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.fileManager = fileManager
        self.now = now
    }

    func load() -> PersistedFocusSession? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(PersistedFocusSession.self, from: data)
            guard snapshot.isValid(at: now()) else {
                clear()
                return nil
            }
            return snapshot
        } catch {
            clear()
            return nil
        }
    }

    func save(_ snapshot: PersistedFocusSession) {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
        } catch {
            // Persistence is best-effort; an I/O failure must not crash a focus session.
        }
    }

    func clear() {
        try? fileManager.removeItem(at: fileURL)
    }
}
