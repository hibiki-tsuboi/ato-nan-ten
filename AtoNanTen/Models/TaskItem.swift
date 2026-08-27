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
    var weekdayMask: Int = TaskItem.everyWeekday

    static let everyWeekday = 0b1111111

    init(
        id: UUID = UUID(),
        childID: UUID? = nil,
        title: String,
        emoji: String,
        points: Int,
        dailyLimit: Int? = 1,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        scheduledDate: Date? = nil,
        weekdayMask: Int = TaskItem.everyWeekday
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
        self.weekdayMask = weekdayMask
    }

    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let scheduledDate else { return false }
        return AppDay.isSameDay(scheduledDate, date, calendar: calendar)
    }

    var isEveryWeekday: Bool {
        weekdayMask & TaskItem.everyWeekday == TaskItem.everyWeekday
    }

    func isWeekdayOn(_ weekday: Int) -> Bool {
        weekdayMask & (1 << (weekday - 1)) != 0
    }

    func setWeekday(_ weekday: Int, isOn: Bool) {
        let bit = 1 << (weekday - 1)
        if isOn {
            weekdayMask |= bit
        } else {
            weekdayMask &= ~bit
        }
    }

    func isActiveWeekday(on date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: AppDay.start(of: date, calendar: calendar))
        return isWeekdayOn(weekday)
    }

    func setEnabled(_ isEnabled: Bool, on date: Date, calendar: Calendar = .current) {
        self.isEnabled = isEnabled
        refreshSchedule(on: date, calendar: calendar)
    }

    /// 表示オンかつ今日が対象の曜日なら当日に繰り越す。変化があったら true。
    @discardableResult
    func refreshSchedule(on date: Date, calendar: Calendar = .current) -> Bool {
        let updated = isEnabled && isActiveWeekday(on: date, calendar: calendar)
            ? AppDay.start(of: date, calendar: calendar)
            : nil
        guard updated != scheduledDate else { return false }
        scheduledDate = updated
        return true
    }
}
