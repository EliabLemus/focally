import Foundation

/// A unified focus type, either built into Focally or created by the user.
enum FocusTypeDescriptor: Equatable, Codable, Hashable, Identifiable {
    case builtIn(FocusModeType)
    case custom(FocusType)

    var id: UUID {
        switch self {
        case .builtIn(let type):
            return type.id
        case .custom(let type):
            return type.id
        }
    }

    var name: String {
        switch self {
        case .builtIn(let type):
            return AppLanguage.shared.localizedString(type.localizedLabel)
        case .custom(let type):
            return type.name
        }
    }

    var emoji: String {
        switch self {
        case .builtIn:
            return ""
        case .custom(let type):
            return type.emoji
        }
    }

    var modeType: FocusModeType {
        switch self {
        case .builtIn(let type):
            return type
        case .custom:
            return .userCustom
        }
    }
}
