import Foundation

enum PortfolioConstants {
    static let nativeSolMint = "So11111111111111111111111111111111111111112"
    static let priceSource = "jupiter-price-v3"
}

enum PortfolioWalletScope: String, Codable, CaseIterable, Identifiable, Equatable {
    case activeWallet = "active_wallet"
    case allWallets = "all_wallets"
    case localWallets = "local_wallets"
    case watchOnlyWallets = "watch_only_wallets"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activeWallet:
            return "Active Wallet"
        case .allWallets:
            return "All Wallets"
        case .localWallets:
            return "Local Wallets"
        case .watchOnlyWallets:
            return "Watch-only"
        }
    }
}

enum PortfolioDataStatus: String, Codable, Equatable {
    case idle
    case loading
    case loaded
    case stale
    case error

    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .loading:
            return "Loading"
        case .loaded:
            return "Loaded"
        case .stale:
            return "Stale"
        case .error:
            return "Error"
        }
    }
}

struct PortfolioPriceQuote: Codable, Equatable, Identifiable {
    var id: String { mintAddress }

    let mintAddress: String
    let usdPrice: Decimal?
    let source: String
    let blockID: UInt64?
    let priceChange24h: Decimal?
    let fetchedAt: Date
    let errorMessage: String?

    var isAvailable: Bool {
        usdPrice != nil && errorMessage == nil
    }

    func isStale(relativeTo date: Date = Date(), maxAgeSeconds: TimeInterval = 300) -> Bool {
        date.timeIntervalSince(fetchedAt) > maxAgeSeconds
    }
}

struct PortfolioAssetBalance: Codable, Equatable, Identifiable {
    var id: String { "\(walletID.uuidString):\(mintAddress):\(tokenAccountAddress ?? "native")" }

    let walletID: UUID
    let walletLabel: String
    let walletPublicAddress: String
    let walletProfileKind: WalletProfileKind
    let network: WalletNetwork
    let mintAddress: String
    let symbol: String
    let name: String
    let amountRaw: UInt64
    let decimals: UInt8?
    let uiAmountString: String
    let isNativeSOL: Bool
    let tokenAccountAddress: String?
    let tokenProgramKind: TokenProgramKind?
    let accountState: TokenAccountState?
    let warnings: [TokenWarning]
    let fetchedAt: Date

    var displayName: String {
        isNativeSOL ? "SOL - Solana" : "\(symbol) - \(name)"
    }

    var displayMint: String {
        isNativeSOL ? "Native SOL" : mintAddress.shortAddress
    }
}

struct PortfolioTokenValue: Codable, Equatable, Identifiable {
    var id: String { asset.id }

    let asset: PortfolioAssetBalance
    let priceQuote: PortfolioPriceQuote?
    let usdValue: Decimal?
    let priceUnavailableReason: String?

    var hasPrice: Bool {
        usdValue != nil
    }
}

struct PortfolioWalletSummary: Codable, Equatable, Identifiable {
    let id: UUID
    let label: String
    let publicAddress: String
    let profileKind: WalletProfileKind
    let colorTag: String?
    let network: WalletNetwork
    let assets: [PortfolioTokenValue]
    let totalUSD: Decimal
    let unavailablePriceCount: Int
    let fetchedAt: Date
    let errorMessage: String?

    var solBalance: PortfolioTokenValue? {
        assets.first { $0.asset.isNativeSOL }
    }

    var splTokenCount: Int {
        assets.filter { !$0.asset.isNativeSOL }.count
    }

    var isWatchOnly: Bool {
        profileKind == .watchOnly
    }
}

struct PortfolioConsolidatedAsset: Codable, Equatable, Identifiable {
    var id: String { mintAddress }

    let mintAddress: String
    let symbol: String
    let name: String
    let decimals: UInt8?
    let totalAmountRaw: UInt64
    let uiAmountString: String
    let totalUSD: Decimal?
    let priceQuote: PortfolioPriceQuote?
    let walletBreakdown: [PortfolioTokenValue]
    let unavailablePriceCount: Int
    let warnings: [TokenWarning]

