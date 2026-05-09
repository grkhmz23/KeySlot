import Foundation

enum RPCErrorCategory: String, Codable, Equatable {
    case unauthorized
    case tokenMissing = "token-missing"
    case rateLimited = "rate-limited"
    case planUpgradeRequired = "plan-upgrade-required"
    case methodBlocked = "method-blocked"
    case endpointUnavailable = "endpoint-unavailable"
    case timeout
    case invalidResponse = "invalid-response"
    case unknown
}

struct RPCNormalizedError: Codable, Equatable {
    let category: RPCErrorCategory
    let message: String
}

enum RPCErrorNormalizer {
    static func normalize(
        statusCode: Int? = nil,
        message: String,
        configuration: RPCFastConfiguration = RPCFastConfiguration()
    ) -> RPCNormalizedError {
        let safeMessage = configuration.redact(message)
        let lowercased = safeMessage.lowercased()

        if statusCode == 401 || statusCode == 403 || lowercased.contains("unauthorized") || lowercased.contains("forbidden") {
            return RPCNormalizedError(category: .unauthorized, message: "RPC Fast authorization failed. Check the local RPC Fast token environment variable.")
        }
        if statusCode == 429 || lowercased.contains("rate limit") || lowercased.contains("too many requests") {
            return RPCNormalizedError(category: .rateLimited, message: "RPC Fast rate limit reached. Try again after the provider window resets.")
        }
        if lowercased.contains("upgrade") || lowercased.contains("plan") || lowercased.contains("compute unit") {
            return RPCNormalizedError(category: .planUpgradeRequired, message: "RPC Fast plan does not currently allow this method or usage level.")
        }
        if lowercased.contains("blocked") || lowercased.contains("not allowed") || lowercased.contains("disabled") {
            return RPCNormalizedError(category: .methodBlocked, message: "RPC Fast blocked this RPC method or program for the current plan.")
        }
        if statusCode.map({ !(200..<300).contains($0) }) == true {
            return RPCNormalizedError(category: .endpointUnavailable, message: safeMessage)
        }
        if lowercased.contains("timed out") || lowercased.contains("timeout") {
            return RPCNormalizedError(category: .timeout, message: "RPC Fast endpoint timed out.")
        }

        return RPCNormalizedError(category: .unknown, message: safeMessage)
    }

    static func normalize(_ error: Error, configuration: RPCFastConfiguration = RPCFastConfiguration()) -> RPCNormalizedError {
        if let rpcError = error as? SolanaRPCError {
            switch rpcError {
            case .tokenMissing(let message):
                return RPCNormalizedError(category: .tokenMissing, message: configuration.redact(message))
            case .unauthorized(let message):
                return RPCNormalizedError(category: .unauthorized, message: configuration.redact(message))
            case .rateLimited(let message):
                return RPCNormalizedError(category: .rateLimited, message: configuration.redact(message))
            case .planUpgradeRequired(let message):
                return RPCNormalizedError(category: .planUpgradeRequired, message: configuration.redact(message))
            case .methodBlocked(let message):
                return RPCNormalizedError(category: .methodBlocked, message: configuration.redact(message))
            case .timeout(let message):
                return RPCNormalizedError(category: .timeout, message: configuration.redact(message))
            case .invalidResponse:
                return RPCNormalizedError(category: .invalidResponse, message: "Solana RPC returned an invalid response.")
            case .transport(let message), .rpc(let message), .devnetOnly(let message):
                return normalize(message: message, configuration: configuration)
            }
        }

        if let urlError = error as? URLError, urlError.code == .timedOut {
            return RPCNormalizedError(category: .timeout, message: "RPC Fast endpoint timed out.")
        }

        return normalize(message: error.localizedDescription, configuration: configuration)
    }
}
