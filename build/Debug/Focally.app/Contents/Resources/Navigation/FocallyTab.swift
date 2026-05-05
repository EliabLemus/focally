import SwiftUI

enum FocallyTab: String, CaseIterable, Identifiable {
    case timer = "Timer"
    case tasks = "Tasks"
    case schedule = "Schedule"
    case analytics = "Analytics"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .timer: return "timer"
        case .tasks: return "checklist"
        case .schedule: return "calendar"
        case .analytics: return "chart.bar.fill"
        case .settings: return "gearshape"
        }
    }

    var activeIcon: String {
        switch self {
        case .timer: return "timer"
        case .tasks: return "checklist"
        case .schedule: return "calendar"
        case .analytics: return "chart.bar.fill"
        case .settings: return "gearshape"
        }
    }
}
