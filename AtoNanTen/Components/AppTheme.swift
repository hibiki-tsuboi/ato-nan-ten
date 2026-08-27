import SwiftUI
import UIKit

enum AppTheme {
    // アクセントは明暗どちらでも沈まないよう、ダークでわずかに明るくするだけにとどめる
    static let orange = dynamic(light: (1.00, 0.48, 0.20), dark: (1.00, 0.55, 0.28))
    static let yellow = dynamic(light: (1.00, 0.78, 0.20), dark: (1.00, 0.82, 0.32))
    static let purple = dynamic(light: (0.48, 0.35, 0.88), dark: (0.66, 0.56, 0.97))
    static let mint = dynamic(light: (0.25, 0.74, 0.64), dark: (0.34, 0.83, 0.72))

    /// 文字色
    static let ink = dynamic(light: (0.16, 0.14, 0.23), dark: (0.96, 0.95, 0.99))
    /// 画面の下地。カードの中の差し色としても使う
    static let background = dynamic(light: (1.00, 0.97, 0.91), dark: (0.09, 0.08, 0.15))
    /// カードなど、下地の上に乗る面
    static let card = dynamic(light: (0.99, 0.98, 0.96), dark: (0.17, 0.16, 0.25))

    private static let backgroundBottom = dynamic(light: (1.00, 0.93, 0.84), dark: (0.13, 0.11, 0.21))

    static let backgroundGradient = LinearGradient(
        colors: [background, backgroundBottom],
        startPoint: .top,
        endPoint: .bottom
    )

    private static func dynamic(
        light: (red: Double, green: Double, blue: Double),
        dark: (red: Double, green: Double, blue: Double)
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let components = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: components.red, green: components.green, blue: components.blue, alpha: 1)
        })
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: AppTheme.orange.opacity(0.10), radius: 12, y: 6)
    }
}

extension View {
    func appCard() -> some View {
        modifier(CardStyle())
    }

    /// iPadなどの広い画面で横に間延びしないよう、内容の幅を制限して中央に寄せる
    func appContentWidth(_ maxWidth: CGFloat = 560) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

struct BouncyButtonStyle: ButtonStyle {
    var color: Color = AppTheme.orange

    func makeBody(configuration: Configuration) -> some View {
        BouncyButtonLabel(configuration: configuration, color: color)
    }
}

private struct BouncyButtonLabel: View {
    @Environment(\.isEnabled) private var isEnabled

    let configuration: ButtonStyleConfiguration
    let color: Color

    var body: some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .saturation(isEnabled ? 1 : 0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.5)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}
