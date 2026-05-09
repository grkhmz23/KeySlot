import Foundation

enum KaminoConstants {
    static let baseURL = URL(string: "https://api.kamino.finance")!
    static let apiSource = "kamino-public-api"
    static let mainnetEnv = "mainnet-beta"
}

struct KaminoMarketConfig: Codable, Equatable, Identifiable {
    var id: String { lendingMarket }

    let name: String
    let isPrimary: Bool
    let description: String?
    let lendingMarket: String
    let lookupTable: String?
    let isCurated: Bool?
}

struct KaminoReserveMetric: Codable, Equatable {
    let reserve: String
    let liquidityToken: String
    let liquidityTokenMint: String
    let maxLtv: String?
    let borrowApy: String?
    let supplyApy: String?
    let totalSupply: String?
    let totalBorrow: String?
    let totalBorrowUsd: String?
    let totalSupplyUsd: String?

    func marketSummary(market: KaminoMarketConfig, updatedAt: Date) -> LendingMarketReserveSummary {
        let totalSupplyDecimal = KaminoDecimalParser.decimal(totalSupply)
        let totalBorrowDecimal = KaminoDecimalParser.decimal(totalBorrow)
        let utilization: Decimal?
        if let totalSupplyDecimal, totalSupplyDecimal > 0, let totalBorrowDecimal {
            utilization = totalBorrowDecimal / totalSupplyDecimal
        } else {
            utilization = nil
        }

        return LendingMarketReserveSummary(
            protocolKind: .kamino,
            marketName: market.name,
            marketAddress: market.lendingMarket,
            reserveAddress: reserve,
            symbol: liquidityToken,
            mintAddress: liquidityTokenMint,
            supplyAPY: KaminoDecimalParser.decimal(supplyApy),
            borrowAPY: KaminoDecimalParser.decimal(borrowApy),
            maxLTV: KaminoDecimalParser.decimal(maxLtv),
            totalSupply: totalSupplyDecimal,
            totalBorrow: totalBorrowDecimal,
            totalSupplyUSD: KaminoDecimalParser.decimal(totalSupplyUsd),
            totalBorrowUSD: KaminoDecimalParser.decimal(totalBorrowUsd),
            utilization: utilization,
            source: .publicAPI,
            updatedAt: updatedAt
        )
    }
}

struct KaminoUserObligation: Equatable {
    let obligationAddress: String
    let marketAddress: String
    let deposits: [KaminoObligationAsset]
    let borrows: [KaminoObligationAsset]
    let userTotalDepositUSD: Decimal?
    let userTotalBorrowUSD: Decimal?
    let netAccountValueUSD: Decimal?
    let loanToValue: Decimal?
    let borrowUtilization: Decimal?
}

struct KaminoObligationAsset: Equatable {
    enum Side: Equatable {
        case deposit
        case borrow
    }

    let side: Side
    let reserveAddress: String
    let rawAmount: UInt64?
    let uiAmountString: String
    let usdValue: Decimal?
}

enum KaminoDecimalParser {
    nonisolated static func decimal(_ value: Any?) -> Decimal? {
        if let decimal = value as? Decimal {
            return decimal
        }
        if let number = value as? NSNumber {
            return number.decimalValue
        }
        guard let string = value as? String else {
            return nil
        }
        let number = NSDecimalNumber(string: string, locale: Locale(identifier: "en_US_POSIX"))
        guard number != .notANumber else {
            return nil
        }
        return number.decimalValue
    }

    nonisolated static func uint64(_ value: Any?) -> UInt64? {
        if let number = value as? NSNumber {
            return number.uint64Value
        }
        if let string = value as? String {
            return UInt64(string)
        }
        return nil
    }
}
