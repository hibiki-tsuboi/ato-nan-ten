import Foundation

/// アプリ上の「1日」。深夜0時ではなく朝4時で切り替える。
/// 夜遅くに押した「できた！」を、日付が変わったあとでもそのまま承認できるようにするため。
enum AppDay {
    static let startHour = 4

    /// その日時が属する1日の始まり（当日の朝4時）。
    static func start(of date: Date, calendar: Calendar = .current) -> Date {
        let offset = Double(startHour) * 3600
        return calendar.startOfDay(for: date.addingTimeInterval(-offset)).addingTimeInterval(offset)
    }

    /// 2つの日時が同じ1日に属するか。
    static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = .current) -> Bool {
        start(of: lhs, calendar: calendar) == start(of: rhs, calendar: calendar)
    }
}
