import SwiftUI

enum FocallyTab: CaseIterable, Identifiable {
    case timer
    case settings

    static let visibleTabs: [FocallyTab] = [.timer, .settings]

    var id: String { localizationKey }

    var localizationKey: String {
        switch self {
        case .timer:
            return "tab_timer"
        case .settings:
            return "tab_settings"
        }
    }

    var localizedLabel: String {
        String(localized: LocalizedStringResource(stringLiteral: localizationKey))
    }

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
