import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \PointHistory.createdAt, order: .reverse) private var histories: [PointHistory]
    @Query(sort: \RewardRedemption.redeemedAt, order: .reverse) private var redemptions: [RewardRedemption]
    @Query private var achievements: [DailyAchievement]

    let child: ChildProfile
    let date: Date

    @State private var showsAllRedemptions = false

    private let redemptionPreviewCount = 3

    private var childHistories: [PointHistory] {
        histories.filter { $0.childID == child.id }
    }

    private var childRedemptions: [RewardRedemption] {
        redemptions.filter { $0.childID == child.id }
    }

    private var visibleRedemptions: [RewardRedemption] {
        showsAllRedemptions ? childRedemptions : Array(childRedemptions.prefix(redemptionPreviewCount))
    }

    private var childAchievements: [DailyAchievement] {
        achievements.filter { $0.childID == child.id }
    }

    private var achievedDays: Set<Date> {
        Set(childAchievements.map { AppDay.start(of: $0.achievedOn) })
    }

    private var streak: Int {
        StreakCalculator.currentStreak(achievedDays: childAchievements.map(\.achievedOn), on: date)
    }

    /// 直近7日ぶんを古い順に並べたもの
    private var recentDays: [Date] {
        let today = AppDay.start(of: date)
        return (0..<7).reversed().compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private var weeklyAchievedCount: Int {
        recentDays.filter { achievedDays.contains($0) }.count
    }

    private var weeklyPoints: Int {
        guard let start = recentDays.first else { return 0 }
        return childHistories
            .filter { $0.points > 0 && AppDay.start(of: $0.createdAt) >= start }
            .reduce(0) { $0 + $1.points }
    }

    private var groupedHistories: [(date: Date, entries: [PointHistory])] {
        let grouped = Dictionary(grouping: childHistories) {
            AppDay.start(of: $0.createdAt)
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
                    Section("この1週間") {
                        weeklySummary
                    }

                    if !childRedemptions.isEmpty {
                        Section("ごほうびを受け取った記録") {
                            ForEach(visibleRedemptions) { redemption in
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

                            if childRedemptions.count > redemptionPreviewCount {
                                Button(showsAllRedemptions ? "最近の\(redemptionPreviewCount)件だけ表示" : "すべて見る（\(childRedemptions.count)件）") {
                                    showsAllRedemptions.toggle()
                                }
                                .font(.subheadline.weight(.bold))
                            }
                        }
                    }

                    ForEach(groupedHistories, id: \.date) { group in
                        Section {
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
                        } header: {
                            HStack(spacing: 8) {
                                Text(group.date.formatted(
                                    .dateTime.year().month().day().weekday().locale(Locale(identifier: "ja_JP"))
                                ))
                                if achievedDays.contains(group.date) {
                                    Text("🎉 目標達成")
                                        .foregroundStyle(AppTheme.orange)
                                }
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

    private var weeklySummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("\(weeklyAchievedCount)日 達成", systemImage: "star.fill")
                    .foregroundStyle(AppTheme.orange)
                Spacer()
                Text("獲得 \(weeklyPoints)点")
                    .foregroundStyle(AppTheme.purple)
            }
            .font(.subheadline.weight(.bold))

            HStack(spacing: 6) {
                ForEach(recentDays, id: \.self) { day in
                    VStack(spacing: 6) {
                        Text(WeekdayFormatter.symbols[Calendar.current.component(.weekday, from: day) - 1])
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Image(systemName: achievedDays.contains(day) ? "star.fill" : "circle.dashed")
                            .font(.headline)
                            .foregroundStyle(achievedDays.contains(day) ? AppTheme.yellow : AppTheme.ink.opacity(0.22))
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }

            if streak >= 2 {
                Text("🔥 \(streak)日連続で達成中")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.orange)
            }
        }
        .padding(.vertical, 6)
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
