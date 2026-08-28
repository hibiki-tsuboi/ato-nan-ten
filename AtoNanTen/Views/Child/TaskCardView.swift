import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    let availability: CompletionAvailability
    let action: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            Text(task.emoji)
                .font(.system(size: 36))
                .frame(width: 54, height: 54)
                .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)

                // 幅が足りないときは縦に落として、どちらも省略されないようにする
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) {
                        pointsLabel
                        unlimitedBadge
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        pointsLabel
                        unlimitedBadge
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: action) {
                VStack(spacing: 3) {
                    Image(systemName: buttonIcon)
                        .font(.headline)
                    Text(buttonTitle)
                        .font(.caption.weight(.heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(buttonForeground)
                .padding(.horizontal, 10)
                .frame(minWidth: 88, minHeight: 56)
                .background(buttonBackground, in: RoundedRectangle(cornerRadius: 17))
            }
            .buttonStyle(.plain)
            .disabled(availability != .available)
            .accessibilityHint(availability == .available ? "親の確認待ちにします" : buttonTitle)
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: AppTheme.orange.opacity(0.09), radius: 10, y: 5)
    }

    private var pointsLabel: some View {
        Text("+\(task.points)てん")
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(AppTheme.purple)
            .lineLimit(1)
    }

    /// 回数制限のない行動だけ、何回でもできることを添える。
    /// 上限のあるものは「できた！」→「きょうはOK」の変化で分かるため出さない。
    @ViewBuilder
    private var unlimitedBadge: some View {
        if task.dailyLimit == nil {
            Text("なんかいでも")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppTheme.ink.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(AppTheme.ink.opacity(0.08), in: Capsule())
                .accessibilityLabel("なんかいでもできます")
        }
    }

    private var buttonTitle: String {
        switch availability {
        case .available: "できた！"
        case .pending: "かくにんまち"
        case .limitReached: "きょうはOK"
        }
    }

    private var buttonIcon: String {
        switch availability {
        case .available: "hand.thumbsup.fill"
        case .pending: "hourglass"
        case .limitReached: "checkmark.circle.fill"
        }
    }

    private var buttonForeground: Color {
        availability == .available ? .white : AppTheme.ink.opacity(0.58)
    }

    private var buttonBackground: Color {
        switch availability {
        case .available: AppTheme.orange
        case .pending: AppTheme.yellow.opacity(0.35)
        case .limitReached: AppTheme.mint.opacity(0.25)
        }
    }
}
