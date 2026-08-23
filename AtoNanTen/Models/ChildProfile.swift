import Foundation
import SwiftData

@Model
final class ChildProfile {
    var id: UUID
    var name: String
    var avatarEmoji: String
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        avatarEmoji: String,
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.avatarEmoji = avatarEmoji
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
