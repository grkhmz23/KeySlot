import Foundation

enum RaydiumEndpointKind: Equatable {
    case ownerStake(owner: String)
    case ownerCLMMLock(owner: String)
    case poolsInfo(ids: [String])
    case mintIDs(mints: [String])
    case mintPrice(mints: [String])
    case mintList
    case farmsInfoLP(lpMint: String)
}

enum RaydiumEndpointGuardError: LocalizedError, Equatable {
    case invalidHost(String)
    case blockedPath(String)
    case unsupportedPath(String)
    case invalidAddress(String)
    case missingQuery(String)

    var errorDescription: String? {
        switch self {
        case .invalidHost(let host):
            return "Raydium endpoint host is not allowed: \(host)."
        case .blockedPath(let path):
            return "Raydium endpoint path is blocked: \(path)."
        case .unsupportedPath(let path):
            return "Raydium endpoint path is not in the read-only allowlist: \(path)."
        case .invalidAddress(let address):
            return "Raydium endpoint contains an invalid public address: \(address)."
        case .missingQuery(let name):
            return "Raydium endpoint is missing required query item: \(name)."
        }
    }
}

enum RaydiumEndpointGuard {
    static let allowedHosts: Set<String> = [
        RaydiumConstants.mainnetOwnerHost,
        RaydiumConstants.devnetOwnerHost,
        RaydiumConstants.mainnetAPIHost,
        RaydiumConstants.devnetAPIHost
    ]

    static let deniedFragments = [
        "transaction",
        "route",
        "swap",
        "build",
        "execute",
        "add-liquidity",
        "removeliquidity",
        "remove-liquidity",
        "claim",
        "harvest",
        "close",
        "create-pool",
        "createposition",
        "farm/deposit",
        "farm/withdraw",
        "auth",
        "forum",
        "launch",
        "ipfs",
        "upload"
    ]

    static func validate(url: URL, kind: RaydiumEndpointKind) throws {
        guard url.scheme == "https",
              let host = url.host?.lowercased(),
              allowedHosts.contains(host) else {
            throw RaydiumEndpointGuardError.invalidHost(url.host ?? "missing")
        }

        let path = url.path
        let lowerPath = path.lowercased()
        let components = path.split(separator: "/").map(String.init)
        if let denied = deniedFragments.first(where: { lowerPath.contains($0) }) {
            throw RaydiumEndpointGuardError.blockedPath("\(path) contains \(denied)")
        }

        switch kind {
        case .ownerStake(let owner):
            guard components == ["position", "stake", owner] else {
                throw RaydiumEndpointGuardError.unsupportedPath(path)
            }
            try validatePublicAddress(owner)
        case .ownerCLMMLock(let owner):
            guard components == ["position", "clmm-lock", owner] else {
                throw RaydiumEndpointGuardError.unsupportedPath(path)
            }
            try validatePublicAddress(owner)
        case .poolsInfo(let ids):
            guard components == ["pools", "info", "ids"] else {
                throw RaydiumEndpointGuardError.unsupportedPath(path)
            }
            try validateList(ids, queryName: "ids")
            try validateQueryList(url: url, name: "ids", expected: ids)
        case .mintIDs(let mints):
            guard components == ["mint", "ids"] else {
                throw RaydiumEndpointGuardError.unsupportedPath(path)
            }
            try validateList(mints, queryName: "mints")
            try validateQueryList(url: url, name: "mints", expected: mints)
        case .mintPrice(let mints):
            guard components == ["mint", "price"] else {
                throw RaydiumEndpointGuardError.unsupportedPath(path)
            }
            try validateList(mints, queryName: "mints")
            try validateQueryList(url: url, name: "mints", expected: mints)
        case .mintList:
            guard components == ["mint", "list"] else {
                throw RaydiumEndpointGuardError.unsupportedPath(path)
            }
        case .farmsInfoLP(let lpMint):
            guard components == ["farms", "info", "lp"] else {
                throw RaydiumEndpointGuardError.unsupportedPath(path)
            }
            try validatePublicAddress(lpMint)
            try validateQueryValue(url: url, name: "lp", expected: lpMint)
        }
    }

    private static func validateList(_ values: [String], queryName: String) throws {
        guard !values.isEmpty else {
            throw RaydiumEndpointGuardError.missingQuery(queryName)
        }
        for value in values {
            try validatePublicAddress(value)
        }
    }

    private static func validateQueryList(url: URL, name: String, expected: [String]) throws {
        let values = queryValue(url: url, name: name)?
            .split(separator: ",")
            .map(String.init) ?? []
        guard values == expected else {
            throw RaydiumEndpointGuardError.missingQuery(name)
        }
    }

    private static func validateQueryValue(url: URL, name: String, expected: String) throws {
        guard queryValue(url: url, name: name) == expected else {
            throw RaydiumEndpointGuardError.missingQuery(name)
        }
    }

    private static func queryValue(url: URL, name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value
    }

    private static func validatePublicAddress(_ value: String) throws {
        guard SolanaAddressValidator.isValidAddress(value) else {
            throw RaydiumEndpointGuardError.invalidAddress(value)
        }
    }
}
