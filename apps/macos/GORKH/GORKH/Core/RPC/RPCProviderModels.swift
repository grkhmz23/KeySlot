import Foundation

enum RPCProviderKind: String, Codable, CaseIterable, Identifiable {
    case rpcFast = "rpc-fast"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rpcFast:
            return "RPC Fast"
        }
    }
}

enum RPCNetwork: String, Codable, CaseIterable, Identifiable {
    case devnet
    case mainnetBeta = "mainnet-beta"

    var id: String { rawValue }

    init(walletNetwork: WalletNetwork) {
        switch walletNetwork {
        case .devnet:
            self = .devnet
        case .mainnetBeta:
            self = .mainnetBeta
        }
    }

    var walletNetwork: WalletNetwork {
        switch self {
        case .devnet:
            return .devnet
        case .mainnetBeta:
            return .mainnetBeta
        }
    }
}

enum RPCFastTokenStatus: String, Codable, Equatable {
    case present
    case missing

    var displayName: String {
        switch self {
        case .present:
            return "Present"
        case .missing:
            return "Missing"
        }
    }
}

struct RPCFastEndpoint: Codable, Equatable {
    let provider: RPCProviderKind
    let network: RPCNetwork
    let httpURL: URL
    let webSocketURL: URL

    var httpHost: String {
        httpURL.host ?? httpURL.absoluteString
    }

    var webSocketHost: String {
        webSocketURL.host ?? webSocketURL.absoluteString
    }

    var safeHTTPDisplay: String {
        RPCFastRedaction.redactedURLDisplay(httpURL)
    }

    var safeWebSocketDisplay: String {
        RPCFastRedaction.redactedURLDisplay(webSocketURL)
    }
}

enum RPCProviderStatus: String, Codable, Equatable {
    case unchecked
    case healthy
    case degraded
    case unavailable
    case tokenMissing = "token-missing"

    var displayName: String {
        switch self {
        case .unchecked:
            return "Unchecked"
        case .healthy:
            return "Healthy"
        case .degraded:
            return "Degraded"
        case .unavailable:
            return "Unavailable"
        case .tokenMissing:
            return "Token missing"
        }
    }
}

struct RPCLatencySample: Codable, Equatable {
    let method: String
    let latencyMilliseconds: Int
    let measuredAt: Date
    let succeeded: Bool
}

enum RPCMethodAvailability: String, Codable, Equatable {
    case allowed
    case expensive
    case planLimited = "plan-limited"
    case blocked
    case unsupported

    static func evaluate(method: String, programID: String? = nil) -> RPCMethodAvailability {
        let method = method.trimmingCharacters(in: .whitespacesAndNewlines)
        let planLimitedMethods = [
            "getProgramAccounts",
            "getTokenAccountsByOwner",
            "getTokenAccountsByDelegate",
            "getTokenLargestAccounts"
        ]

        if method == "getProgramAccounts" {
            if programID == SolanaConstants.splTokenProgramID {
                return .blocked
            }
            return .expensive
        }

        if planLimitedMethods.contains(method) {
            return .planLimited
        }

        let allowedMethods = [
            "getAccountInfo",
            "getBalance",
            "getBlockHeight",
            "getEpochInfo",
            "getFeeForMessage",
            "getHealth",
            "getLatestBlockhash",
            "getMinimumBalanceForRentExemption",
            "getParsedAccountInfo",
            "getProgramAccounts",
            "getSignatureStatuses",
            "getSlot",
            "getTokenAccountsByOwner",
            "getVersion",
            "requestAirdrop",
            "sendTransaction",
            "simulateTransaction"
        ]
        return allowedMethods.contains(method) ? .allowed : .unsupported
    }
}

struct RPCProviderSecurityStatus: Codable, Equatable {
    let provider: RPCProviderKind
    let network: RPCNetwork
    let tokenStatus: RPCFastTokenStatus
    let tokenEnvironmentNames: [String]
    let beamStatus: String

    var isUsable: Bool {
        tokenStatus == .present
    }
}

struct RPCHealthSnapshot: Codable, Equatable {
    let provider: RPCProviderKind
    let network: RPCNetwork
    let httpEndpointHost: String
    let webSocketEndpointHost: String
    let tokenStatus: RPCFastTokenStatus
    let status: RPCProviderStatus
    let latencyMilliseconds: Int?
    let slot: UInt64?
    let blockHeight: UInt64?
    let version: String?
    let checkedAt: Date
    let errorMessage: String?
    let beamStatus: String

    static func unchecked(network: WalletNetwork, configuration: RPCFastConfiguration = RPCFastConfiguration()) -> RPCHealthSnapshot {
        let endpoint = configuration.endpoint(for: network)
        return RPCHealthSnapshot(
            provider: endpoint.provider,
            network: endpoint.network,
            httpEndpointHost: endpoint.httpHost,
            webSocketEndpointHost: endpoint.webSocketHost,
            tokenStatus: configuration.tokenStatus(for: network),
            status: .unchecked,
            latencyMilliseconds: nil,
            slot: nil,
            blockHeight: nil,
            version: nil,
            checkedAt: Date(),
            errorMessage: nil,
            beamStatus: RPCFastConfiguration.beamStatus
        )
    }

    static func tokenMissing(network: WalletNetwork, configuration: RPCFastConfiguration = RPCFastConfiguration()) -> RPCHealthSnapshot {
        let endpoint = configuration.endpoint(for: network)
        return RPCHealthSnapshot(
            provider: endpoint.provider,
            network: endpoint.network,
            httpEndpointHost: endpoint.httpHost,
            webSocketEndpointHost: endpoint.webSocketHost,
            tokenStatus: .missing,
            status: .tokenMissing,
            latencyMilliseconds: nil,
            slot: nil,
            blockHeight: nil,
            version: nil,
            checkedAt: Date(),
            errorMessage: configuration.missingTokenMessage(for: network),
            beamStatus: RPCFastConfiguration.beamStatus
        )
    }
}
