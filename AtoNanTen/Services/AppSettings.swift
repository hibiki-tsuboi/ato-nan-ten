import Foundation
import SwiftUI
import UIKit

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

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

/// preferredColorScheme は表示中のモーダルに反映されず、自動（nil）に戻しても
/// 直前の指定が解除されないため、ウィンドウへ直接適用する。
@MainActor
enum AppearanceController {
    static func apply(_ option: AppColorSchemeOption) {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.overrideUserInterfaceStyle = option.userInterfaceStyle }
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
