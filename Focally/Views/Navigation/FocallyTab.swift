import SwiftUI

enum FocallyTab: CaseIterable, Identifiable {
    case timer
    case metrics
    case settings

    static let visibleTabs: [FocallyTab] = [.timer, .metrics, .settings]

    var id: String { localizationKey }

    var localizationKey: String {
        switch self {
        case .timer:
            return "tab_timer"
        case .metrics:
            return "tab_metrics"
        case .settings:
            return "tab_settings"
        }
    }

    var localizedLabel: String {
        AppLanguage.shared.localizedString(localizationKey)
    }

    var icon: String {
        switch self {
        case .timer:
            return "timer"
        case .metrics:
            return "chart.bar.fill"
        case .settings:
            return "gearshape"
        }
    }

    var activeIcon: String { icon }
}
