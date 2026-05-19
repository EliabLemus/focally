import Foundation
import Combine

final class ScheduleService: ObservableObject {
    @Published var focusBlocks: [FocusBlock] = []
    @Published var currentWeekStart: Date = Date()

    func loadWeek() {
        focusBlocks = Self.mockBlocks()
    }

    static func mockBlocks() -> [FocusBlock] {
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)

        return [
            FocusBlock(
                title: "Deep Work — Focally",
                startDate: cal.date(bySettingHour: 9, minute: 0, second: 0, of: today)!,
                endDate: cal.date(bySettingHour: 10, minute: 30, second: 0, of: today)!,
                color: .primary,
                isCurrentSession: true
            ),
            FocusBlock(
                title: "Team Standup",
                startDate: cal.date(bySettingHour: 11, minute: 0, second: 0, of: today)!,
                endDate: cal.date(bySettingHour: 11, minute: 30, second: 0, of: today)!,
                color: .tertiary
            ),
            FocusBlock(
                title: "Code Review",
                startDate: cal.date(bySettingHour: 14, minute: 0, second: 0, of: today)!,
                endDate: cal.date(bySettingHour: 15, minute: 0, second: 0, of: today)!,
                color: .secondary
            )
        ]
    }
}
