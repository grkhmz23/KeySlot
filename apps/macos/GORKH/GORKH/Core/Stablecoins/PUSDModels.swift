import Foundation

enum PUSDConstants {
    static let mintAddress = "CZzgUBvxaMLwMhVSLgqJn3npmxoTo6nzMNQPAnwtHF3s"
    static let symbol = "PUSD"
    static let name = "Palm USD"
    static let decimals: UInt8 = 6
    static let circulationAPIBaseURL = URL(string: "https://www.palmusd.com/api")!
    static let circulationEndpointPath = "/v1/circulation"
    static let circulationHistoryEndpointPath = "/v1/circulation/history"
    static let stablecoinPegEstimateSource = "stablecoin-peg-estimate"
    static let metadataFlags = TokenMetadataFlags(
        nonFreezable: true,
        noBlacklist: true,
        noPause: true,
        standardSPL: true
    )

    static let integrationDescription = "Palm USD is a standard 6-decimal SPL stablecoin on Solana. GORKH treats it like any other token, with dedicated treasury views and safe send/receive flows."
    static let mintRedeemDescription = "Mint/redeem happens outside GORKH through Palm's permissioned perimeter. GORKH does not mint or redeem PUSD."
    static let pegEstimateDescription = "Stablecoin peg estimates are informational and not guaranteed market quotes."
}

enum PUSDPriceSource: String, Codable, Equatable {
    case jupiterPrice = "jupiter-price-v3"
    case stablecoinPegEstimate = "stablecoin-peg-estimate"
    case unavailable

    var title: String {
        switch self {
        case .jupiterPrice:
            return "Jupiter price"
        case .stablecoinPegEstimate:
            return "Stablecoin peg estimate"
        case .unavailable:
            return "Unavailable"
        }
    }

    var description: String {
        switch self {
        case .jupiterPrice:
            return "Public Jupiter market quote."
        case .stablecoinPegEstimate:
            return PUSDConstants.pegEstimateDescription
        case .unavailable:
            return "No market quote or stablecoin estimate is available."
        }
    }
}

enum PUSDSendFlow: String, Codable, Equatable {
    case existingSPLTransferApprovalFlow = "existing_spl_transfer_approval_flow"
}

enum PUSDLockedFutureAction: String, Codable, CaseIterable, Identifiable {
    case mintRedeem = "mint_redeem"
    case bridge
    case yield

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mintRedeem:
            return "Mint/redeem not supported"
        case .bridge:
            return "Bridge not supported"
        case .yield:
            return "Yield not active"
        }
    }
}

enum PUSDActionPolicy {
    static let sendFlow: PUSDSendFlow = .existingSPLTransferApprovalFlow
    static let lockedFutureActions = PUSDLockedFutureAction.allCases
}

struct PUSDWalletExposure: Codable, Equatable, Identifiable {
    var id: UUID { walletID }

    let walletID: UUID
    let walletLabel: String
    let walletPublicAddress: String
    let walletProfileKind: WalletProfileKind
    let amountRaw: UInt64
    let uiAmountString: String
    let estimatedUSD: Decimal?
    let priceSource: PUSDPriceSource

    var isWatchOnly: Bool {
        walletProfileKind == .watchOnly
    }
}

struct PUSDTreasurySummary: Codable, Equatable {
    let mintAddress: String
    let symbol: String
    let decimals: UInt8
    let totalAmountRaw: UInt64
    let uiAmountString: String
    let estimatedUSD: Decimal?
    let priceSource: PUSDPriceSource
    let priceSourceDescription: String
    let holdingWalletCount: Int
    let watchOnlyAmountRaw: UInt64
    let watchOnlyUIAmountString: String
    let watchOnlyWalletCount: Int
    let walletBreakdown: [PUSDWalletExposure]
    let sendFlow: PUSDSendFlow
    let lockedFutureActions: [PUSDLockedFutureAction]

    var hasBalance: Bool {
        totalAmountRaw > 0
    }

    static let empty = PUSDTreasurySummary(
        mintAddress: PUSDConstants.mintAddress,
        symbol: PUSDConstants.symbol,
        decimals: PUSDConstants.decimals,
        totalAmountRaw: 0,
        uiAmountString: TokenAmountFormatter.format(rawAmount: 0, decimals: PUSDConstants.decimals),
        estimatedUSD: nil,
        priceSource: .unavailable,
        priceSourceDescription: PUSDPriceSource.unavailable.description,
        holdingWalletCount: 0,
        watchOnlyAmountRaw: 0,
        watchOnlyUIAmountString: TokenAmountFormatter.format(rawAmount: 0, decimals: PUSDConstants.decimals),
        watchOnlyWalletCount: 0,
        walletBreakdown: [],
        sendFlow: PUSDActionPolicy.sendFlow,
        lockedFutureActions: PUSDActionPolicy.lockedFutureActions
    )
}

enum PUSDCirculationStatus: String, Codable, Equatable {
    case idle
    case loading
    case loaded
    case unavailable
    case rateLimited = "rate_limited"
    case error

    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .loading:
            return "Loading"
        case .loaded:
            return "Loaded"
        case .unavailable:
            return "Unavailable"
        case .rateLimited:
            return "Rate limited"
        case .error:
            return "Error"
        }
    }
}

struct PUSDChainCirculation: Codable, Equatable, Identifiable {
    var id: String { chain.lowercased() }

    let chain: String
    let amount: Decimal
}

struct PUSDCirculationSnapshot: Codable, Equatable {
    let status: PUSDCirculationStatus
    let totalCirculating: Decimal?
    let solanaCirculating: Decimal?
    let chainTotals: [PUSDChainCirculation]
    let updatedAt: Date?
    let fetchedAt: Date
    let source: String
    let errorMessage: String?

    static func idle(fetchedAt: Date = Date()) -> PUSDCirculationSnapshot {
        PUSDCirculationSnapshot(
            status: .idle,
            totalCirculating: nil,
            solanaCirculating: nil,
            chainTotals: [],
            updatedAt: nil,
            fetchedAt: fetchedAt,
            source: "\(PUSDConstants.circulationAPIBaseURL.absoluteString)\(PUSDConstants.circulationEndpointPath)",
            errorMessage: nil
        )
    }

    static func loading(fetchedAt: Date = Date()) -> PUSDCirculationSnapshot {
        PUSDCirculationSnapshot(
            status: .loading,
            totalCirculating: nil,
            solanaCirculating: nil,
            chainTotals: [],
            updatedAt: nil,
            fetchedAt: fetchedAt,
            source: "\(PUSDConstants.circulationAPIBaseURL.absoluteString)\(PUSDConstants.circulationEndpointPath)",
            errorMessage: nil
        )
    }
}
