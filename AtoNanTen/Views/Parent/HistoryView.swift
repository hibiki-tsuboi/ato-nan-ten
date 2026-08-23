import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \PointHistory.createdAt, order: .reverse) private var histories: [PointHistory]
    @Query(sort: \RewardRedemption.redeemedAt, order: .reverse) private var redemptions: [RewardRedemption]
    let child: ChildProfile

    private var childHistories: [PointHistory] {
        histories.filter { $0.childID == child.id }
    }

    private var childRedemptions: [RewardRedemption] {
        redemptions.filter { $0.childID == child.id }
    }

    private var groupedHistories: [(date: Date, entries: [PointHistory])] {
        let grouped = Dictionary(grouping: childHistories) {
            Calendar.current.startOfDay(for: $0.createdAt)
        }
        return grouped
            .map { (date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if childHistories.isEmpty && childRedemptions.isEmpty {
                ContentUnavailableView(
                    "履歴はまだありません",
                    systemImage: "clock",
                    description: Text("承認やポイント修正の記録がここに残ります。")
                )
            } else {
                List {
                    if !childRedemptions.isEmpty {
                        Section("ごほうび達成") {
                            ForEach(childRedemptions) { redemption in
                                HStack(spacing: 12) {
                                    Text(redemption.rewardEmoji).font(.title)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(redemption.rewardTitle).font(.headline)
                                        Text(redemption.redeemedAt.formatted(
                                            .dateTime.year().month().day().hour().minute().locale(Locale(identifier: "ja_JP"))
                                        ))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(redemption.earnedPoints)点")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(AppTheme.purple)
                                }
                            }
                        }
                    }

                    ForEach(groupedHistories, id: \.date) { group in
                        Section(group.date.formatted(
                            .dateTime.year().month().day().weekday().locale(Locale(identifier: "ja_JP"))
                        )) {
                            ForEach(group.entries) { history in
                                HStack(spacing: 12) {
                                    Image(systemName: icon(for: history))
                                        .foregroundStyle(color(for: history))
                                        .frame(width: 26)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(history.title)
                                            .font(.body.weight(.medium))
                                        Text(history.createdAt.formatted(
                                            .dateTime.hour().minute().locale(Locale(identifier: "ja_JP"))
                                        ))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(history.points > 0 ? "+\(history.points)" : "\(history.points)")
                                        .font(.headline.monospacedDigit())
                                        .foregroundStyle(history.points >= 0 ? AppTheme.mint : .red)
                                }
                            }

                            HStack {
                                Text("この日の合計")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(signedTotal(group.entries.reduce(0) { $0 + $1.points }))
                                    .font(.caption.monospacedDigit().weight(.bold))
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("履歴")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func icon(for history: PointHistory) -> String {
        switch PointHistoryType(rawValue: history.typeRawValue) {
        case .task: "star.fill"
        case .manualAdjustment: "plusminus.circle.fill"
        case .rewardReset: "gift.fill"
        case nil: "circle.fill"
        }
    }

    private func color(for history: PointHistory) -> Color {
        switch PointHistoryType(rawValue: history.typeRawValue) {
        case .task: AppTheme.yellow
        case .manualAdjustment: .blue
        case .rewardReset: AppTheme.purple
        case nil: .secondary
        }
    }

    private func signedTotal(_ value: Int) -> String {
        value > 0 ? "+\(value)点" : "\(value)点"
    }
}
