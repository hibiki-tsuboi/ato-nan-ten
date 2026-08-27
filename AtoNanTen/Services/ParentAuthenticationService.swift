import CryptoKit
import Foundation
import LocalAuthentication

enum ParentAuthenticationResult {
    case authenticated
    case cancelled
    case passcodeRequired
    case failed(String)
}

enum ParentAuthenticationService {
    static func authenticate() async -> ParentAuthenticationResult {
        let context = LAContext()
        context.localizedFallbackTitle = "パスコードを使う"

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            return .passcodeRequired
        }

        do {
            let isAuthenticated = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "親モードを開いて、ポイントや設定を管理します"
            )
            return isAuthenticated ? .authenticated : .cancelled
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .systemCancel, .appCancel:
                return .cancelled
            case .biometryNotEnrolled, .biometryNotAvailable, .passcodeNotSet:
                return .passcodeRequired
            default:
                return .failed("Face IDまたは端末のパスコードを確認してください。")
            }
        } catch {
            return .failed("Face IDまたは端末のパスコードを確認してください。")
        }
    }
}

enum ParentPasscodeStore {
    static let length = 4

    private static let storageKey = "parentPasscodeHash"

    static var isRegistered: Bool {
        storedHash != nil
    }

    static func register(_ passcode: String) {
        UserDefaults.standard.set(hashed(passcode), forKey: storageKey)
    }

    static func matches(_ passcode: String) -> Bool {
        guard let storedHash else { return false }
        return storedHash == hashed(passcode)
    }

    private static var storedHash: String? {
        guard let hash = UserDefaults.standard.string(forKey: storageKey), !hash.isEmpty else {
            return nil
        }
        return hash
    }

    private static func hashed(_ passcode: String) -> String {
        SHA256.hash(data: Data(passcode.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
