import SwiftData
import SwiftUI

struct ParentHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CompletionRequest.requestedAt, order: .reverse) private var requests: [CompletionRequest]
    let child: ChildProfile
    @Bindable var goal: RewardGoal
    let date: Date

    private var pendingCount: Int {
        requests.filter {
            $0.childID == child.id &&
                $0.status == .pending &&
                AppDay.isSameDay($0.requestedAt, date)
        }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        summaryCard

                        if pendingCount > 0 {
                            NavigationLink {
                                ApprovalListView(child: child, goal: goal, date: date)
                            } label: {
                                HStack(spacing: 15) {
                                    Image(systemName: "bell.badge.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                        .frame(width: 50, height: 50)
                                        .background(AppTheme.orange, in: Circle())
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("承認待ちを確認")
                                            .font(.headline)
                                        Text("\(pendingCount)件あります")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .foregroundStyle(AppTheme.ink)
                                .appCard()
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(spacing: 1) {
                            if pendingCount == 0 {
                                ParentMenuLink(
                                    title: "承認待ち",
                                    subtitle: "現在ありません",
                                    systemName: "checkmark.seal.fill",
                                    color: AppTheme.orange
                                ) {
                                    ApprovalListView(child: child, goal: goal, date: date)
                                }

                                Divider().padding(.leading, 66)
                            }

                            ParentMenuLink(
                                title: "行動を設定",
                                subtitle: "表示する行動を選択・追加",
                                systemName: "list.bullet.clipboard.fill",
                                color: AppTheme.mint
                            ) {
                                TaskSettingsView(child: child, date: date)
                            }

                            Divider().padding(.leading, 66)

                            ParentMenuLink(
                                title: "ごほうびを設定",
                                subtitle: "内容・目標ポイント",
                                systemName: "gift.fill",
                                color: AppTheme.purple
                            ) {
                                RewardSettingsView(goal: goal, date: date)
                            }

                            Divider().padding(.leading, 66)

                            ParentMenuLink(
                                title: "ポイントを修正",
                                subtitle: "増減を履歴に記録",
                                systemName: "plusminus.circle.fill",
                                color: .blue
                            ) {
                                PointAdjustmentView(goal: goal)
                            }

                            Divider().padding(.leading, 66)

                            ParentMenuLink(
                                title: "子どもを管理",
                                subtitle: "追加・名前・アイコン",
                                systemName: "person.2.fill",
                                color: .teal
                            ) {
                                ChildrenSettingsView()
                            }

                            Divider().padding(.leading, 66)

                            ParentMenuLink(
                                title: "履歴を見る",
                                subtitle: "ポイントと達成の記録",
                                systemName: "clock.fill",
                                color: .pink
                            ) {
                                HistoryView(child: child, date: date)
                            }

                            Divider().padding(.leading, 66)

                            ParentMenuLink(
                                title: "アプリの設定",
                                subtitle: "承認・通知・データ",
                                systemName: "gearshape.fill",
                                color: .gray
                            ) {
                                AppSettingsView()
                            }
                        }
                        .background(.background, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .padding(18)
                    .appContentWidth()
                }
            }
            .navigationTitle("親モード")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
        .tint(AppTheme.purple)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(child.avatarEmoji) \(child.name)")
                .font(.title3.weight(.heavy))
                .foregroundStyle(AppTheme.ink)
            HStack {
                Text("今日のチャレンジ")
                    .font(.headline)
                Spacer()
                Text("\(goal.currentPoints) / \(goal.targetPoints)点")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(AppTheme.purple)
            }

            ProgressView(value: min(Double(goal.currentPoints) / Double(max(goal.targetPoints, 1)), 1))
                .tint(AppTheme.orange)

            HStack(spacing: 12) {
                Text(goal.emoji).font(.system(size: 36))
                VStack(alignment: .leading, spacing: 2) {
                    Text("ごほうび")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(goal.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                }
            }
        }
        .appCard()
    }
}

private struct ParentMenuLink<Destination: View>: View {
    let title: String
    let subtitle: String
    let systemName: String
    let color: Color
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: systemName)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(color, in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
