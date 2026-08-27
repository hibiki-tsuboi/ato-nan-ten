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
    @State private var showsTargetWarning = false

    private let emojis = ["🎮", "🍦", "🍭", "📺", "🧸", "🚲", "🎨", "🎡"]

    init(goal: RewardGoal, date: Date) {
        self.goal = goal
        self.date = date
        _title = State(initialValue: goal.title)
        _emoji = State(initialValue: goal.emoji)
        _targetPoints = State(initialValue: goal.targetPoints)
    }

    var body: some View {
        Form {
            Section("ごほうび名") {
                TextField("例：ゲーム 30分", text: $title)
            }

            Section("アイコン") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(emojis, id: \.self) { candidate in
                        Button {
                            emoji = candidate
                        } label: {
                            Text(candidate)
                                .font(.system(size: 34))
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(emoji == candidate ? AppTheme.yellow.opacity(0.3) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
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
        goal.markConfigured(on: date)
        try? modelContext.save()
        dismiss()
    }
}
