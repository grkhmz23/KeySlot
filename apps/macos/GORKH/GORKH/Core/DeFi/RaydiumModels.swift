import Foundation

enum RaydiumConstants {
    static let mainnetOwnerHost = "owner-v1.raydium.io"
    static let devnetOwnerHost = "owner-v1-devnet.raydium.io"
    static let mainnetAPIHost = "api-v3.raydium.io"
    static let devnetAPIHost = "api-v3-devnet.raydium.io"

    static let mainnetAMMv4ProgramID = "675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8"
    static let mainnetCPMMProgramID = "CPMMoo8L3F4NbTegBCKVNunggL7H1ZpdTHKxQB5qKP1C"
    static let mainnetCLMMProgramID = "CAMMCzo5YL8w4VFF8KVHrK22GGUsp5VTaW7grrKgrWqK"
    static let mainnetFarmV3ProgramID = "EhhTKczWMGQt46ynNeRX1WfeagwwJd7ufHvCDjRxjo5Q"
    static let mainnetFarmV5ProgramID = "9KEPoZmtHUrBbhWN1v1KWLMkkvwY6WLtAVUCPRtRjP4z"
    static let mainnetFarmV6ProgramID = "FarmqiPv5eAj3j1GMdMCMUGXqPUvmquZtMy86QH6rzhG"

    static let devnetAMMv4ProgramID = "DRaya7Kj3aMWQSy19kSjvmuwq9docCHofyP9kanQGaav"
    static let devnetCPMMProgramID = "DRaycpLY18LhpbydsBWbVJtxpNv9oXPgjRSfpF2bWpYb"
    static let devnetCLMMProgramID = "DRayAUgENGQBKVaX8owNhgzkEDyoHTGVEGHVJT1E9pfH"

    static let cacheNotice = "Raydium Owner API and API v3 values are cached display data, not settlement truth."

    static func ownerBaseURL(network: WalletNetwork) -> URL {
        switch network {
        case .mainnetBeta:
            return URL(string: "https://\(mainnetOwnerHost)")!
        case .devnet:
            return URL(string: "https://\(devnetOwnerHost)")!
        }
    }

    static func apiBaseURL(network: WalletNetwork) -> URL {
        switch network {
        case .mainnetBeta:
            return URL(string: "https://\(mainnetAPIHost)")!
        case .devnet:
            return URL(string: "https://\(devnetAPIHost)")!
        }
    }
}

enum RaydiumPositionKind: String, Codable, Equatable {
    case standardLP = "standard_lp"
    case lockedCLMM = "locked_clmm"
    case farm = "farm"
    case unknown

    var title: String {
        switch self {
        case .standardLP:
            return "AMM/CPMM LP"
        case .lockedCLMM:
            return "Locked CLMM LP"
        case .farm:
            return "Farm/staked LP"
        case .unknown:
            return "Unknown Raydium LP"
        }
    }
}

struct RaydiumOwnerEndpointResult: Codable, Equatable {
    let status: LPAdapterStatus
    let positions: [RaydiumPositionRecord]
    let message: String?
}

struct RaydiumPositionRecord: Codable, Equatable, Identifiable {
    var id: String { positionAddress ?? "\(kind.rawValue):\(poolAddress ?? "unknown"):\(lpMintAddress ?? "unknown")" }

    let walletPublicAddress: String
    let kind: RaydiumPositionKind
    let sourceEndpoint: String
    let positionAddress: String?
    let poolAddress: String?
    let lpMintAddress: String?
    let lpAmountRaw: String?
    let lpAmountUI: String?
    let tokenAMint: String?
    let tokenBMint: String?
    let tokenAAmountRaw: String?
    let tokenBAmountRaw: String?
    let tokenAAmountUI: String?
    let tokenBAmountUI: String?
    let feeAAmountRaw: String?
    let feeBAmountRaw: String?
    let feeAAmountUI: String?
    let feeBAmountUI: String?
    let pendingRewardCount: Int
    let lockEndTime: Date?
    let rawStatus: String?
    let partialReason: String?
}

struct RaydiumPoolInfo: Codable, Equatable, Identifiable {
    var id: String { poolAddress }

    let poolAddress: String
    let poolType: RaydiumPositionKind
    let lpMintAddress: String?
    let tokenAMint: String?
    let tokenBMint: String?
    let tvlUSD: Decimal?
}

struct RaydiumMintInfo: Codable, Equatable, Identifiable {
    var id: String { mintAddress }

    let mintAddress: String
    let symbol: String?
    let name: String?
    let decimals: UInt8?
}

struct RaydiumFarmInfo: Codable, Equatable, Identifiable {
    var id: String { farmID }

    let farmID: String
    let lpMintAddress: String?
    let poolAddress: String?
}

struct RaydiumEnrichment: Equatable {
    let poolsByID: [String: RaydiumPoolInfo]
    let mintsByID: [String: RaydiumMintInfo]
    let pricesByMint: [String: Decimal]
    let unavailableReason: String?

    static let empty = RaydiumEnrichment(
        poolsByID: [:],
        mintsByID: [:],
        pricesByMint: [:],
        unavailableReason: nil
    )
}
