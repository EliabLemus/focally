import Foundation

/// A user-defined category for focus modes.
struct FocusType: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var emoji: String
    var color: String

    init(id: UUID = UUID(), name: String, emoji: String, color: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
    }
}
