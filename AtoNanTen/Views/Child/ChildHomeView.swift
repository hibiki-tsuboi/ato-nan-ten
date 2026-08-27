import SwiftData
import SwiftUI

struct ChildHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @Query(sort: \CompletionRequest.requestedAt, order: .reverse) private var requests: [CompletionRequest]
    @Query private var achievements: [DailyAchievement]

    let child: ChildProfile
    @Bindable var goal: RewardGoal
    let siblings: [ChildProfile]
    let date: Date
    let onSelectChild: (ChildProfile) -> Void
    @State private var presentedScreen: ChildModalScreen?
    @State private var queuedScreen: ChildModalScreen?
    @State private var isAuthenticating = false
    @State private var authenticationMessage: String?
    @State private var showsParentModeHint = false
    @ScaledMetric(relativeTo: .largeTitle) private var remainingPointsSize: CGFloat = 70
    @AppStorage("hasSeenParentModeHint") private var hasSeenParentModeHint = false
    @AppStorage(AppSettings.Key.requiresApproval) private var requiresApproval = true
    @State private var completionCount = 0

    init(
        child: ChildProfile,
        goal: RewardGoal,
        siblings: [ChildProfile],
        date: Date,
        onSelectChild: @escaping (ChildProfile) -> Void
    ) {
        self.child = child
        self.goal = goal
        self.siblings = siblings
        self.date = date
        self.onSelectChild = onSelectChild
        let isAchievedToday = goal.isConfigured(on: date) && goal.isAchieved
        let isPostponed = AchievementDeferralStore.isPostponed(goalID: goal.id, on: date)

        if goal.isTimerRunning() {
            _presentedScreen = State(initialValue: .timer)
        } else {
            _presentedScreen = State(initialValue: isAchievedToday && !isPostponed ? .achievement : nil)
        }
    }

    private var todayTasks: [TaskItem] {
        tasks.filter { $0.childID == child.id && $0.isScheduled(on: date) }
    }

    private var childRequests: [CompletionRequest] {
        requests.filter {
            $0.childID == child.id && AppDay.isSameDay($0.requestedAt, date)
        }
    }

    private var isConfiguredToday: Bool {
        goal.isConfigured(on: date)
    }

    private var isAchievementPostponed: Bool {
        AchievementDeferralStore.isPostponed(goalID: goal.id, on: date)
    }

    private var isParentModeHintVisible: Bool {
        showsParentModeHint || !hasSeenParentModeHint
    }

    private var streak: Int {
        StreakCalculator.currentStreak(
            achievedDays: achievements.filter { $0.childID == child.id }.map(\.achievedOn),
            on: date
        )
    }

    private var pendingCount: Int {
        childRequests.filter { $0.status == .pending }.count
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 18) {
                    header

                    if isParentModeHintVisible {
                        parentModeHint
                    }

                    if siblings.count > 1 {
                        childSwitcher
                    }

                    if isConfiguredToday {
                        progressCard

                        if goal.isAchieved {
                            pendingRewardCard
                        }

                        if pendingCount > 0 {
                            pendingBanner
                        }

                        if todayTasks.isEmpty {
                            noTasksCard
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("きょうも がんばろう！")
                                    .font(.title3.weight(.heavy))
                                    .foregroundStyle(AppTheme.ink)

                                ForEach(todayTasks) { task in
                                    TaskCardView(task: task, availability: availability(for: task)) {
                                        requestCompletion(for: task)
                                    }
                                }
                            }
                        }
                    } else {
                        setupPendingCard
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
                .appContentWidth()
            }
            .scrollIndicators(.hidden)
        }
        .tint(AppTheme.orange)
        .sensoryFeedback(.success, trigger: completionCount)
        .fullScreenCover(item: $presentedScreen, onDismiss: presentQueuedScreen) { screen in
            switch screen {
            case .parentMode:
                ParentHomeView(child: child, goal: goal, date: date)
            case .achievement:
                RewardAchievedView(
                    goal: goal,
                    onPostpone: { AchievementDeferralStore.postpone(goalID: goal.id, on: date) },
                    onRedeem: { startRewardTimer() }
                )
            case .timer:
                RewardTimerView(goal: goal) { finishRewardTimer() }
            case .passcodeSetup:
                ParentPasscodeView(mode: .register) { present(.parentMode) }
            case .passcodeUnlock:
                ParentPasscodeView(mode: .unlock) { present(.parentMode) }
            }
        }
        .alert("親モードを開けませんでした", isPresented: Binding(
            get: { authenticationMessage != nil },
            set: { if !$0 { authenticationMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authenticationMessage ?? "もう一度お試しください。")
        }
        .onChange(of: goal.isAchieved) { _, isAchieved in
            guard isAchieved else {
                AchievementDeferralStore.clear(goalID: goal.id)
                return
            }
            if isConfiguredToday, !isAchievementPostponed {
                present(.achievement)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ごほうびプラス")
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                Text("あと なんてん？ ごほうびまでのチャレンジ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.card)
                if isAuthenticating {
                    ProgressView().tint(AppTheme.purple)
                } else {
                    Image(systemName: "person.badge.key.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.purple)
                }
            }
            .frame(width: 48, height: 48)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: 1) {
                openParentMode()
            }
            .onTapGesture {
                showsParentModeHint = true
            }
            .accessibilityLabel("親モード")
            .accessibilityHint("1秒長押しして認証します")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { openParentMode() }
        }
        .padding(.top, 8)
    }

    private var parentModeHint: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.badge.key.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.purple)

            VStack(alignment: .leading, spacing: 3) {
                Text("おうちの人へ")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("右上のボタンを1秒長押しすると、設定を開けます。")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            }

            Spacer(minLength: 8)

            Button {
                showsParentModeHint = false
                hasSeenParentModeHint = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("ヒントを閉じる")
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private var pendingRewardCard: some View {
        Button {
            present(.achievement)
        } label: {
            HStack(spacing: 13) {
                Text("🎁")
                    .font(.system(size: 34))
                VStack(alignment: .leading, spacing: 3) {
                    Text("ごほうび、まだもらってないよ")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(AppTheme.ink)
                    Text(goal.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.mint)
            }
            .padding(14)
            .background(AppTheme.mint.opacity(0.22), in: RoundedRectangle(cornerRadius: 18))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var childSwitcher: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(siblings) { sibling in
                    Button {
                        onSelectChild(sibling)
                    } label: {
                        HStack(spacing: 8) {
                            Text(sibling.avatarEmoji)
                                .font(.title3)
                            Text(sibling.name)
                                .font(.subheadline.weight(.heavy))
                                .lineLimit(1)
                        }
                        .foregroundStyle(sibling.id == child.id ? .white : AppTheme.ink)
                        .padding(.horizontal, 15)
                        .frame(minHeight: 44)
                        .background(
                            sibling.id == child.id ? AppTheme.purple : AppTheme.card,
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(sibling.name)に切り替える")
                    .accessibilityAddTraits(sibling.id == child.id ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var progressCard: some View {
        VStack(spacing: 17) {
            VStack(spacing: 2) {
                Text("あと")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink.opacity(0.7))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(goal.remainingPoints)")
                        .font(.system(size: remainingPointsSize, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.orange)
                        .contentTransition(.numericText())
                    Text("てん！")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }

            PointProgressView(currentPoints: goal.currentPoints, targetPoints: goal.targetPoints)

            if streak >= 2 {
                Text("🔥 \(streak)にち れんぞく！")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppTheme.orange.opacity(0.14), in: Capsule())
            }

            HStack(spacing: 13) {
                Text(goal.emoji)
                    .font(.system(size: 42))
                    .frame(width: 62, height: 62)
                    .background(AppTheme.yellow.opacity(0.22), in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 3) {
                    Text("ごほうび")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(goal.title)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(13)
            .background(AppTheme.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 19))
        }
        .frame(maxWidth: .infinity)
        .appCard()
    }

    private var pendingBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hourglass.circle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("おうちの人に かくにんしてもらおう！")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text("かくにんまち \(pendingCount)こ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(AppTheme.yellow.opacity(0.28), in: RoundedRectangle(cornerRadius: 18))
    }

    private var setupPendingCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 42))
                .foregroundStyle(AppTheme.purple)
            Text("きょうのチャレンジを準備中")
                .font(.title3.weight(.heavy))
                .foregroundStyle(AppTheme.ink)
            Text("もうすぐ きょうのチャレンジが はじまるよ。")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .appCard()
    }

    private var noTasksCard: some View {
        VStack(spacing: 10) {
            Text("☀️")
                .font(.system(size: 40))
            Text("きょうの やることは まだないよ")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            Text("おうちの人が えらんだ やることが ここに でるよ。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .appCard()
    }

    private func availability(for task: TaskItem) -> CompletionAvailability {
        PointService.availability(for: task, requests: childRequests, on: date)
    }

    private func requestCompletion(for task: TaskItem) {
        guard availability(for: task) == .available else { return }

        if requiresApproval {
            guard let request = try? PointService.requestCompletion(for: task, in: modelContext) else { return }
            NotificationService.schedulePendingApproval(
                requestID: request.id,
                childName: child.name,
                taskTitle: task.title
            )
        } else {
            try? PointService.completeWithoutApproval(task: task, goal: goal, in: modelContext)
        }

        completionCount += 1
        SoundService.play(.complete)
    }

    private func openParentMode() {
        guard !isAuthenticating, presentedScreen == nil else { return }
        isAuthenticating = true

        Task {
            switch await ParentAuthenticationService.authenticate() {
            case .authenticated:
                present(.parentMode)
            case .cancelled:
                break
            case .passcodeRequired:
                present(ParentPasscodeStore.isRegistered ? .passcodeUnlock : .passcodeSetup)
            case .failed(let message):
                authenticationMessage = message
            }
            isAuthenticating = false
        }
    }

    private func startRewardTimer() {
        guard let minutes = goal.durationMinutes, minutes > 0 else { return }

        let seconds = TimeInterval(minutes * 60)
        goal.timerEndsAt = Date.now.addingTimeInterval(seconds)
        try? modelContext.save()
        NotificationService.scheduleRewardTimerEnd(after: seconds, rewardTitle: goal.title)
        present(.timer)
    }

    private func finishRewardTimer() {
        goal.timerEndsAt = nil
        try? modelContext.save()
        NotificationService.cancelRewardTimerEnd()
    }

    private func present(_ screen: ChildModalScreen) {
        guard presentedScreen != screen else { return }

        if presentedScreen == nil {
            presentedScreen = screen
        } else {
            queuedScreen = screen
        }
    }

    private func presentQueuedScreen() {
        guard let queuedScreen else { return }
        self.queuedScreen = nil
        presentedScreen = queuedScreen
    }
}

private enum ChildModalScreen: Int, Identifiable {
    case parentMode
    case achievement
    case timer
    case passcodeSetup
    case passcodeUnlock

    var id: Int { rawValue }
}
