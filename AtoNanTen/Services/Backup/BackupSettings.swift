import Foundation

struct BackupSettings: Codable, Equatable {
    var requiresApproval: Bool
    var soundEnabled: Bool
    var pendingNotification: Bool
    var dailyReminder: Bool
    var dailyReminderHour: Int
    var colorScheme: String
    var selectedChildID: String
    var hasSeenParentModeHint: Bool
    var postponedAchievements: [String: Double]

    init(defaults: UserDefaults, goalIDs: Set<UUID>) {
        requiresApproval = defaults.object(forKey: AppSettings.Key.requiresApproval) as? Bool ?? true
        soundEnabled = defaults.object(forKey: AppSettings.Key.soundEnabled) as? Bool ?? true
        pendingNotification = defaults.bool(forKey: AppSettings.Key.pendingNotification)
        dailyReminder = defaults.bool(forKey: AppSettings.Key.dailyReminder)
        dailyReminderHour = defaults.object(forKey: AppSettings.Key.dailyReminderHour) as? Int
            ?? AppSettings.defaultReminderHour
        colorScheme = defaults.string(forKey: AppSettings.Key.colorScheme) ?? AppColorSchemeOption.system.rawValue
        selectedChildID = defaults.string(forKey: "selectedChildID") ?? ""
        hasSeenParentModeHint = defaults.bool(forKey: "hasSeenParentModeHint")
        postponedAchievements = [:]
        for id in goalIDs {
            if let day = defaults.object(forKey: "postponedAchievement-\(id.uuidString)") as? Double {
                postponedAchievements[id.uuidString] = day
            }
        }
    }

    /// Copy only app preferences. Authentication and in-progress operations belong to this device.
    func apply(to defaults: UserDefaults) {
        defaults.set(requiresApproval, forKey: AppSettings.Key.requiresApproval)
        defaults.set(soundEnabled, forKey: AppSettings.Key.soundEnabled)
        defaults.set(pendingNotification, forKey: AppSettings.Key.pendingNotification)
        defaults.set(dailyReminder, forKey: AppSettings.Key.dailyReminder)
        defaults.set(dailyReminderHour, forKey: AppSettings.Key.dailyReminderHour)
        defaults.set(colorScheme, forKey: AppSettings.Key.colorScheme)
        defaults.set(selectedChildID, forKey: "selectedChildID")
        defaults.set(hasSeenParentModeHint, forKey: "hasSeenParentModeHint")
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("postponedAchievement-") {
            defaults.removeObject(forKey: key)
        }
        for (id, day) in postponedAchievements {
            defaults.set(day, forKey: "postponedAchievement-\(id)")
        }
    }
}
