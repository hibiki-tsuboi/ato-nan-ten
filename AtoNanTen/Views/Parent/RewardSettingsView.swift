import SwiftData
import SwiftUI

struct RewardSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var goal: RewardGoal
    let date: Date

    @State private var title: String
    @State private var emoji: String
    @State private var targetPoints: Int
    @State private var durationMinutes: Int
    @State private var showsTargetWarning = false

    private let emojis = ["🎮", "🍦", "🍭", "📺", "🧸", "🚲", "🎨", "🎡"]

    init(goal: RewardGoal, date: Date) {
        self.goal = goal
        self.date = date
        _title = State(initialValue: goal.title)
        _emoji = State(initialValue: goal.emoji)
        _targetPoints = State(initialValue: goal.targetPoints)
        _durationMinutes = State(initialValue: goal.durationMinutes ?? RewardDuration.minutes(in: goal.title) ?? 0)
    }

    var body: some View {
        Form {
            Section("ごほうび名") {
                TextField("例：ゲーム 30分", text: $title)
            }

            Section("アイコン") {
                EmojiPicker(selection: $emoji, candidates: emojis)
            }

            Section {
                Picker("時間", selection: $durationMinutes) {
                    Text("なし").tag(0)
                    ForEach(RewardDuration.options, id: \.self) { minutes in
                        Text(RewardDuration.text(for: minutes)).tag(minutes)
                    }
                }
            } header: {
                Text("ごほうびの時間")
            } footer: {
                Text("時間を決めると、「ごほうびをもらった」を押したあとにタイマーが始まり、終わったら音とお知らせで教えます。")
            }

            Section {
                Stepper("\(targetPoints)点", value: $targetPoints, in: 1...99)
            } header: {
                Text("目標ポイント")
            } footer: {
                Text("今日は\(goal.currentPoints)点です。現在ポイント以下にすると、保存後すぐ達成になります。\nごほうびと目標ポイントは翌日以降も引き継がれ、ポイントだけ毎朝4時に0点へリセットされます。")
            }
        }
        .navigationTitle("ごほうびの設定")
        .onChange(of: title) { _, newTitle in
            guard goal.durationMinutes == nil, let suggested = RewardDuration.minutes(in: newTitle) else { return }
            durationMinutes = suggested
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    if targetPoints <= goal.currentPoints {
                        showsTargetWarning = true
                    } else {
                        save()
                    }
                }
                .fontWeight(.bold)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("すぐに目標達成になります", isPresented: $showsTargetWarning) {
            Button("キャンセル", role: .cancel) {}
            Button("保存する") { save() }
        } message: {
            Text("目標を\(targetPoints)点に変更しますか？")
        }
    }

    private func save() {
        goal.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        goal.emoji = emoji
        goal.targetPoints = targetPoints
        goal.durationMinutes = durationMinutes == 0 ? nil : durationMinutes
        goal.markConfigured(on: date)
        try? modelContext.save()
        dismiss()
    }
}
