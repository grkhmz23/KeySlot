import Foundation

enum LSTDataAvailability: String, Codable, Equatable {
    case available
    case priceOnly
    case unavailable
    case stale

    var title: String {
        switch self {
        case .available:
            return "Available"
        case .priceOnly:
            return "Price only"
        case .unavailable:
            return "Unavailable"
        case .stale:
            return "Stale"
        }
    }
}

struct LSTKnownToken: Codable, Equatable, Identifiable {
    var id: String { mintAddress }

    let mintAddress: String
    let symbol: String
    let name: String
    let network: WalletNetwork
    let decimals: UInt8?
    let riskNote: String
}

struct LSTHoldingSummary: Codable, Equatable, Identifiable {
    var id: String { mintAddress }

    let mintAddress: String
    let symbol: String
    let name: String
    let amountRaw: UInt64
    let decimals: UInt8?
    let uiAmountString: String
    let estimatedUSD: Decimal?
    let priceQuote: PortfolioPriceQuote?
    let walletBreakdown: [PortfolioTokenValue]
    let dataSource: String
    let priceUnavailable: Bool
}

struct LSTComparisonEntry: Codable, Equatable, Identifiable {
    var id: String { mintAddress }

    let mintAddress: String
    let symbol: String
    let name: String
    let holdingAmountRaw: UInt64
    let uiAmountString: String
    let estimatedUSD: Decimal?
    let exchangeRate: Decimal?
    let apy: Decimal?
    let tvlUSD: Decimal?
    let priceQuote: PortfolioPriceQuote?
    let dataSource: String
    let availability: LSTDataAvailability
    let unavailableReason: String?
    let riskNote: String
}

struct LSTPortfolioSummary: Codable, Equatable {
    let holdings: [LSTHoldingSummary]
    let comparison: [LSTComparisonEntry]
    let totalUSD: Decimal?
    let holdingCount: Int
    let priceUnavailableCount: Int
    let dataSource: String
    let refreshedAt: Date

    static func empty(dataSource: String = PortfolioConstants.priceSource) -> LSTPortfolioSummary {
        LSTPortfolioSummary(
            holdings: [],
            comparison: [],
            totalUSD: nil,
            holdingCount: 0,
            priceUnavailableCount: 0,
            dataSource: dataSource,
            refreshedAt: Date()
        )
    }
}
