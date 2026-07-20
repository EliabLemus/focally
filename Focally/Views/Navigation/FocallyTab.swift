import SwiftUI

enum FocallyTab: String, CaseIterable, Identifiable {
    case timer = "Timer"
    case settings = "Settings"

    static let visibleTabs: [FocallyTab] = [.timer, .settings]

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .timer:
            return "timer"
        case .settings:
            return "gearshape"
        }
    }

    var activeIcon: String { icon }
}
