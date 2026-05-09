import Foundation
import LocalAuthentication

enum LocalAuthenticationResult: Equatable {
    case success
    case unavailable(String)
    case failed(String)

    var succeeded: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var message: String {
        switch self {
        case .success:
            return "Device authentication succeeded."
        case .unavailable(let message), .failed(let message):
            return message
        }
    }
}

protocol LocalAuthenticationService {
    var statusDescription: String { get }
    func authenticate(reason: String) async -> LocalAuthenticationResult
}

struct SystemLocalAuthenticationService: LocalAuthenticationService {
    var statusDescription: String {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            return "Touch ID or macOS password available"
        }
        return error?.localizedDescription ?? "Device authentication unavailable"
    }

    func authenticate(reason: String) async -> LocalAuthenticationResult {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .unavailable(error?.localizedDescription ?? "Device authentication is unavailable.")
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return success ? .success : .failed("Device authentication failed.")
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
