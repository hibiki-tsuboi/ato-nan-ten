import SwiftData
import SwiftUI

struct SetupFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChildProfile.sortOrder) private var children: [ChildProfile]
    @AppStorage("selectedChildID") private var selectedChildID = ""

    let isAddingSibling: Bool
    let onComplete: ((ChildProfile) -> Void)?

    @State private var step = 0
    @State private var childName = ""
    @State private var childAvatar = "🧒"
    @State private var rewardTitle = "ゲーム 30ぷん"
    @State private var rewardEmoji = "🎮"
    @State private var targetPoints = 5
    @State private var presets = SetupTaskPreset.defaults
    @FocusState private var focusedField: SetupField?
    @ScaledMetric(relativeTo: .largeTitle) private var targetPointsSize: CGFloat = 52

    private let rewardEmojis = ["🎮", "🍦", "🍭", "📺", "🧸", "🚲"]
    private let childAvatars = ["🧒", "👦", "👧", "🐶", "🐱", "🐰"]

    init(
        isAddingSibling: Bool = false,
        onComplete: ((ChildProfile) -> Void)? = nil
    ) {
        self.isAddingSibling = isAddingSibling
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                progressHeader

                Group {
                    if step == 0 {
                        rewardStep
                    } else if step == 1 {
                        taskStep
                    } else {
                        completionStep
                    }
                }
                .animation(.easeInOut, value: step)
            }
        }
        .tint(AppTheme.orange)
        .onChange(of: step) {
            focusedField = nil
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 10) {
            if isAddingSibling {
                HStack {
                    Spacer()
                    Button("キャンセル") { dismiss() }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.purple)
                        .frame(minHeight: 44)
                }
            }

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? AppTheme.orange : AppTheme.card)
                        .frame(height: 7)
                }
            }
            .accessibilityLabel("セットアップ ステップ \(step + 1) / 3")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .appContentWidth()
    }

    private var rewardStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                SetupTitle(
                    emoji: isAddingSibling ? "👋" : "🎁",
                    title: isAddingSibling ? "きょうだいの\nチャレンジをつくろう！" : "だれの\nごほうび？",
                    subtitle: "プロフィールとごほうびを決めます"
                )

                if !isAddingSibling {
                    setupIntro
                }

                VStack(alignment: .leading, spacing: 18) {
                    Text("おなまえ")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    TextField("例：たろう", text: $childName)
                        .font(.title3.weight(.bold))
                        .textContentType(.name)
                        .focused($focusedField, equals: .childName)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .rewardTitle
                        }
                        .padding()
                        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 16))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(childAvatars, id: \.self) { avatar in
                            emojiButton(
                                avatar,
                                isSelected: childAvatar == avatar,
                                action: { childAvatar = avatar }
                            )
                        }
                    }

                    Divider()

                    Text("ごほうび")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    TextField("ごほうびの名前", text: $rewardTitle)
                        .font(.title3.weight(.bold))
                        .focused($focusedField, equals: .rewardTitle)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }
                        .padding()
                        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 16))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(rewardEmojis, id: \.self) { emoji in
                            emojiButton(
                                emoji,
                                isSelected: rewardEmoji == emoji,
                                action: { rewardEmoji = emoji }
                            )
                        }
                    }

                    Text("なんてん ためる？")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    HStack(spacing: 22) {
                        stepperButton(systemName: "minus", disabled: targetPoints <= 1) {
                            targetPoints -= 1
                        }

                        Text("\(targetPoints)")
                            .font(.system(size: targetPointsSize, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.purple)
                            .frame(minWidth: 80)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        stepperButton(systemName: "plus", disabled: targetPoints >= 99) {
                            targetPoints += 1
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .appCard()
            }
            .padding(24)
            .appContentWidth()
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button("つぎへ") {
                focusedField = nil
                step = 1
            }
            .buttonStyle(BouncyButtonStyle())
            .disabled(
                childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    rewardTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .appContentWidth()
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    private var setupIntro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("このアプリでできること")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.secondary)
            introRow(number: 1, text: "こどもが「できた！」をおす")
            introRow(number: 2, text: "おうちの人が承認する")
            introRow(number: 3, text: "ポイントがたまって、ごほうびをゲット")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func introRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(AppTheme.orange, in: Circle())
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Spacer(minLength: 0)
        }
    }

    private var taskStep: some View {
        ScrollView {
            VStack(spacing: 22) {
                SetupTitle(
                    emoji: "⭐️",
                    title: "ポイントがもらえる\nことをきめよう！",
                    subtitle: "使わないものはチェックを外せます"
                )

                VStack(spacing: 10) {
                    ForEach($presets) { $preset in
                        Button {
                            preset.isSelected.toggle()
                        } label: {
                            HStack(spacing: 14) {
                                Text(preset.emoji).font(.system(size: 30))
                                Text(preset.title)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                                Text("+\(preset.points)")
                                    .font(.title3.bold())
                                    .foregroundStyle(AppTheme.purple)
                                Image(systemName: preset.isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(preset.isSelected ? AppTheme.mint : .secondary)
                            }
                            .padding(15)
                            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    Button("もどる") { step = 0 }
                        .buttonStyle(BouncyButtonStyle(color: AppTheme.purple.opacity(0.72)))
                    Button("つぎへ") { step = 2 }
                        .buttonStyle(BouncyButtonStyle())
                        .disabled(!presets.contains(where: \.isSelected))
                }
            }
            .padding(24)
            .appContentWidth()
        }
        .scrollIndicators(.hidden)
    }

    private var completionStep: some View {
        ScrollView {
            VStack(spacing: 26) {
                SetupTitle(
                    emoji: "🙌",
                    title: "じゅんびOK！",
                    subtitle: "きょうから楽しくポイントをためよう"
                )

                VStack(spacing: 16) {
                    Text(childAvatar).font(.system(size: 58))
                    Text("\(childName)のチャレンジ")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(rewardEmoji).font(.system(size: 72))
                    Text(rewardTitle)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("\(targetPoints)てん でゲット！")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(AppTheme.purple)
                    Divider()
                    Text("えらんだこと \(presets.filter(\.isSelected).count)こ")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .appCard()

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.purple)
                    Text("設定を変えるときは、子ども画面の右上のボタンを1秒長押ししてください。")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 12) {
                    Button("もどる") { step = 1 }
                        .buttonStyle(BouncyButtonStyle(color: AppTheme.purple.opacity(0.72)))
                    Button("はじめる！") { completeSetup() }
                        .buttonStyle(BouncyButtonStyle(color: AppTheme.mint))
                }
            }
            .padding(24)
            .appContentWidth()
        }
        .scrollIndicators(.hidden)
    }

    private func stepperButton(
        systemName: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(AppTheme.orange, in: Circle())
        }
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }

    private func emojiButton(
        _ emoji: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(emoji)
                .font(.system(size: 30))
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(isSelected ? AppTheme.yellow.opacity(0.35) : AppTheme.background)
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? AppTheme.orange : .clear, lineWidth: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func completeSetup() {
        let child = ChildProfile(
            name: childName.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarEmoji: childAvatar,
            sortOrder: children.count
        )
        let cleanedRewardTitle = rewardTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = RewardGoal(
            childID: child.id,
            title: cleanedRewardTitle,
            emoji: rewardEmoji,
            targetPoints: targetPoints,
            durationMinutes: RewardDuration.minutes(in: cleanedRewardTitle)
        )
        modelContext.insert(child)
        modelContext.insert(goal)

        for (index, preset) in presets.filter(\.isSelected).enumerated() {
            modelContext.insert(TaskItem(
                childID: child.id,
                title: preset.title,
                emoji: preset.emoji,
                points: preset.points,
                dailyLimit: 1,
                sortOrder: index,
                scheduledDate: .now
            ))
        }
        try? modelContext.save()
        if !isAddingSibling {
            selectedChildID = child.id.uuidString
        }
        onComplete?(child)
        if isAddingSibling {
            dismiss()
        }
    }

    private enum SetupField: Hashable {
        case childName
        case rewardTitle
    }
}

private struct SetupTitle: View {
    let emoji: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Text(emoji).font(.system(size: 54))
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.ink)
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 18)
    }
}

private struct SetupTaskPreset: Identifiable {
    let id = UUID()
    let title: String
    let emoji: String
    let points: Int
    var isSelected = true

    static let defaults = [
        SetupTaskPreset(title: "学校の宿題", emoji: "📚", points: 1),
        SetupTaskPreset(title: "くもんの宿題", emoji: "✏️", points: 2),
        SetupTaskPreset(title: "読書", emoji: "📖", points: 1),
        SetupTaskPreset(title: "お手伝い", emoji: "🧹", points: 1)
    ]
}
