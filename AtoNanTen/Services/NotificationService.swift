import Foundation
import UserNotifications

enum NotificationService {
    /// 承認されないまま放置された申請だけを通知したいので、少し待ってから鳴らす
    static let pendingApprovalDelay: TimeInterval = 300

    private static let dailyReminderIdentifier = "dailyReminder"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let isGranted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return isGranted ?? false
    }

    static func schedulePendingApproval(requestID: UUID, childName: String, taskTitle: String) {
        guard AppSettings.isPendingNotificationEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "かくにん待ちがあります"
        content.body = "\(childName)の「\(taskTitle)」を承認してください。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: pendingApprovalDelay, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier(for: requestID), content: content, trigger: trigger)
        )
    }

    static func cancelPendingApproval(requestID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier(for: requestID)]
        )
    }

    static func scheduleDailyReminder(hour: Int) {
        cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = "きょうのチャレンジ"
        content.body = "やることが のこっていないか チェックしよう！"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = 0

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: dailyReminderIdentifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
        )
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [dailyReminderIdentifier]
        )
    }

    private static func identifier(for requestID: UUID) -> String {
        "pendingApproval-\(requestID.uuidString)"
    }
}
