import SwiftUI

struct EmojiPicker: View {
    @Binding var selection: String

    let candidates: [String]
    var columns = 4

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: 12) {
                ForEach(candidates, id: \.self) { candidate in
                    Button {
                        selection = candidate
                    } label: {
                        Text(candidate)
                            .font(.system(size: 32))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(selection == candidate ? AppTheme.yellow.opacity(0.3) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("すきな絵文字を入力")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("🙂", text: $selection)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28))
                    .frame(width: 66, height: 44)
                    .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: selection) { oldValue, newValue in
                        let cleaned = Self.lastEmoji(in: newValue)
                        guard cleaned != newValue else { return }
                        selection = cleaned.isEmpty ? oldValue : cleaned
                    }
                    .accessibilityLabel("絵文字を入力")
            }
        }
    }

    nonisolated static func lastEmoji(in value: String) -> String {
        guard let character = value.reversed().first(where: isEmoji) else { return "" }
        return String(character)
    }

    nonisolated private static func isEmoji(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && scalar.value > 0x238C)
        }
    }
}
