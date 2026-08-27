import Foundation
import SwiftData

@Model
final class DailyAchievement {
    var id: UUID
    var childID: UUID?
    var goalID: UUID?
    var rewardTitle: String
    var rewardEmoji: String
    var earnedPoints: Int
    var targetPoints: Int
    var achievedOn: Date
    var achievedAt: Date

    init(
        id: UUID = UUID(),
        childID: UUID? = nil,
        goalID: UUID? = nil,
        rewardTitle: String,
        rewardEmoji: String,
        earnedPoints: Int,
        targetPoints: Int,
        achievedOn: Date,
        achievedAt: Date = .now
    ) {
        self.id = id
        self.childID = childID
        self.goalID = goalID
        self.rewardTitle = rewardTitle
        self.rewardEmoji = rewardEmoji
        self.earnedPoints = earnedPoints
        self.targetPoints = targetPoints
        self.achievedOn = achievedOn
        self.achievedAt = achievedAt
    }
}
