import SwiftData
import SwiftUI

struct PointAdjustmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var goal: RewardGoal

    @State private var adjustment = 0
    @State private var note = ""

    private var resultingPoints: Int {
        max(goal.currentPoints + adjustment, 0)
    }

    var body: some View {
        Form {
            Section("現在のポイント") {
                HStack {
                    Text("変更前")
                    Spacer()
                    Text("\(goal.currentPoints)点")
                        .font(.headline)
                }
                HStack {
                    Text("変更後")
                    Spacer()
                    Text("\(resultingPoints)点")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(AppTheme.purple)
                }
            }

            Section("増減") {
                Stepper(value: $adjustment, in: -99...99) {
                    HStack {
                        Text("修正値")
                        Spacer()
                        Text(adjustment > 0 ? "+\(adjustment)" : "\(adjustment)")
                            .font(.title3.monospacedDigit().weight(.bold))
                            .foregroundStyle(adjustment < 0 ? .red : AppTheme.mint)
                    }
                }

                HStack(spacing: 10) {
                    ForEach([-5, -1, 1, 5], id: \.self) { value in
                        Button(value > 0 ? "+\(value)" : "\(value)") {
                            adjustment = min(max(adjustment + value, -99), 99)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Section("メモ（任意）") {
                TextField("例：昨日の分を追加", text: $note)
            }
        }
        .navigationTitle("ポイント修正")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .fontWeight(.bold)
                    .disabled(adjustment == 0 || resultingPoints == goal.currentPoints)
            }
        }
    }

    private func save() {
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try? PointService.adjust(
            goal: goal,
            by: adjustment,
            note: cleanedNote,
            in: modelContext
        )
        dismiss()
    }
}
