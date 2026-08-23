import LocalAuthentication

enum ParentAuthenticationService {
    static func authenticate() async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "パスコードを使う"

        var authorizationError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authorizationError) else {
            throw authorizationError ?? LAError(.notInteractive)
        }

        return try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "親モードを開いて、ポイントや設定を管理します"
        )
    }
}
