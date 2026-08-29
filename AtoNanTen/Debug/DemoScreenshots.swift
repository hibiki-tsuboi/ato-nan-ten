#if DEBUG

import SwiftData
import SwiftUI

/// App Store 用のスクリーンショットを撮るための表示モード。
///
/// `-demoScene <名前>` を起動引数に渡したときだけ有効になり、メモリ内のサンプルデータで
/// 指定した画面をいきなり表示する。端末に保存された本物のデータには触れない。
/// DEBUG ビルドにしか含まれないので、配布するアプリの動きは変わらない。
///
///     xcrun simctl launch <device> jp.hibiki.gohobiplus -demoScene home
enum DemoScene: String, CaseIterable {
    /// 子ども画面
    case home
    /// きょうだいの切り替えつきの子ども画面
    case siblings
    /// 目標を達成したお祝いの画面
    case achievement
    /// ごほうびタイマー
    case timer
    /// 親モードのホーム
    case parent
    /// 承認待ちの一覧
    case approval
    /// 行動の設定
    case tasks
    /// 履歴
    case history
}

/// 起動引数を読んで、デモ用のコンテナを一度だけ組み立てる。
struct DemoScreenshotMode {
    let scene: DemoScene
    let container: ModelContainer

    static let current: DemoScreenshotMode? = make()

    private static func make() -> DemoScreenshotMode? {
        let arguments = CommandLine.arguments
        guard let flagIndex = arguments.firstIndex(of: "-demoScene"),
              arguments.indices.contains(flagIndex + 1),
              let scene = DemoScene(rawValue: arguments[flagIndex + 1]) else {
            return nil
        }
        return DemoScreenshotMode(scene: scene, container: DemoData.makeContainer(for: scene))
    }
}

/// デモモードのときだけ差し込む画面。通常起動では素通しで `ContentView` を出す。
struct DemoScreenshotRoot: View {
    var body: some View {
        if let mode = DemoScreenshotMode.current {
            DemoSceneView(scene: mode.scene)
                .modelContainer(mode.container)
        } else {
            ContentView()
        }
    }
}

/// 子ども画面は状態から自動で決まるのでそのまま出し、親モードの下の階層だけ直接開く。
private struct DemoSceneView: View {
    @Query(sort: \ChildProfile.sortOrder) private var children: [ChildProfile]
    @Query(sort: \RewardGoal.createdAt) private var goals: [RewardGoal]

    let scene: DemoScene

    private var child: ChildProfile? { children.first }

    private var goal: RewardGoal? {
        guard let child else { return nil }
        return goals.first { $0.childID == child.id }
    }

    var body: some View {
        switch scene {
        case .home, .siblings, .achievement, .timer:
            ContentView()
        case .parent, .approval, .tasks, .history:
            if let child, let goal {
                parentScene(child: child, goal: goal)
            }
        }
    }

    @ViewBuilder
    private func parentScene(child: ChildProfile, goal: RewardGoal) -> some View {
        switch scene {
        case .parent:
            ParentHomeView(child: child, goal: goal, date: .now)
        case .approval:
            NavigationStack {
                ApprovalListView(child: child, goal: goal, date: .now)
            }
            .tint(AppTheme.purple)
        case .tasks:
            NavigationStack {
                TaskSettingsView(child: child, date: .now)
            }
            .tint(AppTheme.purple)
        default:
            NavigationStack {
                HistoryView(child: child, date: .now)
            }
            .tint(AppTheme.purple)
        }
    }
}

/// スクリーンショット用のサンプルデータ。実在する商品名や塾名は使わない。
enum DemoData {
    static func makeContainer(for scene: DemoScene) -> ModelContainer {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: ChildProfile.self,
                RewardGoal.self,
                TaskItem.self,
                CompletionRequest.self,
                PointHistory.self,
                RewardRedemption.self,
                DailyAchievement.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("デモ用のデータを準備できませんでした: \(error)")
        }

