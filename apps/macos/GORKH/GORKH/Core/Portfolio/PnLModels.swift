import Foundation

enum PnLConstants {
    static let source = "portfolio-snapshot-performance"
    static let notTaxGradeCopy = "Portfolio performance is an estimate from local wallet snapshots. It is not tax-grade accounting."
    static let costBasisMissingReason = "Manual cost basis is needed before unrealized PnL can be completed."
    static let realizedUnavailableReason = "Realized PnL unavailable - insufficient cost basis or disposal history."
    static let unrealizedPartialReason = "Unrealized PnL partial - cost basis is missing for one or more assets."
}

enum PnLTimeframe: String, Codable, CaseIterable, Identifiable, Equatable {
    case twentyFourHours = "24h"
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case all
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twentyFourHours:
            return "24h"
        case .sevenDays:
            return "7d"
        case .thirtyDays:
            return "30d"
        case .all:
            return "All"
        case .custom:
            return "Custom"
        }
    }

    var lookbackSeconds: TimeInterval? {
        switch self {
        case .twentyFourHours:
            return 24 * 60 * 60
        case .sevenDays:
            return 7 * 24 * 60 * 60
        case .thirtyDays:
            return 30 * 24 * 60 * 60
        case .all, .custom:
            return nil
        }
    }
}

enum PnLSource: String, Codable, CaseIterable, Identifiable, Equatable {
    case portfolioSnapshot = "portfolio_snapshot"
    case swapActivity = "swap_activity"
    case sendActivity = "send_activity"
    case manualCostBasis = "manual_cost_basis"
    case priceEstimate = "price_estimate"
    case unavailable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portfolioSnapshot:
            return "Portfolio snapshots"
        case .swapActivity:
            return "GORKH swap activity"
        case .sendActivity:
            return "GORKH send activity"
        case .manualCostBasis:
            return "Manual cost basis"
        case .priceEstimate:
            return "Price estimate"
        case .unavailable:
            return "Unavailable"
        }
    }
}

enum PnLDataStatus: String, Codable, CaseIterable, Identifiable, Equatable {
    case loaded
    case partial
    case unavailable
    case stale
    case error

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loaded:
            return "Loaded"
        case .partial:
            return "Partial"
        case .unavailable:
            return "Unavailable"
        case .stale:
            return "Stale"
        case .error:
            return "Error"
        }
    }
}

struct PnLTimeframePerformance: Codable, Equatable, Identifiable {
    var id: PnLTimeframe { timeframe }

    let timeframe: PnLTimeframe
    let currentValueUSD: Decimal?
    let baselineValueUSD: Decimal?
    let valueDeltaUSD: Decimal?
    let percentageDelta: Decimal?
    let baselineTimestamp: Date?
    let currentTimestamp: Date
    let missingPriceImpactCount: Int
    let walletCount: Int
    let assetCount: Int
    let source: PnLSource
    let status: PnLDataStatus
    let reason: String?
}

struct PnLAssetPerformance: Codable, Equatable, Identifiable {
    var id: String { "\(walletScope.rawValue):\(tokenMint)" }

    let walletScope: PortfolioWalletScope
    let tokenMint: String
    let tokenSymbol: String
    let currentAmountRaw: UInt64
    let previousAmountRaw: UInt64?
    let amountDeltaRaw: Decimal?
    let currentValueUSD: Decimal?
    let previousValueUSD: Decimal?
    let valueDeltaUSD: Decimal?
    let percentageDelta: Decimal?
    let priceSource: String
    let source: PnLSource
    let timestamp: Date
    let status: PnLDataStatus
    let reason: String?
}

struct PnLWalletPerformance: Codable, Equatable, Identifiable {
    var id: String { walletPublicAddress }

    let walletPublicAddress: String
    let walletLabel: String
    let walletKind: WalletProfileKind
    let currentValueUSD: Decimal?
    let previousValueUSD: Decimal?
    let valueDeltaUSD: Decimal?
    let percentageDelta: Decimal?
    let assetCount: Int
    let missingPriceCount: Int
    let source: PnLSource
    let timestamp: Date
    let status: PnLDataStatus
    let reason: String?
}

