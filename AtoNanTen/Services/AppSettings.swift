import Foundation
import SwiftUI

enum AppColorSchemeOption: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "自動"
        case .light: "ライト"
        case .dark: "ダーク"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppSettings {
    enum Key {
        static let requiresApproval = "requiresApproval"
        static let pendingNotification = "pendingNotificationEnabled"
        static let dailyReminder = "dailyReminderEnabled"
        static let dailyReminderHour = "dailyReminderHour"
        static let colorScheme = "appColorScheme"
        static let soundEnabled = "soundEnabled"
    }

    static let defaultReminderHour = 19

    /// 未設定のときは承認ありをデフォルトにする
    static var requiresApproval: Bool {
        guard UserDefaults.standard.object(forKey: Key.requiresApproval) != nil else { return true }
        return UserDefaults.standard.bool(forKey: Key.requiresApproval)
    }

    /// 未設定のときは音ありをデフォルトにする
    static var isSoundEnabled: Bool {
        guard UserDefaults.standard.object(forKey: Key.soundEnabled) != nil else { return true }
        return UserDefaults.standard.bool(forKey: Key.soundEnabled)
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
