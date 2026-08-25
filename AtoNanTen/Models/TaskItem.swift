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
    var scheduledDate: Date?

    init(
        id: UUID = UUID(),
        childID: UUID? = nil,
        title: String,
        emoji: String,
        points: Int,
        dailyLimit: Int? = 1,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        scheduledDate: Date? = nil
    ) {
        self.id = id
        self.childID = childID
        self.title = title
        self.emoji = emoji
        self.points = points
        self.dailyLimit = dailyLimit
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.scheduledDate = scheduledDate
    }

    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let scheduledDate else { return false }
        return calendar.isDate(scheduledDate, inSameDayAs: date)
    }

    func setScheduled(_ isScheduled: Bool, on date: Date, calendar: Calendar = .current) {
        scheduledDate = isScheduled ? calendar.startOfDay(for: date) : nil
        isEnabled = isScheduled
    }
}
