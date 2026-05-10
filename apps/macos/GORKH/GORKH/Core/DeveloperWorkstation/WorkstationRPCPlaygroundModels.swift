import Foundation

enum WorkstationRPCMethod: String, CaseIterable, Codable, Identifiable {
    case getHealth
    case getVersion
    case getSlot
    case getEpochInfo
    case getBlockHeight
    case getLatestBlockhash
    case getBalance
    case getAccountInfo
    case getParsedAccountInfo
    case getTransaction
    case getSignatureStatuses
    case getSignaturesForAddress
    case getRecentPrioritizationFees
    case getFeeForMessage
    case simulateTransaction
    case requestAirdrop
    case sendTransaction
    case getProgramAccounts
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .getHealth:
            return "getHealth"
        case .getVersion:
            return "getVersion"
        case .getSlot:
            return "getSlot"
        case .getEpochInfo:
            return "getEpochInfo"
        case .getBlockHeight:
            return "getBlockHeight"
        case .getLatestBlockhash:
            return "getLatestBlockhash"
        case .getBalance:
            return "getBalance"
        case .getAccountInfo:
            return "getAccountInfo"
        case .getParsedAccountInfo:
            return "getParsedAccountInfo"
        case .getTransaction:
            return "getTransaction"
        case .getSignatureStatuses:
            return "getSignatureStatuses"
        case .getSignaturesForAddress:
            return "getSignaturesForAddress"
        case .getRecentPrioritizationFees:
            return "getRecentPrioritizationFees"
        case .getFeeForMessage:
            return "getFeeForMessage"
        case .simulateTransaction:
            return "simulateTransaction"
        case .requestAirdrop:
            return "requestAirdrop"
        case .sendTransaction:
            return "sendTransaction"
        case .getProgramAccounts:
            return "getProgramAccounts"
        case .custom:
            return "Custom method"
        }
    }

    var requiresAddress: Bool {
        switch self {
        case .getBalance, .getAccountInfo, .getParsedAccountInfo, .getSignaturesForAddress:
            return true
        default:
            return false
        }
    }

    var requiresSignature: Bool {
        switch self {
        case .getTransaction, .getSignatureStatuses:
            return true
        default:
            return false
        }
    }

    var requiresEncodedTransaction: Bool {
        switch self {
        case .simulateTransaction, .getFeeForMessage:
            return true
        default:
            return false
        }
    }

    var isBroadScan: Bool {
        self == .getProgramAccounts
    }

    var isCustom: Bool {
        self == .custom
    }

    var isReadOnly: Bool {
        switch self {
        case .requestAirdrop, .sendTransaction, .custom:
            return false
        default:
            return true
        }
    }
}

enum WorkstationRPCPermission: Equatable {
    case allowed
    case allowedThroughFaucetOnly
    case blocked(String)

    var isAllowed: Bool {
        switch self {
        case .allowed, .allowedThroughFaucetOnly:
            return true
        case .blocked:
            return false
        }
    }

    var message: String {
        switch self {
        case .allowed:
            return "Read-only RPC method is allowed."
        case .allowedThroughFaucetOnly:
            return "Airdrop is only available through the guarded localnet/devnet faucet."
        case .blocked(let reason):
            return reason
        }
    }
}

struct WorkstationRPCPlaygroundRequest: Equatable {
    let method: WorkstationRPCMethod
    let cluster: WorkstationCluster
    let address: String?
    let signature: String?
    let encodedTransaction: String?
    let amountSOL: Double?
}

struct WorkstationRPCPlaygroundResult: Equatable {
    let method: WorkstationRPCMethod
    let cluster: WorkstationCluster
    let status: WorkstationDataStatus
    let safeSummary: String
    let rawJSONPreview: String?
    let createdAt: Date
}

struct WorkstationFaucetRequest: Equatable {
    let cluster: WorkstationCluster
    let publicAddress: String
    let amountSOL: Double
}

struct WorkstationFaucetPolicy {
    static let maximumAirdropSOL: Double = 2

    static func validate(_ request: WorkstationFaucetRequest) -> WorkstationRPCPermission {
        guard request.cluster.allowsAirdrop else {
            return .blocked("Airdrop is blocked on \(request.cluster.title). Use localnet or devnet only.")
        }
        guard SolanaAddressValidator.isValidAddress(request.publicAddress) else {
            return .blocked("Enter a valid Solana public address.")
        }
        guard request.amountSOL > 0, request.amountSOL <= maximumAirdropSOL else {
            return .blocked("Airdrop amount must be greater than 0 and no more than \(maximumAirdropSOL) SOL.")
        }
        return .allowedThroughFaucetOnly
    }
}
