import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupTransferView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BackupRestoreController.self) private var restoreController
    var allowsExport = true

    @State private var exportDocument: BackupFileDocument?
    @State private var showsExporter = false
    @State private var showsImporter = false
    @State private var isReading = false
    @State private var preview: BackupArchive?
    @State private var showsConfirmation = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Text("古いiPhoneでデータを保存し、新しいiPhoneでそのファイルを読み込みます。")
                Text("子ども全員のプロフィール・ポイント・ごほうび・行動・承認待ち・履歴・アプリ設定が対象です。")
            }

            if allowsExport {
                Section {
                    Button(action: exportBackup) {
                        Label("データをエクスポート", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("1. 古いiPhoneで保存")
                } footer: {
                    Text("「ファイル」に保存してください。iCloud Driveを使うか、保存したファイルをAirDropなどで新しいiPhoneへ送れます。")
                }
            }

            Section {
                Button {
                    showsImporter = true
                } label: {
                    Label("データをインポート", systemImage: "square.and.arrow.down")
                }
                if isReading {
                    ProgressView("ファイルを確認しています…")
                }
            } header: {
                Text("2. 新しいiPhoneで読み込み")
            } footer: {
                Text("読み込み前に内容を確認できます。このiPhoneのデータは、バックアップの内容ですべて置き換わります。")
            }

            if let preview {
                Section("読み込むバックアップ") {
                    LabeledContent("保存日時", value: preview.exportedAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("子ども", value: "\(preview.children.count)人")
                    LabeledContent("行動", value: "\(preview.tasks.count)件")
                    LabeledContent("ポイント履歴", value: "\(preview.histories.count)件")
                    LabeledContent("達成記録", value: "\(preview.achievements.count)件")
                    Button("このデータで復元する", role: .destructive) {
                        showsConfirmation = true
                    }
                    Button("読み込みをキャンセル", role: .cancel) {
                        self.preview = nil
                    }
                }
            }

            Section {
                Text("親モードには新しいiPhoneのFace ID・端末パスコードを使います。アプリ内パスコードは引き継がれません。通知を使う場合は、このiPhoneでも許可が必要です。")
                Text("バックアップは暗号化されていません。子どもの名前や履歴が含まれるため、大切に保管してください。")
                Text("保存時点のデータを移す機能です。2台のiPhoneのデータが自動で同期されるわけではありません。")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .disabled(isReading)
        .navigationTitle("データの引き継ぎ")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showsExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "GohobiPlus-backup-\(Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash)))"
        ) { result in
            switch result {
            case .success:
                message = "バックアップを保存しました。新しいiPhoneでこのファイルをインポートしてください。"
            case .failure(let error):
                showError(error)
            }
            exportDocument = nil
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                readBackup(from: url)
            case .failure(let error):
                showError(error)
            }
        }
        .alert("このiPhoneのデータを置き換えますか？", isPresented: $showsConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("置き換えてインポート", role: .destructive) {
                restoreController.pendingArchive = preview
            }
        } message: {
            Text("現在のデータはすべて削除され、選んだバックアップの内容になります。残したいデータがある場合は、先にエクスポートしてください。")
        }
        .alert("データの引き継ぎ", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func exportBackup() {
        do {
            let archive = try BackupService.snapshot(in: modelContext)
            exportDocument = BackupFileDocument(data: try BackupService.encode(archive))
            showsExporter = true
        } catch {
            showError(error)
        }
    }

    private func readBackup(from url: URL) {
        preview = nil
        isReading = true
        Task {
            defer { isReading = false }
            do {
                let data = try await Task.detached {
                    try BackupFileReader.read(from: url)
                }.value
                preview = try BackupService.decode(data)
            } catch {
                showError(error)
            }
        }
    }

    private func showError(_ error: Error) {
        guard (error as NSError).code != NSUserCancelledError else { return }
        message = error.localizedDescription
    }
}

#Preview {
    NavigationStack {
        BackupTransferView()
    }
    .environment(BackupRestoreController())
    .modelContainer(for: [
        ChildProfile.self, RewardGoal.self, TaskItem.self, CompletionRequest.self,
        PointHistory.self, RewardRedemption.self, DailyAchievement.self
    ], inMemory: true)
}
