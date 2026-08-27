import Foundation

enum StreakCalculator {
    /// 達成した日の一覧から、今日（まだ達成していなければ昨日）を起点に連続日数を数える。
    static func currentStreak(achievedDays: [Date], on date: Date, calendar: Calendar = .current) -> Int {
        let days = Set(achievedDays.map { AppDay.start(of: $0, calendar: calendar) })
        var cursor = AppDay.start(of: date, calendar: calendar)

        if !days.contains(cursor) {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = previousDay
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }
}
