import SwiftUI

struct EmojiPicker: View {
    @Binding var selection: String

    let candidates: [String]
    var columns = 4

    @State private var draft = ""
    @FocusState private var isDraftFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
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

            HStack(spacing: 12) {
                // いま選ばれているアイコン。入力欄と取り違えないよう、常にここに表示する
                Text(selection.isEmpty ? "？" : selection)
                    .font(.system(size: 30))
                    .frame(width: 54, height: 46)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("いまのアイコン")

                VStack(alignment: .leading, spacing: 3) {
                    TextField("ほかの絵文字を入力", text: $draft)
                        .focused($isDraftFocused)
                        .submitLabel(.done)
                        .onSubmit { commitDraft() }

                    Text("キーボードの 😀 から選べます")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: isDraftFocused) { _, isFocused in
                if !isFocused { commitDraft() }
            }
        }
    }

    /// 入力中は手を出さず、確定したときにだけ絵文字を取り出す。
    /// 1文字ごとに直すと、日本語入力の変換が途中で戻されてしまうため。
    private func commitDraft() {
        let emoji = Self.lastEmoji(in: draft)
        if !emoji.isEmpty {
            selection = emoji
        }
        draft = ""
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
