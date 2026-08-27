import SwiftUI

struct PointProgressView: View {
    let currentPoints: Int
    let targetPoints: Int

    private var progress: Double {
        guard targetPoints > 0 else { return 0 }
        return min(Double(currentPoints) / Double(targetPoints), 1)
    }

    var body: some View {
        VStack(spacing: 12) {
            if targetPoints <= 10 {
                ViewThatFits(in: .horizontal) {
                    starRow(size: 25, spacing: 6)
                    starRow(size: 20, spacing: 5)
                    starRow(size: 16, spacing: 4)
                    progressBar
                }
            } else {
                progressBar
            }

            Text("\(currentPoints) / \(targetPoints) てん")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink.opacity(0.72))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(targetPoints)点中\(currentPoints)点")
    }

    private func starRow(size: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<targetPoints, id: \.self) { index in
                Image(systemName: index < currentPoints ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(index < currentPoints ? AppTheme.yellow : AppTheme.orange.opacity(0.35))
                    .symbolEffect(.bounce, value: currentPoints)
            }
        }
        .accessibilityHidden(true)
    }

    private var progressBar: some View {
        ProgressView(value: progress)
            .tint(AppTheme.yellow)
            .scaleEffect(y: 2.2)
            .padding(.vertical, 7)
    }
}
