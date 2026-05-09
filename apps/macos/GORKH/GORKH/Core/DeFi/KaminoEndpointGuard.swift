import Foundation

enum KaminoEndpointKind: String, Equatable {
    case marketList
    case reserveMetrics
    case userObligations
}

enum KaminoEndpointGuardError: LocalizedError, Equatable {
    case invalidHost(String)
    case blockedPath(String)
    case unsupportedPath(String)
    case invalidAddress(String)

    var errorDescription: String? {
        switch self {
        case .invalidHost(let host):
            return "Kamino endpoint host is not allowed: \(host)."
        case .blockedPath(let path):
            return "Kamino endpoint path is blocked: \(path)."
        case .unsupportedPath(let path):
            return "Kamino endpoint path is not in the read-only allowlist: \(path)."
        case .invalidAddress(let address):
            return "Kamino endpoint contains an invalid public address: \(address)."
        }
    }
}

enum KaminoEndpointGuard {
    static let deniedPathFragments = [
        "transaction",
        "unsignedtransaction",
        "txn",
        "tx",
        "deposit",
        "borrow",
        "repay",
        "withdraw",
        "liquidate",
        "leverage",
        "multiply",
        "swap",
        "order",
        "action",
        "instruction"
    ]

    static func validate(url: URL, kind: KaminoEndpointKind) throws {
        guard url.scheme == "https", url.host?.lowercased() == "api.kamino.finance" else {
            throw KaminoEndpointGuardError.invalidHost(url.host ?? "missing")
        }

        let path = url.path
        let components = path.split(separator: "/").map(String.init)
        let staticComponents = components.filter { !SolanaAddressValidator.isValidAddress($0) }
        if let denied = deniedPathFragments.first(where: { fragment in
            staticComponents.contains { $0.lowercased().contains(fragment) }
        }) {
            throw KaminoEndpointGuardError.blockedPath("\(path) contains \(denied)")
        }

        switch kind {
        case .marketList:
            guard components == ["v2", "kamino-market"] else {
                throw KaminoEndpointGuardError.unsupportedPath(path)
            }
        case .reserveMetrics:
            guard components.count == 4,
                  components[0] == "kamino-market",
                  components[2] == "reserves",
                  components[3] == "metrics" else {
                throw KaminoEndpointGuardError.unsupportedPath(path)
            }
            try validatePublicAddress(components[1])
        case .userObligations:
            guard components.count == 5,
                  components[0] == "kamino-market",
                  components[2] == "users",
                  components[4] == "obligations" else {
                throw KaminoEndpointGuardError.unsupportedPath(path)
            }
            try validatePublicAddress(components[1])
            try validatePublicAddress(components[3])
        }
    }

    private static func validatePublicAddress(_ value: String) throws {
        guard SolanaAddressValidator.isValidAddress(value) else {
            throw KaminoEndpointGuardError.invalidAddress(value)
        }
    }
}
