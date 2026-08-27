import SwiftData
import SwiftUI

struct RewardTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var goal: RewardGoal
    let onFinish: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var remainingSize: CGFloat = 62

    private var totalSeconds: TimeInterval {
        TimeInterval((goal.durationMinutes ?? 0) * 60)
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, (goal.timerEndsAt ?? context.date).timeIntervalSince(context.date))
                timerBody(remaining: remaining)
            }
        }
        .task {
            let remaining = (goal.timerEndsAt ?? .now).timeIntervalSinceNow
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            SoundService.play(.finish)
        }
        .sensoryFeedback(.success, trigger: goal.timerEndsAt)
    }

    private func timerBody(remaining: TimeInterval) -> some View {
        VStack(spacing: 26) {
            VStack(spacing: 10) {
                Text(goal.emoji)
                    .font(.system(size: 64))
                Text(goal.title)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.center)
            }

            ZStack {
                Circle()
                    .stroke(AppTheme.orange.opacity(0.18), lineWidth: 18)

                Circle()
                    .trim(from: 0, to: progress(remaining: remaining))
                    .stroke(AppTheme.orange, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.9), value: remaining)

                VStack(spacing: 4) {
                    if remaining > 0 {
                        Text(timeText(remaining: remaining))
                            .font(.system(size: remainingSize, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("のこり")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("おしまい！")
                            .font(.system(size: remainingSize * 0.6, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.orange)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(30)
            }
            .frame(maxWidth: 280)
            .frame(height: 280)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(remaining > 0 ? "のこり\(Int(remaining / 60))分" : "おしまい")

            Button(remaining > 0 ? "おしまいにする" : "とじる") {
                onFinish()
                dismiss()
            }
            .buttonStyle(BouncyButtonStyle(color: remaining > 0 ? AppTheme.purple.opacity(0.72) : AppTheme.mint))

            if remaining > 0 {
                Text("じかんになったら おしらせするよ")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .appContentWidth()
    }

    private func progress(remaining: TimeInterval) -> Double {
        guard totalSeconds > 0 else { return 0 }
        return min(max(remaining / totalSeconds, 0), 1)
    }

    private func timeText(remaining: TimeInterval) -> String {
        let seconds = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
