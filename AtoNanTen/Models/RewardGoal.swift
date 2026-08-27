import Foundation
import SwiftData

@Model
final class RewardGoal {
    var id: UUID
    var childID: UUID?
    var title: String
    var emoji: String
    var targetPoints: Int
    var currentPoints: Int
    var createdAt: Date
    var configuredDate: Date?

    init(
        id: UUID = UUID(),
        childID: UUID? = nil,
        title: String,
        emoji: String,
        targetPoints: Int,
        currentPoints: Int = 0,
        createdAt: Date = .now,
        configuredDate: Date? = Date.now
    ) {
        self.id = id
        self.childID = childID
        self.title = title
        self.emoji = emoji
        self.targetPoints = targetPoints
        self.currentPoints = currentPoints
        self.createdAt = createdAt
        self.configuredDate = configuredDate
    }

    var remainingPoints: Int {
        max(targetPoints - currentPoints, 0)
    }

    var isAchieved: Bool {
        currentPoints >= targetPoints
    }

    func isConfigured(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let configuredDate else { return false }
        return AppDay.isSameDay(configuredDate, date, calendar: calendar)
    }

    func markConfigured(on date: Date, calendar: Calendar = .current) {
        configuredDate = AppDay.start(of: date, calendar: calendar)
    }
}
