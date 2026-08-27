import SwiftUI

enum AppTheme {
    static let orange = Color(red: 1.00, green: 0.48, blue: 0.20)
    static let yellow = Color(red: 1.00, green: 0.78, blue: 0.20)
    static let purple = Color(red: 0.48, green: 0.35, blue: 0.88)
    static let mint = Color(red: 0.25, green: 0.74, blue: 0.64)
    static let ink = Color(red: 0.16, green: 0.14, blue: 0.23)
    static let background = Color(red: 1.00, green: 0.97, blue: 0.91)

    static let backgroundGradient = LinearGradient(
        colors: [background, Color(red: 1.0, green: 0.93, blue: 0.84)],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: AppTheme.orange.opacity(0.10), radius: 12, y: 6)
    }
}

extension View {
    func appCard() -> some View {
        modifier(CardStyle())
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
