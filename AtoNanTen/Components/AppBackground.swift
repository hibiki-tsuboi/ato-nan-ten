import SwiftUI

/// 子ども向け画面の下地。画像が無い場合はグラデーションだけになる
struct AppBackground: View {
    var body: some View {
        AppTheme.backgroundGradient
            .overlay {
                Image("ChildBackground")
                    .resizable()
                    .scaledToFill()
                    .clipped()
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}

/// 達成画面の下地
struct AchievedBackground: View {
    var body: some View {
        LinearGradient(
            colors: [AppTheme.purple, Color(red: 0.34, green: 0.18, blue: 0.66)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image("AchievedBackground")
                .resizable()
                .scaledToFill()
                .clipped()
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
