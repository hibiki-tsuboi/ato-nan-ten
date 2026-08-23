import Foundation
import SwiftData

@Model
final class RewardRedemption {
    var id: UUID
    var childID: UUID?
    var rewardTitle: String
    var rewardEmoji: String
    var earnedPoints: Int
    var redeemedAt: Date

    init(
        id: UUID = UUID(),
        childID: UUID? = nil,
        rewardTitle: String,
        rewardEmoji: String,
        earnedPoints: Int,
        redeemedAt: Date = .now
    ) {
        self.id = id
        self.childID = childID
        self.rewardTitle = rewardTitle
        self.rewardEmoji = rewardEmoji
        self.earnedPoints = earnedPoints
        self.redeemedAt = redeemedAt
    }
}
