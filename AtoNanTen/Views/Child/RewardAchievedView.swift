import SwiftData
import SwiftUI

struct RewardAchievedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var goal: RewardGoal
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.purple, Color(red: 0.34, green: 0.18, blue: 0.66)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ConfettiView(animate: animate && !reduceMotion)
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 22) {
                    Text("🎉")
                        .font(.system(size: 78))
                        .scaleEffect(animate && !reduceMotion ? 1.12 : 0.86)

                    Text("\(goal.currentPoints)てん\nたまった！")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)

                    Text("ごほうびゲット！")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(AppTheme.yellow)

                    VStack(spacing: 10) {
                        Text(goal.emoji).font(.system(size: 70))
                        Text(goal.title)
                            .font(.title.bold())
                            .foregroundStyle(AppTheme.ink)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .appCard()

                    Button {
                        redeemReward()
                    } label: {
                        Label("ごほうびをもらった", systemImage: "gift.fill")
                    }
                    .buttonStyle(BouncyButtonStyle(color: AppTheme.mint))

                    Text("ポイントは0にもどって、つぎのチャレンジがはじまるよ")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                }
                .padding(28)
                .padding(.top, 26)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55).repeatCount(2, autoreverses: true)) {
                animate = true
            }
        }
    }

    private func redeemReward() {
        try? PointService.redeem(goal: goal, in: modelContext)
        dismiss()
    }
}

private struct ConfettiView: View {
    let animate: Bool

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<22, id: \.self) { index in
                ConfettiPiece(
                    index: index,
                    animate: animate,
                    containerSize: proxy.size
                )
            }
        }
        .ignoresSafeArea()
    }
}

private struct ConfettiPiece: View {
    let index: Int
    let animate: Bool
    let containerSize: CGSize

    private let colors: [Color] = [AppTheme.yellow, AppTheme.orange, AppTheme.mint, .pink, .white]

    var body: some View {
        let endY = animate ? containerSize.height + 30 : -30
        let rotation = animate ? Double(index * 83) : 0
        let duration = 1.8 + Double(index % 5) * 0.15
        let delay = Double(index % 7) * 0.08

        RoundedRectangle(cornerRadius: 2)
            .fill(colors[index % colors.count])
            .frame(width: 9, height: 18)
            .rotationEffect(.degrees(rotation))
            .position(x: containerSize.width * horizontalPosition, y: endY)
            .animation(.easeIn(duration: duration).delay(delay), value: animate)
    }

    private var horizontalPosition: Double {
        Double((index * 37) % 100) / 100
    }
}
