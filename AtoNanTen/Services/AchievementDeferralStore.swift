import Foundation

/// 「あとでもらう」を選んだ達成を、その日はもう自動で出さないようにするための記録。
enum AchievementDeferralStore {
    static func isPostponed(goalID: UUID, on date: Date) -> Bool {
        guard let postponedDay = UserDefaults.standard.object(forKey: key(for: goalID)) as? Double else {
            return false
        }
        return postponedDay == AppDay.start(of: date).timeIntervalSinceReferenceDate
    }

    static func postpone(goalID: UUID, on date: Date) {
        UserDefaults.standard.set(
            AppDay.start(of: date).timeIntervalSinceReferenceDate,
            forKey: key(for: goalID)
        )
    }

    static func clear(goalID: UUID) {
        UserDefaults.standard.removeObject(forKey: key(for: goalID))
    }

    private static func key(for goalID: UUID) -> String {
        "postponedAchievement-\(goalID.uuidString)"
    }
}