    var isNativeSOL: Bool {
        mintAddress == PortfolioConstants.nativeSolMint
    }
}

struct PortfolioAggregateSummary: Codable, Equatable {
    let scope: PortfolioWalletScope
    let network: WalletNetwork
    let wallets: [PortfolioWalletSummary]
    let consolidatedAssets: [PortfolioConsolidatedAsset]
    let totalUSD: Decimal
    let unavailablePriceCount: Int
    let assetCount: Int
    let priceSource: String
    let status: PortfolioDataStatus
    let refreshedAt: Date
    let errorMessage: String?

    static func empty(scope: PortfolioWalletScope = .activeWallet, network: WalletNetwork = .devnet) -> PortfolioAggregateSummary {
        PortfolioAggregateSummary(
            scope: scope,
            network: network,
            wallets: [],
            consolidatedAssets: [],
            totalUSD: 0,
            unavailablePriceCount: 0,
            assetCount: 0,
            priceSource: PortfolioConstants.priceSource,
            status: .idle,
            refreshedAt: Date(),
            errorMessage: nil
        )
    }
}

struct PortfolioSnapshotAsset: Codable, Equatable, Identifiable {
    var id: String { "\(walletPublicAddress):\(mintAddress):\(tokenAccountAddress ?? "native")" }

    let walletPublicAddress: String
    let walletLabel: String
    let walletKind: WalletProfileKind
    let network: WalletNetwork
    let mintAddress: String
    let tokenAccountAddress: String?
    let symbol: String
    let amountRaw: UInt64
    let uiAmountString: String
    let usdValue: Decimal?
    let priceSource: String
    let priceUnavailable: Bool
}

struct PortfolioSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let scope: PortfolioWalletScope
    let network: WalletNetwork
    let totalUSD: Decimal
    let walletCount: Int
    let assetCount: Int
    let unavailablePriceCount: Int
    let priceSource: String
    let assets: [PortfolioSnapshotAsset]

    init(id: UUID = UUID(), summary: PortfolioAggregateSummary, createdAt: Date = Date()) {
        self.id = id
        self.createdAt = createdAt
        self.scope = summary.scope
        self.network = summary.network
        self.totalUSD = summary.totalUSD
        self.walletCount = summary.wallets.count
        self.assetCount = summary.assetCount
        self.unavailablePriceCount = summary.unavailablePriceCount
        self.priceSource = summary.priceSource
        self.assets = summary.wallets.flatMap { wallet in
            wallet.assets.map { value in
                PortfolioSnapshotAsset(
                    walletPublicAddress: wallet.publicAddress,
                    walletLabel: wallet.label,
                    walletKind: wallet.profileKind,
                    network: wallet.network,
                    mintAddress: value.asset.mintAddress,
                    tokenAccountAddress: value.asset.tokenAccountAddress,
                    symbol: value.asset.symbol,
                    amountRaw: value.asset.amountRaw,
                    uiAmountString: value.asset.uiAmountString,
                    usdValue: value.usdValue,
                    priceSource: value.priceQuote?.source ?? summary.priceSource,
                    priceUnavailable: value.usdValue == nil
                )
            }
        }
    }
}

struct PortfolioHistoryPoint: Codable, Equatable, Identifiable {
    var id: UUID { snapshotID }

    let snapshotID: UUID
    let createdAt: Date
    let totalUSD: Decimal
    let walletCount: Int
    let assetCount: Int
    let unavailablePriceCount: Int

    init(snapshot: PortfolioSnapshot) {
        self.snapshotID = snapshot.id
        self.createdAt = snapshot.createdAt
        self.totalUSD = snapshot.totalUSD
        self.walletCount = snapshot.walletCount
        self.assetCount = snapshot.assetCount
        self.unavailablePriceCount = snapshot.unavailablePriceCount
    }
}

extension Decimal {
    var portfolioCurrencyText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = self >= 1 ? 2 : 6
        return formatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }
}
