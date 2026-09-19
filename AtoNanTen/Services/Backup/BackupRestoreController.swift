import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BackupRestoreController {
    var pendingArchive: BackupArchive?
    var resultMessage: String?
    var didRestore = false

    func restore(in context: ModelContext) async {
        guard let archive = pendingArchive else { return }
        do {
            try BackupService.restore(archive, in: context)
            // データの復元完了を、端末の通知サービスの応答待ちにしない。
            Task { await NotificationService.restoreNotifications(from: archive) }
            didRestore = true
            resultMessage = "データをインポートしました。日付が変わっている場合、当日のポイントと承認待ちは通常どおり朝4時を基準にリセットされます。"
        } catch {
            didRestore = false
            resultMessage = "インポートできませんでした。元のデータは変更していません。\n\(error.localizedDescription)"
        }
        pendingArchive = nil
    }
}