struct PnLRealizedSummary: Codable, Equatable {
    let estimatedUSD: Decimal?
    let disposalEventCount: Int
    let matchedCostBasisEventCount: Int
    let source: PnLSource
    let status: PnLDataStatus
    let reason: String

    static func unavailable(disposalEventCount: Int = 0) -> PnLRealizedSummary {
        PnLRealizedSummary(
            estimatedUSD: nil,
            disposalEventCount: disposalEventCount,
            matchedCostBasisEventCount: 0,
            source: .unavailable,
            status: .unavailable,
            reason: PnLConstants.realizedUnavailableReason
        )
    }
}

struct PnLUnrealizedSummary: Codable, Equatable {
    let estimatedUSD: Decimal?
    let coveredAssetCount: Int
    let missingCostBasisAssetCount: Int
    let source: PnLSource
    let status: PnLDataStatus
    let reason: String?
}

struct PnLComparisonSnapshot: Codable, Equatable {
    let generatedAt: Date
    let timeframe: PnLTimeframe
    let currentValueUSD: Decimal?
    let baselineValueUSD: Decimal?
    let valueDeltaUSD: Decimal?
    let percentageDelta: Decimal?
    let assetPerformanceCount: Int
    let walletPerformanceCount: Int
    let costBasisEntryCount: Int
    let status: PnLDataStatus
    let source: PnLSource
}

struct PnLSwapActivityHint: Codable, Equatable, Identifiable {
    var id: String { signature ?? "\(walletPublicAddress):\(timestamp.timeIntervalSince1970):\(inputMint):\(outputMint)" }

    let walletPublicAddress: String
    let signature: String?
    let inputMint: String
    let outputMint: String
    let inputAmountRaw: String
    let outputAmountRaw: String?
    let feeLamports: String?
    let timestamp: Date
    let source: PnLSource
    let status: PnLDataStatus
    let reason: String?
}

struct PnLPortfolioSummary: Codable, Equatable {
    let generatedAt: Date
    let scope: PortfolioWalletScope
    let network: WalletNetwork
    let currentValueUSD: Decimal?
    let currentWalletCount: Int
    let currentAssetCount: Int
    let primaryTimeframe: PnLTimeframe
    let timeframePerformances: [PnLTimeframePerformance]
    let assetPerformances: [PnLAssetPerformance]
    let walletPerformances: [PnLWalletPerformance]
    let realized: PnLRealizedSummary
    let unrealized: PnLUnrealizedSummary
    let costBasisCoverage: CostBasisCoverage
    let swapActivityHintCount: Int
    let historyPointCount: Int
    let source: PnLSource
    let status: PnLDataStatus
    let reason: String?

    var primaryPerformance: PnLTimeframePerformance? {
        timeframePerformances.first { $0.timeframe == primaryTimeframe }
    }

    static func empty(
        scope: PortfolioWalletScope = .activeWallet,
        network: WalletNetwork = .devnet,
        generatedAt: Date = Date()
    ) -> PnLPortfolioSummary {
        PnLPortfolioSummary(
            generatedAt: generatedAt,
            scope: scope,
            network: network,
            currentValueUSD: nil,
            currentWalletCount: 0,
            currentAssetCount: 0,
            primaryTimeframe: .thirtyDays,
            timeframePerformances: [],
            assetPerformances: [],
            walletPerformances: [],
            realized: .unavailable(),
            unrealized: PnLUnrealizedSummary(
                estimatedUSD: nil,
                coveredAssetCount: 0,
                missingCostBasisAssetCount: 0,
                source: .unavailable,
                status: .unavailable,
                reason: PnLConstants.costBasisMissingReason
            ),
            costBasisCoverage: .unavailable(),
            swapActivityHintCount: 0,
            historyPointCount: 0,
            source: .unavailable,
            status: .unavailable,
            reason: "Refresh Portfolio to create local snapshots before PnL can be estimated."
        )
    }
}
