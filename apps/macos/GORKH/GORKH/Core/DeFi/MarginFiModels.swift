import Foundation

enum MarginFiConstants {
    static let programID = "MFv2hWf31Z9kbCa1snEPYctwafyhdvnV7FZnsebVacA"
    static let mainGroupID = "4qp6Fx6tnZkY5Wropq9wUYgtFxXKwE6viZxFHg3rdAG8"
    static let source = "marginfi-v2-on-chain-read-only-parser"
    static let unsupportedNetworkReason = "MarginFi v2 read-only status is mainnet-beta only."
    static let positionParsingUnavailableReason = """
    MarginFi v2 program is reachable on mainnet-beta, but no MarginFi accounts were found for this wallet through bounded read-only authority filters.
    """
    static let partialParsingReason = """
    MarginFi account data was parsed from public on-chain accounts. Bank metadata, token values, LTV, and health are unavailable until the bank/oracle parser is audited.
    """
}

struct MarginFiAdapterMetadata: Codable, Equatable {
    let programID: String
    let groupID: String
    let network: WalletNetwork
    let programAccountReachable: Bool
    let source: LendingDataSource
    let updatedAt: Date
    let unavailableReason: String?
}

struct MarginFiAccountSummary: Codable, Equatable, Identifiable {
    var id: String { accountAddress }

    let accountAddress: String
    let walletPublicAddress: String
    let groupAddress: String
    let suppliedAssets: [MarginFiPositionAsset]
    let borrowedAssets: [MarginFiPositionAsset]
    let health: MarginFiHealthSummary
    let updatedAt: Date
    let source: LendingDataSource
}

struct MarginFiBankSummary: Codable, Equatable, Identifiable {
    var id: String { bankAddress }

    let bankAddress: String
    let groupAddress: String
    let mintAddress: String
    let symbol: String?
    let totalSupplied: Decimal?
    let totalBorrowed: Decimal?
    let supplyAPY: Decimal?
    let borrowAPY: Decimal?
    let updatedAt: Date
    let source: LendingDataSource
}

struct MarginFiPositionAsset: Codable, Equatable, Identifiable {
    var id: String { "\(mintAddress):\(side.rawValue)" }

    enum Side: String, Codable, Equatable {
        case supplied
        case borrowed
    }

    let side: Side
    let mintAddress: String
    let symbol: String?
    let amountRaw: UInt64?
    let uiAmountString: String?
    let usdValue: Decimal?
    let source: LendingDataSource
}

struct MarginFiHealthSummary: Codable, Equatable {
    let ltv: Decimal?
    let healthFactor: Decimal?
    let riskLevel: LendingRiskLevel
    let unavailableReason: String?
}
