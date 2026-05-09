import Foundation

enum LendingConstants {
    static let source = "read-only-lending-adapters"
    static let noDoubleCountNotice = "Lending values are shown separately from wallet token balances to avoid double-counting."
}

enum LendingProtocolKind: String, Codable, CaseIterable, Identifiable, Equatable {
    case kamino
    case marginFi = "marginfi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kamino:
            return "Kamino"
        case .marginFi:
            return "MarginFi"
        }
    }
}

enum LendingAdapterStatus: String, Codable, Equatable {
    case idle
    case loaded
    case empty
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
        case .unavailable:
            return "Unavailable"
        case .error:
            return "Error"
        case .stale:
            return "Stale"
        }
    }
}

enum LendingDataSource: String, Codable, Equatable {
    case solanaRPC = "solana-rpc"
    case publicAPI = "public-api"
    case sdkReadOnly = "sdk-read-only"
    case unavailable
}

enum LendingRiskLevel: String, Codable, Equatable {
    case healthy
    case caution
    case highRisk = "high_risk"
    case liquidationRisk = "liquidation_risk"
    case unavailable

    var title: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .caution:
            return "Caution"
        case .highRisk:
            return "High Risk"
        case .liquidationRisk:
            return "Liquidation Risk"
        case .unavailable:
            return "Unavailable"
        }
    }
}

enum LendingLockedAction: String, Codable, CaseIterable, Identifiable, Equatable {
    case deposit
    case borrow
    case repay
    case withdraw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deposit:
            return "Deposit locked"
        case .borrow:
            return "Borrow locked"
        case .repay:
            return "Repay locked"
        case .withdraw:
            return "Withdraw locked"
        }
    }

    var isEnabled: Bool {
        false
    }
}

struct LendingAssetAmount: Codable, Equatable, Identifiable {
    var id: String { "\(mintAddress):\(symbol)" }

    let mintAddress: String
    let symbol: String
    let name: String
    let amountRaw: UInt64
    let decimals: UInt8?
    let uiAmountString: String
    let usdValue: Decimal?
    let priceQuote: PortfolioPriceQuote?
    let source: LendingDataSource
}

struct LendingHealthSummary: Codable, Equatable {
    let ltv: Decimal?
    let liquidationThreshold: Decimal?
    let healthFactor: Decimal?
    let riskLevel: LendingRiskLevel
    let unavailableReason: String?

    static let unavailable = LendingHealthSummary(
        ltv: nil,
        liquidationThreshold: nil,
        healthFactor: nil,
        riskLevel: .unavailable,
        unavailableReason: "Health factor and LTV are unavailable from the read-only adapter."
    )

    static func riskLevel(healthFactor: Decimal?, ltv: Decimal?) -> LendingRiskLevel {
        if let healthFactor {
            if healthFactor <= Decimal(string: "1.05")! {
                return .liquidationRisk
            }
            if healthFactor <= Decimal(string: "1.20")! {
                return .highRisk
            }
            if healthFactor <= Decimal(string: "1.50")! {
                return .caution
            }
            return .healthy
        }

        if let ltv {
            if ltv >= Decimal(string: "0.90")! {
                return .liquidationRisk
            }
            if ltv >= Decimal(string: "0.75")! {
                return .highRisk
            }
            if ltv >= Decimal(string: "0.60")! {
                return .caution
            }
            return .healthy
        }

        return .unavailable
    }
}

struct LendingPositionSummary: Codable, Equatable, Identifiable {
    var id: String { "\(protocolKind.rawValue):\(walletID.uuidString)" }

    let walletID: UUID
    let walletLabel: String
    let walletPublicAddress: String
    let network: WalletNetwork
    let protocolKind: LendingProtocolKind
    let suppliedAssets: [LendingAssetAmount]
    let borrowedAssets: [LendingAssetAmount]
    let netValueUSD: Decimal?
    let health: LendingHealthSummary
    let source: LendingDataSource
    let updatedAt: Date
    let status: LendingAdapterStatus
    let errorMessage: String?

    var suppliedValueUSD: Decimal? {
        aggregate(values: suppliedAssets.compactMap(\.usdValue), expectedCount: suppliedAssets.count)
    }

    var borrowedValueUSD: Decimal? {
        aggregate(values: borrowedAssets.compactMap(\.usdValue), expectedCount: borrowedAssets.count)
    }

    private func aggregate(values: [Decimal], expectedCount: Int) -> Decimal? {
        guard expectedCount > 0 else {
            return 0
        }
        guard values.count == expectedCount else {
            return nil
        }
        return values.reduce(Decimal(0), +)
    }
}

struct LendingAdapterResult: Codable, Equatable {
    let protocolKind: LendingProtocolKind
    let status: LendingAdapterStatus
    let positions: [LendingPositionSummary]
    let source: LendingDataSource
    let updatedAt: Date
    let errorMessage: String?

    static func unavailable(
        protocolKind: LendingProtocolKind,
        reason: String,
        updatedAt: Date = Date()
    ) -> LendingAdapterResult {
        LendingAdapterResult(
            protocolKind: protocolKind,
            status: .unavailable,
            positions: [],
            source: .unavailable,
            updatedAt: updatedAt,
            errorMessage: reason
        )
    }
}

struct LendingProtocolSummary: Codable, Equatable, Identifiable {
    var id: String { protocolKind.rawValue }

    let protocolKind: LendingProtocolKind
    let status: LendingAdapterStatus
    let positions: [LendingPositionSummary]
    let suppliedValueUSD: Decimal?
    let borrowedValueUSD: Decimal?
    let netValueUSD: Decimal?
    let riskyPositionCount: Int
    let walletCount: Int
    let source: LendingDataSource
    let updatedAt: Date
    let errorMessage: String?
}

struct LendingPortfolioSummary: Codable, Equatable {
    let status: LendingAdapterStatus
    let protocols: [LendingProtocolSummary]
    let suppliedValueUSD: Decimal?
    let borrowedValueUSD: Decimal?
    let netValueUSD: Decimal?
    let positionCount: Int
    let riskyPositionCount: Int
    let unavailableAdapterCount: Int
    let source: String
    let noDoubleCountNotice: String
    let refreshedAt: Date
    let errorMessage: String?

    static func empty(status: LendingAdapterStatus = .idle) -> LendingPortfolioSummary {
        LendingPortfolioSummary(
            status: status,
            protocols: [],
            suppliedValueUSD: 0,
            borrowedValueUSD: 0,
            netValueUSD: 0,
            positionCount: 0,
            riskyPositionCount: 0,
            unavailableAdapterCount: 0,
            source: LendingConstants.source,
            noDoubleCountNotice: LendingConstants.noDoubleCountNotice,
            refreshedAt: Date(),
            errorMessage: nil
        )
    }
}
