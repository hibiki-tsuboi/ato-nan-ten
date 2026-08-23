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
                HStack(spacing: 6) {
                    ForEach(0..<targetPoints, id: \.self) { index in
                        Image(systemName: index < currentPoints ? "star.fill" : "star")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(index < currentPoints ? AppTheme.yellow : AppTheme.orange.opacity(0.35))
                            .symbolEffect(.bounce, value: currentPoints)
                    }
                }
                .accessibilityHidden(true)
            } else {
                ProgressView(value: progress)
                    .tint(AppTheme.yellow)
                    .scaleEffect(y: 2.2)
                    .padding(.vertical, 7)
            }

            Text("\(currentPoints) / \(targetPoints) てん")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink.opacity(0.72))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(targetPoints)点中\(currentPoints)点")
    }
}
