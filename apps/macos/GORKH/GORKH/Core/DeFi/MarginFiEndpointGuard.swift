import Foundation

enum MarginFiEndpointGuardError: LocalizedError, Equatable {
    case blockedPath(String)
    case unsupportedPath(String)
    case blockedRPCMethod(String)
    case unsupportedRPCMethod(String)
    case invalidProgramID(String)

    var errorDescription: String? {
        switch self {
        case .blockedPath(let path):
            return "MarginFi endpoint path is blocked: \(path)."
        case .unsupportedPath(let path):
            return "MarginFi endpoint path is not in the read-only allowlist: \(path)."
        case .blockedRPCMethod(let method):
            return "MarginFi RPC method is blocked: \(method)."
        case .unsupportedRPCMethod(let method):
            return "MarginFi RPC method is not in the read-only allowlist: \(method)."
        case .invalidProgramID(let programID):
            return "MarginFi v2 program ID is invalid or unexpected: \(programID)."
        }
    }
}

enum MarginFiEndpointGuard {
    static let deniedFragments = [
        "transaction",
        "unsignedtransaction",
        "txn",
        "tx",
        "instruction",
        "create",
        "account-create",
        "deposit",
        "borrow",
        "repay",
        "withdraw",
        "liquidate",
        "leverage",
        "multiply",
        "loop",
        "swap",
        "order",
        "action"
    ]

    static let allowedRPCMethods = [
        "getAccountInfo",
        "getProgramAccounts"
    ]

    static func validateHTTPReadOnlyPath(_ path: String) throws {
        let components = path.split(separator: "/").map(String.init)
        let staticComponents = components.filter { !SolanaAddressValidator.isValidAddress($0) }
        if let denied = deniedFragments.first(where: { fragment in
            staticComponents.contains { $0.lowercased().contains(fragment) }
        }) {
            throw MarginFiEndpointGuardError.blockedPath("\(path) contains \(denied)")
        }

        throw MarginFiEndpointGuardError.unsupportedPath(
            "No MarginFi HTTP endpoint is allowlisted in Phase 3.4C: \(path)"
        )
    }

    static func validateRPCMethod(_ method: String) throws {
        let lowered = method.lowercased()
        if let denied = deniedFragments.first(where: { lowered.contains($0) }) {
            throw MarginFiEndpointGuardError.blockedRPCMethod("\(method) contains \(denied)")
        }
        guard allowedRPCMethods.contains(method) else {
            throw MarginFiEndpointGuardError.unsupportedRPCMethod(method)
        }
    }

    static func validateProgramID(_ programID: String) throws {
        guard programID == MarginFiConstants.programID,
              SolanaAddressValidator.isValidAddress(programID) else {
            throw MarginFiEndpointGuardError.invalidProgramID(programID)
        }
    }
}
