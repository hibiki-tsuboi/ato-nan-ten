import Foundation
import SwiftData

enum PointHistoryType: String {
    case task
    case manualAdjustment
    case rewardReset
}

@Model
final class PointHistory {
    var id: UUID
    var childID: UUID?
    var title: String
    var points: Int
    var createdAt: Date
    var typeRawValue: String

    init(
        id: UUID = UUID(),
        childID: UUID? = nil,
        title: String,
        points: Int,
        createdAt: Date = .now,
        type: PointHistoryType
    ) {
        self.id = id
        self.childID = childID
        self.title = title
        self.points = points
        self.createdAt = createdAt
        self.typeRawValue = type.rawValue
    }
}
