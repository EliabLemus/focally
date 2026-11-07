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
            // TASK-062: a corrupt/unreadable snapshot must not silently kill
            // session restoration. Quarantine the file for diagnostics and let
            // the next save() regenerate a fresh one.
            let corruptURL = fileURL.deletingLastPathComponent()
                .appendingPathComponent("active_session.corrupt-\(Int(now().timeIntervalSince1970)).json")
            try? fileManager.removeItem(at: corruptURL)
            try? fileManager.moveItem(at: fileURL, to: corruptURL)
            Logger.app.error(
                "Failed to load persisted focus session (\(error.localizedDescription)); quarantined to \(corruptURL.lastPathComponent)"
            )
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
            // Persistence is best-effort; an I/O failure must not crash a focus
            // session. TASK-062: surface it so disk-full/permission issues are
            // diagnosable instead of silently losing session state.
            Logger.app.error("Failed to persist focus session: \(error.localizedDescription)")
        }
    }

    func clear() {
        do {
            try fileManager.removeItem(at: fileURL)
        } catch where (error as NSError).code == NSFileNoSuchFileError {
            // (c) Silence justified: clearing an already-absent file is a no-op.
        } catch {
            // TASK-062: a failed clear leaves a stale snapshot behind that
            // would resurrect a dead session on next launch. Log best-effort.
            Logger.app.error("Failed to clear persisted focus session: \(error.localizedDescription)")
        }
    }
}
