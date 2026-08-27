import SwiftData
import SwiftUI

struct ChildHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @Query(sort: \CompletionRequest.requestedAt, order: .reverse) private var requests: [CompletionRequest]

    let child: ChildProfile
    @Bindable var goal: RewardGoal
    let siblings: [ChildProfile]
    let date: Date
    let onSelectChild: (ChildProfile) -> Void
    @State private var presentedScreen: ChildModalScreen?
    @State private var queuedScreen: ChildModalScreen?
    @State private var isAuthenticating = false
    @State private var authenticationMessage: String?

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
        _presentedScreen = State(initialValue: isAchievedToday ? .achievement : nil)
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

    private var pendingCount: Int {
        childRequests.filter { $0.status == .pending }.count
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    childSwitcher

                    if isConfiguredToday {
                        progressCard

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
            }
            .scrollIndicators(.hidden)
        }
        .tint(AppTheme.orange)
        .fullScreenCover(item: $presentedScreen, onDismiss: presentQueuedScreen) { screen in
            switch screen {
            case .parentMode:
                ParentHomeView(child: child, goal: goal, date: date)
            case .achievement:
                RewardAchievedView(goal: goal)
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
            if isAchieved && isConfiguredToday {
                present(.achievement)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("あとなんてん？")
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                Text("ごほうびまでのチャレンジ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(.white.opacity(0.9))
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
            .accessibilityLabel("親モード")
            .accessibilityHint("1秒長押しして認証します")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { openParentMode() }
        }
        .padding(.top, 8)
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
                            sibling.id == child.id ? AppTheme.purple : .white.opacity(0.88),
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
                        .font(.system(size: 70, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.orange)
                        .contentTransition(.numericText())
                    Text("てん！")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                }
            }

            PointProgressView(currentPoints: goal.currentPoints, targetPoints: goal.targetPoints)

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
            Text("きょうの行動はまだないよ")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            Text("おうちの人が選んだ行動だけ、ここに表示されます。")
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
        try? PointService.requestCompletion(for: task, in: modelContext)
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
    case passcodeSetup
    case passcodeUnlock

    var id: Int { rawValue }
}
