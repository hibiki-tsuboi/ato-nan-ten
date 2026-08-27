import SwiftUI

struct ParentPasscodeView: View {
    enum Mode {
        case register
        case unlock
    }

    let mode: Mode
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var passcode = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case passcode
        case confirmation
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("\(ParentPasscodeStore.length)けたの数字", text: $passcode)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .passcode)
                        .onChange(of: passcode) { _, newValue in
                            passcode = sanitized(newValue)
                            errorMessage = nil
                        }

                    if mode == .register {
                        SecureField("もう一度入力", text: $confirmation)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .confirmation)
                            .onChange(of: confirmation) { _, newValue in
                                confirmation = sanitized(newValue)
                                errorMessage = nil
                            }
                    }
                } header: {
                    Text(mode == .register ? "新しいパスコード" : "パスコード")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else {
                        Text(footerText)
                    }
                }
            }
            .navigationTitle("親モード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .register ? "設定する" : "開く") { submit() }
                        .fontWeight(.bold)
                        .disabled(!isSubmittable)
                }
            }
            .onAppear { focusedField = .passcode }
        }
        .tint(AppTheme.purple)
    }

    private var footerText: String {
        switch mode {
        case .register:
            "この端末ではFace IDや端末のパスコードが使えないため、親モード用のパスコードを設定します。忘れないようにしてください。"
        case .unlock:
            "設定した\(ParentPasscodeStore.length)けたのパスコードを入力してください。"
        }
    }

    private var isSubmittable: Bool {
        switch mode {
        case .register:
            passcode.count == ParentPasscodeStore.length && confirmation.count == ParentPasscodeStore.length
        case .unlock:
            passcode.count == ParentPasscodeStore.length
        }
    }

    private func sanitized(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(ParentPasscodeStore.length))
    }

    private func submit() {
        switch mode {
        case .register:
            guard passcode == confirmation else {
                errorMessage = "2回入力したパスコードが違います。"
                return
            }
            ParentPasscodeStore.register(passcode)
        case .unlock:
            guard ParentPasscodeStore.matches(passcode) else {
                errorMessage = "パスコードが違います。"
                return
            }
        }

        onSuccess()
        dismiss()
    }
}
