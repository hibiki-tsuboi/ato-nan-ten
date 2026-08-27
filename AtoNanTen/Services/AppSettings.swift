import Foundation

enum AppSettings {
    enum Key {
        static let requiresApproval = "requiresApproval"
        static let pendingNotification = "pendingNotificationEnabled"
        static let dailyReminder = "dailyReminderEnabled"
        static let dailyReminderHour = "dailyReminderHour"
    }

    static let defaultReminderHour = 19

    /// 未設定のときは承認ありをデフォルトにする
    static var requiresApproval: Bool {
        guard UserDefaults.standard.object(forKey: Key.requiresApproval) != nil else { return true }
        return UserDefaults.standard.bool(forKey: Key.requiresApproval)
    }

    static var isPendingNotificationEnabled: Bool {
        UserDefaults.standard.bool(forKey: Key.pendingNotification)
    }

    static var isDailyReminderEnabled: Bool {
        UserDefaults.standard.bool(forKey: Key.dailyReminder)
    }

    static var dailyReminderHour: Int {
        guard UserDefaults.standard.object(forKey: Key.dailyReminderHour) != nil else {
            return defaultReminderHour
        }
        return UserDefaults.standard.integer(forKey: Key.dailyReminderHour)
    }
}
