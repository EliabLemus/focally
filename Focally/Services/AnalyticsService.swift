import Foundation
import SwiftUI
import Observation

@Observable
final class AnalyticsService {
    enum TimeRange: String, CaseIterable {
        case weekly, monthly
    }

    var selectedRange: TimeRange = .weekly

    // MARK: - Mock Data

    struct ScoreData {
        let value: Int
        let delta: Int
        let description: String
    }

    struct TrendPoint: Identifiable {
        let id = UUID()
        let label: String
        let minutes: Int
    }

    struct Category: Identifiable {
        let id = UUID()
        let name: String
        let hours: Double
        let percentage: Int
        let color: Color
    }

    struct RecentSession: Identifiable {
        let id = UUID()
        let activity: String
        let category: String
        let date: Date
        let durationMinutes: Int
        let rating: Int // 0-5 stars
    }

    var focusScore: ScoreData {
        ScoreData(value: 94, delta: 5, description: "Above average focus time this week. Keep it up!")
    }

    var avgSessionDepth: (hours: Int, minutes: Int) {
        (2, 14)
    }

    var trendData: [TrendPoint] {
        let mins: [Int] = [120, 150, 90, 180, 120, 45, 60]
        let days: [String] = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        return zip(days, mins).map { TrendPoint(label: $0, minutes: $1) }
    }

    var categories: [Category] {
        [
            Category(name: "Development", hours: 12.5, percentage: 42, color: Color.focallyPrimary),
            Category(name: "Meetings", hours: 6.2, percentage: 21, color: Color.focallySecondary),
            Category(name: "Research", hours: 4.8, percentage: 16, color: Color.focallyTertiary),
            Category(name: "Planning", hours: 3.5, percentage: 12, color: Color.focallySurfaceContainerHigh)
        ]
    }

    var recentSessions: [RecentSession] {
        let cal = Calendar.current
        let today = Date()
        return [
            RecentSession(activity: "Deep Work — Focally", category: "Development", date: today, durationMinutes: 90, rating: 5),
            RecentSession(activity: "API Design Review", category: "Planning", date: cal.date(byAdding: .day, value: -1, to: today)!, durationMinutes: 45, rating: 4),
            RecentSession(activity: "Bug Triage", category: "Development", date: cal.date(byAdding: .day, value: -1, to: today)!, durationMinutes: 60, rating: 4),
            RecentSession(activity: "Documentation Sprint", category: "Research", date: cal.date(byAdding: .day, value: -2, to: today)!, durationMinutes: 75, rating: 3),
            RecentSession(activity: "Team Retrospective", category: "Meetings", date: cal.date(byAdding: .day, value: -2, to: today)!, durationMinutes: 30, rating: 3),
            RecentSession(activity: "Feature Implementation", category: "Development", date: cal.date(byAdding: .day, value: -3, to: today)!, durationMinutes: 120, rating: 5)
        ]
    }
}
