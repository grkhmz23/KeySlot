import Foundation

enum YieldConstants {
    static let source = "portfolio-yield-comparison"
    static let noDoubleCountNotice = "Yield exposure is shown separately from wallet token balances to avoid double-counting."
    static let unavailableRateReason = "APY/APR is unavailable from the connected read-only data source."
    static let pusdYieldUnavailableReason = "PUSD yield is not active in KeySlot."
}

enum YieldSourceKind: String, Codable, CaseIterable, Identifiable, Equatable {
    case lst
    case lending
    case lp
    case stablecoin
    case unavailable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lst:
            return "LST"
        case .lending:
            return "Lending"
        case .lp:
            return "LP"
        case .stablecoin:
            return "Stablecoin"
        case .unavailable:
            return "Unavailable"
        }
    }
}

enum YieldProtocol: String, Codable, CaseIterable, Identifiable, Equatable {
    case jito
    case marinade
    case blazeStake = "blazestake"
    case bybitStakedSol = "bybit_staked_sol"
    case kamino
    case marginFi = "marginfi"
    case meteora
    case orca
    case raydium
    case palmUSD = "palm_usd"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .jito:
            return "Jito"
        case .marinade:
            return "Marinade"
        case .blazeStake:
            return "BlazeStake"
        case .bybitStakedSol:
            return "Bybit Staked SOL"
        case .kamino:
            return "Kamino"
        case .marginFi:
            return "MarginFi"
        case .meteora:
            return "Meteora"
        case .orca:
            return "Orca"
        case .raydium:
            return "Raydium"
        case .palmUSD:
            return "Palm USD"
        }
    }
}

enum YieldRateKind: String, Codable, Equatable {
    case apy
    case apr

    var title: String {
        switch self {
        case .apy:
            return "APY"
        case .apr:
            return "APR"
        }
    }
}

struct YieldRate: Codable, Equatable {
    let kind: YieldRateKind
    let value: Decimal?
    let base: Decimal?
    let reward: Decimal?
    let fee: Decimal?
    let source: String
    let updatedAt: Date
    let unavailableReason: String?

    static func unavailable(source: String, updatedAt: Date, reason: String = YieldConstants.unavailableRateReason) -> YieldRate {
        YieldRate(
            kind: .apy,
            value: nil,
            base: nil,
            reward: nil,
            fee: nil,
            source: source,
            updatedAt: updatedAt,
            unavailableReason: reason
        )
    }
}

enum YieldRiskLevel: String, Codable, Equatable {
    case low
    case medium
    case high
    case unavailable

    var title: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .unavailable:
            return "Unavailable"
        }
    }
}

enum YieldDataStatus: String, Codable, Equatable {
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

struct YieldHolding: Codable, Equatable, Identifiable {
    var id: String { "\(protocolKind.rawValue):\(sourceKind.rawValue):\(walletScope.rawValue):\(assetMint ?? label)" }

    let protocolKind: YieldProtocol
    let sourceKind: YieldSourceKind
    let assetMint: String?
    let label: String
    let walletScope: PortfolioWalletScope
    let heldAmountRaw: UInt64?
    let heldAmount: String?
    let estimatedUSD: Decimal?
    let source: String
    let updatedAt: Date
    let status: YieldDataStatus
    let unavailableReason: String?
}

struct YieldOpportunity: Codable, Equatable, Identifiable {
    var id: String { "\(protocolKind.rawValue):\(sourceKind.rawValue):\(assetMint ?? label):\(sourceEndpoint)" }

    let protocolKind: YieldProtocol
    let sourceKind: YieldSourceKind
    let assetMint: String?
    let label: String
    let walletScope: PortfolioWalletScope
    let isHeld: Bool
    let heldAmountRaw: UInt64?
    let heldAmount: String?
    let estimatedUSD: Decimal?
    let rate: YieldRate
    let tvlUSD: Decimal?
    let sourceEndpoint: String
    let updatedAt: Date
    let status: YieldDataStatus
    let riskLevel: YieldRiskLevel
    let unavailableReason: String?
}

struct YieldComparisonSnapshot: Codable, Equatable {
    let totalYieldExposureUSD: Decimal?
    let heldOpportunityCount: Int
    let apyAvailableCount: Int
    let unavailableCount: Int
    let topYieldSourceLabel: String?
    let timestamp: Date
}

struct YieldPortfolioSummary: Codable, Equatable {
    let status: YieldDataStatus
    let opportunities: [YieldOpportunity]
    let holdings: [YieldHolding]
    let totalYieldExposureUSD: Decimal?
    let heldOpportunityCount: Int
    let apyAvailableCount: Int
    let unavailableCount: Int
    let topYieldSourceLabel: String?
    let source: String
    let noDoubleCountNotice: String
    let refreshedAt: Date
    let errorMessage: String?

    var snapshot: YieldComparisonSnapshot {
        YieldComparisonSnapshot(
            totalYieldExposureUSD: totalYieldExposureUSD,
            heldOpportunityCount: heldOpportunityCount,
            apyAvailableCount: apyAvailableCount,
            unavailableCount: unavailableCount,
            topYieldSourceLabel: topYieldSourceLabel,
            timestamp: refreshedAt
        )
    }

    static func empty(status: YieldDataStatus = .idle, refreshedAt: Date = Date()) -> YieldPortfolioSummary {
        YieldPortfolioSummary(
            status: status,
            opportunities: [],
            holdings: [],
            totalYieldExposureUSD: 0,
            heldOpportunityCount: 0,
            apyAvailableCount: 0,
            unavailableCount: 0,
            topYieldSourceLabel: nil,
            source: YieldConstants.source,
            noDoubleCountNotice: YieldConstants.noDoubleCountNotice,
            refreshedAt: refreshedAt,
            errorMessage: nil
        )
    }
}
