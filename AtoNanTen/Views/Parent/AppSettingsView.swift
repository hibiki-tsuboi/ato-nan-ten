import SwiftUI

struct AppSettingsView: View {
    @AppStorage(AppSettings.Key.requiresApproval) private var requiresApproval = true
    @AppStorage(AppSettings.Key.pendingNotification) private var isPendingNotificationEnabled = false
    @AppStorage(AppSettings.Key.dailyReminder) private var isDailyReminderEnabled = false
    @AppStorage(AppSettings.Key.dailyReminderHour) private var dailyReminderHour = AppSettings.defaultReminderHour
    @AppStorage("isResettingData") private var isResettingData = false
    @AppStorage(AppSettings.Key.colorScheme) private var colorSchemeOption = AppColorSchemeOption.system

    @State private var showsResetConfirmation = false
    @State private var notificationMessage: String?

    var body: some View {
        Form {
            Section {
                Picker("画面の見た目", selection: $colorSchemeOption) {
                    ForEach(AppColorSchemeOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("見た目")
            } footer: {
                Text("「自動」は端末の設定に合わせて、明るい場所ではライト、暗い場所ではダークになります。")
            }

            Section {
                Toggle("おうちの人の承認を必須にする", isOn: $requiresApproval)
            } header: {
                Text("承認")
            } footer: {
                Text(requiresApproval
                     ? "子どもが「できた！」を押すと承認待ちになり、承認するとポイントが入ります。"
                     : "承認なしで、「できた！」を押した時点でポイントが入ります。")
            }

            Section {
                Toggle("承認待ちを通知する", isOn: $isPendingNotificationEnabled)
                Toggle("毎日リマインドする", isOn: $isDailyReminderEnabled)

                if isDailyReminderEnabled {
                    Picker("時刻", selection: $dailyReminderHour) {
                        ForEach(6...22, id: \.self) { hour in
                            Text("\(hour):00").tag(hour)
                        }
                    }
                }
            } header: {
                Text("通知")
            } footer: {
                Text("承認待ちの通知は、\(Int(NotificationService.pendingApprovalDelay / 60))分たっても承認されていない申請だけをお知らせします。")
            }

            Section("アプリについて") {
                LabeledContent("バージョン", value: appVersion)
            }

            Section {
                Button("すべてのデータを削除", role: .destructive) {
                    showsResetConfirmation = true
                }
            } footer: {
                Text("子ども・ごほうび・行動・ポイント・履歴がすべて消え、最初の設定からやり直します。この操作は元に戻せません。")
            }
        }
        .navigationTitle("アプリの設定")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isPendingNotificationEnabled) { _, isEnabled in
            guard isEnabled else { return }
            authorizeNotifications { isGranted in
                if !isGranted { isPendingNotificationEnabled = false }
            }
        }
        .onChange(of: isDailyReminderEnabled) { _, isEnabled in
            guard isEnabled else {
                NotificationService.cancelDailyReminder()
                return
            }
            authorizeNotifications { isGranted in
                if isGranted {
                    NotificationService.scheduleDailyReminder(hour: dailyReminderHour)
                } else {
                    isDailyReminderEnabled = false
                }
            }
        }
        .onChange(of: dailyReminderHour) { _, hour in
            guard isDailyReminderEnabled else { return }
            NotificationService.scheduleDailyReminder(hour: hour)
        }
        .alert("すべてのデータを削除しますか？", isPresented: $showsResetConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("削除する", role: .destructive) { resetAllData() }
        } message: {
            Text("すべての記録が消えます。この操作は元に戻せません。")
        }
        .alert("通知を使えません", isPresented: Binding(
            get: { notificationMessage != nil },
            set: { if !$0 { notificationMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notificationMessage ?? "")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    private func authorizeNotifications(completion: @escaping (Bool) -> Void) {
        Task {
            let isGranted = await NotificationService.requestAuthorization()
            if !isGranted {
                notificationMessage = "iPhoneの「設定」＞「通知」から、このアプリの通知を許可してください。"
            }
            completion(isGranted)
        }
    }

    private func resetAllData() {
        NotificationService.cancelDailyReminder()
        isResettingData = true
    }
}