        seed(scene, into: container.mainContext)
        return container
    }

    private static func seed(_ scene: DemoScene, into context: ModelContext) {
        let now = Date.now
        let today = AppDay.start(of: now)

        let child = ChildProfile(name: "はると", avatarEmoji: "🦁", sortOrder: 0)
        context.insert(child)

        let goal = RewardGoal(
            childID: child.id,
            title: "ゲーム 30ぷん",
            emoji: "🎮",
            targetPoints: 5,
            currentPoints: 0,
            durationMinutes: 30
        )
        goal.markConfigured(on: now)
        context.insert(goal)

        if scene == .siblings {
            addSiblings(context: context, now: now)
        }

        let tasks = addTasks(for: child, scene: scene, context: context, now: now)
        addPastRecords(child: child, goal: goal, context: context, today: today)
        addToday(scene: scene, goal: goal, tasks: tasks, context: context, today: today, now: now)

        applyDefaults(selecting: child)
        try? context.save()
    }

    // MARK: - 子ども

    private static func addSiblings(context: ModelContext, now: Date) {
        let siblings = [
            (name: "さくら", emoji: "🐰", reward: "アイス", rewardEmoji: "🍦", target: 5, points: 4),
            (name: "みなと", emoji: "🐧", reward: "こうえんで あそぶ", rewardEmoji: "🏞️", target: 8, points: 5)
        ]

        for (index, sibling) in siblings.enumerated() {
            let profile = ChildProfile(
                name: sibling.name,
                avatarEmoji: sibling.emoji,
                sortOrder: index + 1
            )
            context.insert(profile)

            let goal = RewardGoal(
                childID: profile.id,
                title: sibling.reward,
                emoji: sibling.rewardEmoji,
                targetPoints: sibling.target,
                currentPoints: sibling.points
            )
            goal.markConfigured(on: now)
            context.insert(goal)
        }
    }

    // MARK: - 行動

    private static func addTasks(
        for child: ChildProfile,
        scene: DemoScene,
        context: ModelContext,
        now: Date
    ) -> [String: TaskItem] {
        var definitions: [(title: String, emoji: String, limit: Int?, weekdays: [Int], isEnabled: Bool)] = [
            ("しゅくだい", "📚", 1, [], true),
            ("おてつだい", "🧹", nil, [], true),
            ("はみがき", "🪥", 2, [], true),
            ("どくしょ", "📖", 1, [], true),
            ("かたづけ", "🧸", 1, [], true)
        ]

        // 設定画面では、曜日ごとの出し分けと非表示の見え方も見せる
        if scene == .tasks {
            definitions[0].weekdays = [2, 3, 4, 5, 6]
            definitions += [
                ("おふろそうじ", "🛁", 1, [1, 7], true),
                ("なわとび", "🪢", 1, [], false)
            ]
        }

        var tasks: [String: TaskItem] = [:]
        for (index, definition) in definitions.enumerated() {
            let task = TaskItem(
                childID: child.id,
                title: definition.title,
                emoji: definition.emoji,
                points: 1,
                dailyLimit: definition.limit,
                isEnabled: definition.isEnabled,
                sortOrder: index,
                weekdayMask: weekdayMask(definition.weekdays)
            )
            task.refreshSchedule(on: now)
            context.insert(task)
            tasks[definition.title] = task
        }
        return tasks
    }

    private static func weekdayMask(_ weekdays: [Int]) -> Int {
        guard !weekdays.isEmpty else { return TaskItem.everyWeekday }
        return weekdays.reduce(0) { $0 | (1 << ($1 - 1)) }
    }

    // MARK: - きょうの状態

    private static func addToday(
        scene: DemoScene,
        goal: RewardGoal,
        tasks: [String: TaskItem],
        context: ModelContext,
        today: Date,
        now: Date
    ) {
        switch scene {
        case .home, .siblings, .parent, .tasks, .history:
            approve(tasks["はみがき"], at: time(7, 30, today: today), goal: goal, context: context)
            approve(tasks["どくしょ"], at: time(8, 20, today: today), goal: goal, context: context)
            approve(tasks["かたづけ"], at: time(9, 5, today: today), goal: goal, context: context)
            request(tasks["おてつだい"], at: time(9, 30, today: today), context: context)
            if scene == .parent {
                request(tasks["しゅくだい"], at: time(9, 38, today: today), context: context)
            }

        case .approval:
            request(tasks["はみがき"], at: time(7, 35, today: today), context: context)
            request(tasks["かたづけ"], at: time(8, 40, today: today), context: context)
            request(tasks["おてつだい"], at: time(9, 12, today: today), context: context)
            request(tasks["しゅくだい"], at: time(9, 26, today: today), context: context)
            request(tasks["どくしょ"], at: time(9, 38, today: today), context: context)

        case .achievement:
            approve(tasks["はみがき"], at: time(7, 30, today: today), goal: goal, context: context)
            approve(tasks["どくしょ"], at: time(8, 20, today: today), goal: goal, context: context)
            approve(tasks["かたづけ"], at: time(9, 5, today: today), goal: goal, context: context)
            approve(tasks["おてつだい"], at: time(9, 20, today: today), goal: goal, context: context)
            approve(tasks["しゅくだい"], at: time(9, 36, today: today), goal: goal, context: context)
            context.insert(DailyAchievement(
                childID: goal.childID,
                goalID: goal.id,
                rewardTitle: goal.title,
                rewardEmoji: goal.emoji,
                earnedPoints: goal.currentPoints,
                targetPoints: goal.targetPoints,
                achievedOn: today,
                achievedAt: time(9, 36, today: today)
            ))

        case .timer:
            // 受け取り直後。ポイントは0に戻り、タイマーだけが動いている
            goal.timerEndsAt = now.addingTimeInterval(18 * 60 + 25)
        }
    }

    private static func approve(
        _ task: TaskItem?,
        at date: Date,
        goal: RewardGoal,
        context: ModelContext
    ) {
        guard let task else { return }

        context.insert(CompletionRequest(
            childID: task.childID,
            taskID: task.id,
            taskTitle: task.title,
            taskEmoji: task.emoji,
            points: task.points,
            requestedAt: date,
            status: .approved
        ))
        context.insert(PointHistory(
            childID: task.childID,
            title: task.title,
            points: task.points,
            createdAt: date,
            type: .task
        ))
        goal.currentPoints += task.points
    }

    private static func request(_ task: TaskItem?, at date: Date, context: ModelContext) {
        guard let task else { return }

        context.insert(CompletionRequest(
            childID: task.childID,
            taskID: task.id,
            taskTitle: task.title,
            taskEmoji: task.emoji,
            points: task.points,
            requestedAt: date,
            status: .pending
        ))
    }

    // MARK: - これまでの記録

    /// 連続達成の表示と履歴のために、数日ぶんの記録をさかのぼって入れる
    private static func addPastRecords(
        child: ChildProfile,
        goal: RewardGoal,
        context: ModelContext,
        today: Date
    ) {
        let pastDays = [1, 2, 3, 5]

        for daysAgo in pastDays {
            let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let entries = [
                ("はみがき", 7, 25), ("しゅくだい", 17, 10), ("どくしょ", 18, 5),
                ("おてつだい", 18, 40), ("かたづけ", 19, 15)
            ]

            for entry in entries {
                context.insert(PointHistory(
                    childID: child.id,
                    title: entry.0,
                    points: 1,
                    createdAt: time(entry.1, entry.2, daysAgo: daysAgo, today: today),
                    type: .task
                ))
            }

            context.insert(DailyAchievement(
                childID: child.id,
                goalID: goal.id,
                rewardTitle: goal.title,
                rewardEmoji: goal.emoji,
                earnedPoints: 5,
                targetPoints: 5,
                achievedOn: day,
                achievedAt: time(19, 20, daysAgo: daysAgo, today: today)
            ))
            context.insert(RewardRedemption(
                childID: child.id,
                rewardTitle: goal.title,
                rewardEmoji: goal.emoji,
                earnedPoints: 5,
                redeemedAt: time(19, 30, daysAgo: daysAgo, today: today)
            ))
            context.insert(PointHistory(
                childID: child.id,
                title: "ごほうびを受け取りました",
                points: -5,
                createdAt: time(19, 30, daysAgo: daysAgo, today: today),
                type: .rewardReset
            ))
        }

        context.insert(PointHistory(
            childID: child.id,
            title: "おてつだい スペシャル",
            points: 2,
            createdAt: time(20, 10, daysAgo: 2, today: today),
            type: .manualAdjustment
        ))
    }

    // MARK: - 補助

    /// 「1日」は朝4時始まりなので、その日の4時からの経過時間で時刻を組み立てる
    private static func time(_ hour: Int, _ minute: Int, daysAgo: Int = 0, today: Date) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        return day.addingTimeInterval(TimeInterval((hour - AppDay.startHour) * 3600 + minute * 60))
    }

    private static func applyDefaults(selecting child: ChildProfile) {
        let defaults = UserDefaults.standard
        defaults.set(child.id.uuidString, forKey: "selectedChildID")
        defaults.set(true, forKey: "hasSeenParentModeHint")
        defaults.set(false, forKey: "isResettingData")
        defaults.set(true, forKey: AppSettings.Key.requiresApproval)
        defaults.set(false, forKey: AppSettings.Key.soundEnabled)
        defaults.set(AppColorSchemeOption.system.rawValue, forKey: AppSettings.Key.colorScheme)
    }
}

#endif
