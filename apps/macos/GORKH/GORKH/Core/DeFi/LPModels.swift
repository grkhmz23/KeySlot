import Foundation

enum LPConstants {
    static let source = "read-only-lp-adapters"
    static let noDoubleCountNotice = "LP values are shown separately from wallet token balances to avoid double-counting."
}

enum LPProtocolKind: String, Codable, CaseIterable, Identifiable, Equatable {
    case meteora
    case orca
    case raydium

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .meteora:
            return "Meteora"
        case .orca:
            return "Orca"
        case .raydium:
            return "Raydium"
        }
    }
}

enum LPAdapterStatus: String, Codable, Equatable {
    case idle
    case loaded
    case empty
    case partial
    case unavailable
    case error
    case stale

    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .loaded:
            return "Loaded"
        case .empty:
            return "Empty"
        case .partial:
            return "Partial"
        case .unavailable:
            return "Unavailable"
        case .error:
            return "Error"
        case .stale:
            return "Stale"
        }
    }
}

enum LPDataSource: String, Codable, Equatable {
    case sdkReadOnly = "sdk-read-only"
    case publicAPI = "public-api"
    case solanaRPC = "solana-rpc"
    case unavailable
}

enum LPRangeState: String, Codable, Equatable {
    case inRange = "in_range"
    case outOfRange = "out_of_range"
    case unknown

    var title: String {
        switch self {
        case .inRange:
            return "In range"
        case .outOfRange:
            return "Out of range"
        case .unknown:
            return "Unknown"
        }
    }
}

enum LPLockedAction: String, Codable, CaseIterable, Identifiable, Equatable {
    case addLiquidity = "add_liquidity"
    case removeLiquidity = "remove_liquidity"
    case claimFees = "claim_fees"
    case closePosition = "close_position"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addLiquidity:
            return "Add liquidity locked"
        case .removeLiquidity:
            return "Remove liquidity locked"
        case .claimFees:
            return "Manual claim locked"
        case .closePosition:
            return "Close position locked"
        }
    }

    var isEnabled: Bool {
        false
    }
}

struct LPPositionAssetAmount: Codable, Equatable, Identifiable {
    var id: String { "\(mintAddress):\(symbol)" }

    let mintAddress: String
    let symbol: String
    let name: String
    let amountRaw: UInt64?
    let decimals: UInt8?
    let uiAmountString: String?
    let usdValue: Decimal?
    let priceQuote: PortfolioPriceQuote?
    let source: LPDataSource
}

struct LPFeeSummary: Codable, Equatable {
    let tokenAFees: LPPositionAssetAmount?
    let tokenBFees: LPPositionAssetAmount?
    let totalUSD: Decimal?
    let unavailableReason: String?

    static let unavailable = LPFeeSummary(
        tokenAFees: nil,
        tokenBFees: nil,
        totalUSD: nil,
        unavailableReason: "Fee amounts are unavailable from the read-only adapter."
    )
}

struct LPRangeSummary: Codable, Equatable {
    let lowerBinID: Int?
    let upperBinID: Int?
    let currentBinID: Int?
    let state: LPRangeState
    let unavailableReason: String?

    static let unavailable = LPRangeSummary(
        lowerBinID: nil,
        upperBinID: nil,
        currentBinID: nil,
        state: .unknown,
        unavailableReason: "Range and bin metadata are unavailable from the read-only adapter."
    )
}

struct LPImpermanentLossSummary: Codable, Equatable {
    let estimatedUSD: Decimal?
    let unavailableReason: String?

    static let unavailable = LPImpermanentLossSummary(
        estimatedUSD: nil,
        unavailableReason: "Impermanent loss estimation is not calculated in this read-only phase."
    )
}

struct LPPositionSummary: Codable, Equatable, Identifiable {
    var id: String { "\(protocolKind.rawValue):\(walletID.uuidString):\(positionAddress)" }

    let walletID: UUID
    let walletLabel: String
    let walletPublicAddress: String
    let network: WalletNetwork
    let protocolKind: LPProtocolKind
    let poolAddress: String
    let positionAddress: String
    let positionMintAddress: String?
    let tokenA: LPPositionAssetAmount?
    let tokenB: LPPositionAssetAmount?
    let estimatedValueUSD: Decimal?
    let feeSummary: LPFeeSummary
    let rangeSummary: LPRangeSummary
    let impermanentLoss: LPImpermanentLossSummary
    let source: LPDataSource
    let updatedAt: Date
    let status: LPAdapterStatus
    let metadataStatus: String?
    let errorMessage: String?
}

struct LPAdapterResult: Codable, Equatable {
    let protocolKind: LPProtocolKind
    let status: LPAdapterStatus
    let positions: [LPPositionSummary]
    let source: LPDataSource
    let updatedAt: Date
    let errorMessage: String?

    static func unavailable(
        protocolKind: LPProtocolKind,
        reason: String,
        updatedAt: Date = Date()
    ) -> LPAdapterResult {
        LPAdapterResult(
            protocolKind: protocolKind,
            status: .unavailable,
            positions: [],
            source: .unavailable,
            updatedAt: updatedAt,
            errorMessage: reason
        )
    }
}

struct LPProtocolSummary: Codable, Equatable, Identifiable {
    var id: String { protocolKind.rawValue }

    let protocolKind: LPProtocolKind
    let status: LPAdapterStatus
    let positions: [LPPositionSummary]
    let estimatedValueUSD: Decimal?
    let positionCount: Int
    let partialPositionCount: Int
    let walletCount: Int
    let source: LPDataSource
    let updatedAt: Date
    let errorMessage: String?
}

struct LPPortfolioSummary: Codable, Equatable {
    let status: LPAdapterStatus
    let protocols: [LPProtocolSummary]
    let estimatedValueUSD: Decimal?
    let positionCount: Int
    let partialAdapterCount: Int
    let partialPositionCount: Int
    let unavailableAdapterCount: Int
    let walletCount: Int
    let source: String
    let noDoubleCountNotice: String
    let refreshedAt: Date
    let errorMessage: String?

    static func empty(status: LPAdapterStatus = .idle) -> LPPortfolioSummary {
        LPPortfolioSummary(
            status: status,
            protocols: [],
            estimatedValueUSD: 0,
            positionCount: 0,
            partialAdapterCount: 0,
            partialPositionCount: 0,
            unavailableAdapterCount: 0,
            walletCount: 0,
            source: LPConstants.source,
            noDoubleCountNotice: LPConstants.noDoubleCountNotice,
            refreshedAt: Date(),
            errorMessage: nil
        )
    }
}
