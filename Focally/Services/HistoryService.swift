import Foundation
import os.log

class HistoryService: ObservableObject {
    static let shared = HistoryService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.focally.mac", category: "HistoryService")

    private let historyDirectory: URL = {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let focallyDir = supportDir.appendingPathComponent("Focally", isDirectory: true)
        let historyDir = focallyDir.appendingPathComponent("history", isDirectory: true)

        if !FileManager.default.fileExists(atPath: historyDir.path) {
            try? FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
        }

        return historyDir
    }()

    struct SessionEntry: Codable, Identifiable {
        let id: UUID
        let activity: String
        let emoji: String
        let durationMinutes: Int
        let startTime: Date
        let endTime: Date
        let round: Int

        var timeRange: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "\(formatter.string(from: startTime)) – \(formatter.string(from: endTime))"
        }
    }

    func recordWorkSession(
        activity: String,
        emoji: String,
        durationMinutes: Int,
        round: Int,
        startTime: Date = Date(),
        endTime: Date = Date()
    ) {
        let today = startTime
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: today)

        let historyFile = historyDirectory.appendingPathComponent("\(dateKey).json")

        var history: [SessionEntry] = []

        if let data = try? Data(contentsOf: historyFile),
           let decoded = try? JSONDecoder().decode([SessionEntry].self, from: data) {
            history = decoded
        }

        let entry = SessionEntry(
            id: UUID(),
            activity: activity,
            emoji: emoji,
            durationMinutes: durationMinutes,
            startTime: startTime,
            endTime: endTime,
            round: round
        )

        history.append(entry)

        if let encoded = try? JSONEncoder().encode(history) {
            do {
                try encoded.write(to: historyFile)
                logger.info("Recorded work session: \(activity, privacy: .public) (\(durationMinutes) min)")
            } catch {
                logger.error("Failed to write history: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func loadSessions(for date: Date = Date()) -> [SessionEntry] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: date)

        let historyFile = historyDirectory.appendingPathComponent("\(dateKey).json")

        guard let data = try? Data(contentsOf: historyFile),
              let decoded = try? JSONDecoder().decode([SessionEntry].self, from: data) else {
            return []
        }

        return decoded
    }

    func loadTodaySessions() -> [SessionEntry] {
        loadSessions(for: Date())
    }

    func totalFocusMinutesToday() -> Int {
        loadTodaySessions().reduce(0) { $0 + $1.durationMinutes }
    }

    func sessionCountToday() -> Int {
        loadTodaySessions().count
    }
}
