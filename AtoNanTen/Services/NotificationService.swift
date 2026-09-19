import Foundation
import UserNotifications

enum NotificationService {
    /// 承認されないまま放置された申請だけを通知したいので、少し待ってから鳴らす
    static let pendingApprovalDelay: TimeInterval = 300

    private static let dailyReminderIdentifier = "dailyReminder"
    private static let rewardTimerIdentifier = "rewardTimer"
    /// OS側の同期IPCが遅れても、画面操作やSwiftDataの保存を止めない。
    /// 予約と取り消しは同じキューで順序を保つ。
    private static let deliveryQueue = DispatchQueue(label: "jp.hibiki.gohobiplus.notifications", qos: .utility)

    static func requestAuthorization() async -> Bool {
        await Task.detached {
            let isGranted = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return isGranted ?? false
        }.value
    }

    static func schedulePendingApproval(requestID: UUID, childName: String, taskTitle: String) {
        guard AppSettings.isPendingNotificationEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "かくにん待ちがあります"
        content.body = "\(childName)の「\(taskTitle)」を承認してください。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: pendingApprovalDelay, repeats: false)
        enqueue(
            UNNotificationRequest(identifier: identifier(for: requestID), content: content, trigger: trigger)
        )
    }

    static func cancelPendingApproval(requestID: UUID) {
        removePending(identifiers: [identifier(for: requestID)])
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

        enqueue(
            UNNotificationRequest(
                identifier: dailyReminderIdentifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
        )
    }

    /// ごほうびの時間が終わったことを知らせる。すでに通知が許可されているときだけ予約する
    static func scheduleRewardTimerEnd(after seconds: TimeInterval, rewardTitle: String) {
        guard seconds > 0 else { return }

        Task {
            guard await authorizationStatus() == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "ごほうびの じかんが おわりました"
            content.body = "「\(rewardTitle)」はおしまいです。"
            content.sound = .default

            enqueue(
                UNNotificationRequest(
                    identifier: rewardTimerIdentifier,
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
                )
            )
        }
    }

    static func cancelRewardTimerEnd() {
        removePending(identifiers: [rewardTimerIdentifier])
    }

    static func cancelDailyReminder() {
        removePending(identifiers: [dailyReminderIdentifier])
    }

    /// Notification permissions and scheduled notifications are local to each iPhone.
    static func restoreNotifications(from archive: BackupArchive) async {
        deliveryQueue.async {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
        }
        if archive.settings.pendingNotification || archive.settings.dailyReminder {
            _ = await requestAuthorization()
        }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        if archive.settings.dailyReminder {
            scheduleDailyReminder(hour: archive.settings.dailyReminderHour)
        }
        for request in archive.requests where request.statusRawValue == CompletionStatus.pending.rawValue
            && AppDay.isSameDay(request.requestedAt, .now) {
            guard let child = archive.children.first(where: { $0.id == request.childID }) else { continue }
            schedulePendingApproval(requestID: request.id, childName: child.name, taskTitle: request.taskTitle)
        }
        if let goal = archive.goals.filter({ ($0.timerEndsAt ?? .distantPast) > .now })
            .min(by: { ($0.timerEndsAt ?? .distantPast) < ($1.timerEndsAt ?? .distantPast) }),
           let end = goal.timerEndsAt {
            scheduleRewardTimerEnd(after: end.timeIntervalSinceNow, rewardTitle: goal.title)
        }
    }

    private static func identifier(for requestID: UUID) -> String {
        "pendingApproval-\(requestID.uuidString)"
    }

    private static func enqueue(_ request: UNNotificationRequest) {
        deliveryQueue.async {
            UNUserNotificationCenter.current().add(request)
        }
    }

    private static func removePending(identifiers: [String]) {
        deliveryQueue.async {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    private static func authorizationStatus() async -> UNAuthorizationStatus {
        await Task.detached {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }.value
    }
}
