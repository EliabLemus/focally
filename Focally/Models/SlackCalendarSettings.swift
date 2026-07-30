import Foundation

/// Slack behavior for the independent calendar channel.
struct SlackCalendarSettings: Codable, Equatable {
    var showCalendarInSlack = false
    var titleDisplay: CalendarTitleDisplay = .hideTitle
    var useEventEmojisForStatus = false
    var activateDNDForVideoCalls = false
}

enum CalendarTitleDisplay: String, Codable, CaseIterable {
    case showFullTitle
    case showVideoCallOnly
    case hideTitle

    var displayName: String {
        switch self {
        case .showFullTitle:
            return AppLanguage.shared.localizedString("calendar_show_full_title")
        case .showVideoCallOnly:
            return AppLanguage.shared.localizedString("calendar_show_video_call_only")
        case .hideTitle:
            return AppLanguage.shared.localizedString("calendar_hide_title")
        }
    }
}
