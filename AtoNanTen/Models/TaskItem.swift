import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var childID: UUID?
    var title: String
    var emoji: String
    var points: Int
    var dailyLimit: Int?
    var isEnabled: Bool
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        childID: UUID? = nil,
        title: String,
        emoji: String,
        points: Int,
        dailyLimit: Int? = 1,
        isEnabled: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.childID = childID
        self.title = title
        self.emoji = emoji
        self.points = points
        self.dailyLimit = dailyLimit
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
    }
}
