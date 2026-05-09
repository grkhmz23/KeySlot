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
    let liquidSolLamports: UInt64
    let liquidAssetsUSD: Decimal
    let nativeStakeSummary: StakePortfolioSummary
    let lstSummary: LSTPortfolioSummary
    let lendingSummary: LendingPortfolioSummary
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
            liquidSolLamports: 0,
            liquidAssetsUSD: 0,
            nativeStakeSummary: .empty(),
            lstSummary: .empty(),
            lendingSummary: .empty(),
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
    let nativeStakeLamports: UInt64
    let activeStakeLamports: UInt64
    let activatingStakeLamports: UInt64
    let deactivatingStakeLamports: UInt64
    let inactiveStakeLamports: UInt64
    let stakeAccountCount: Int
    let lstHoldingCount: Int
    let lstEstimatedUSD: Decimal?
    let lendingSuppliedValueUSD: Decimal?
    let lendingBorrowedValueUSD: Decimal?
    let lendingNetValueUSD: Decimal?
    let lendingPositionCount: Int
    let lendingRiskyPositionCount: Int
    let lendingUnavailableAdapterCount: Int
    let lendingMarketReserveCount: Int
    let lendingProtocolStatuses: [String: String]
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
        self.nativeStakeLamports = summary.nativeStakeSummary.totalDelegatedLamports
        self.activeStakeLamports = summary.nativeStakeSummary.activeLamports
        self.activatingStakeLamports = summary.nativeStakeSummary.activatingLamports
        self.deactivatingStakeLamports = summary.nativeStakeSummary.deactivatingLamports
        self.inactiveStakeLamports = summary.nativeStakeSummary.inactiveLamports
        self.stakeAccountCount = summary.nativeStakeSummary.accountCount
        self.lstHoldingCount = summary.lstSummary.holdingCount
        self.lstEstimatedUSD = summary.lstSummary.totalUSD
        self.lendingSuppliedValueUSD = summary.lendingSummary.suppliedValueUSD
        self.lendingBorrowedValueUSD = summary.lendingSummary.borrowedValueUSD
        self.lendingNetValueUSD = summary.lendingSummary.netValueUSD
        self.lendingPositionCount = summary.lendingSummary.positionCount
        self.lendingRiskyPositionCount = summary.lendingSummary.riskyPositionCount
        self.lendingUnavailableAdapterCount = summary.lendingSummary.unavailableAdapterCount
        self.lendingMarketReserveCount = summary.lendingSummary.marketReserveCount
        self.lendingProtocolStatuses = Dictionary(uniqueKeysWithValues: summary.lendingSummary.protocols.map {
            ($0.protocolKind.rawValue, $0.status.rawValue)
        })
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

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case scope
        case network
        case totalUSD
        case walletCount
        case assetCount
        case unavailablePriceCount
        case priceSource
        case nativeStakeLamports
        case activeStakeLamports
        case activatingStakeLamports
        case deactivatingStakeLamports
        case inactiveStakeLamports
        case stakeAccountCount
        case lstHoldingCount
        case lstEstimatedUSD
        case lendingSuppliedValueUSD
        case lendingBorrowedValueUSD
        case lendingNetValueUSD
        case lendingPositionCount
        case lendingRiskyPositionCount
        case lendingUnavailableAdapterCount
        case lendingMarketReserveCount
        case lendingProtocolStatuses
        case assets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        scope = try container.decode(PortfolioWalletScope.self, forKey: .scope)
        network = try container.decode(WalletNetwork.self, forKey: .network)
        totalUSD = try container.decode(Decimal.self, forKey: .totalUSD)
        walletCount = try container.decode(Int.self, forKey: .walletCount)
        assetCount = try container.decode(Int.self, forKey: .assetCount)
        unavailablePriceCount = try container.decode(Int.self, forKey: .unavailablePriceCount)
        priceSource = try container.decode(String.self, forKey: .priceSource)
        nativeStakeLamports = try container.decodeIfPresent(UInt64.self, forKey: .nativeStakeLamports) ?? 0
        activeStakeLamports = try container.decodeIfPresent(UInt64.self, forKey: .activeStakeLamports) ?? 0
        activatingStakeLamports = try container.decodeIfPresent(UInt64.self, forKey: .activatingStakeLamports) ?? 0
        deactivatingStakeLamports = try container.decodeIfPresent(UInt64.self, forKey: .deactivatingStakeLamports) ?? 0
        inactiveStakeLamports = try container.decodeIfPresent(UInt64.self, forKey: .inactiveStakeLamports) ?? 0
        stakeAccountCount = try container.decodeIfPresent(Int.self, forKey: .stakeAccountCount) ?? 0
        lstHoldingCount = try container.decodeIfPresent(Int.self, forKey: .lstHoldingCount) ?? 0
        lstEstimatedUSD = try container.decodeIfPresent(Decimal.self, forKey: .lstEstimatedUSD)
        lendingSuppliedValueUSD = try container.decodeIfPresent(Decimal.self, forKey: .lendingSuppliedValueUSD)
        lendingBorrowedValueUSD = try container.decodeIfPresent(Decimal.self, forKey: .lendingBorrowedValueUSD)
        lendingNetValueUSD = try container.decodeIfPresent(Decimal.self, forKey: .lendingNetValueUSD)
        lendingPositionCount = try container.decodeIfPresent(Int.self, forKey: .lendingPositionCount) ?? 0
        lendingRiskyPositionCount = try container.decodeIfPresent(Int.self, forKey: .lendingRiskyPositionCount) ?? 0
        lendingUnavailableAdapterCount = try container.decodeIfPresent(Int.self, forKey: .lendingUnavailableAdapterCount) ?? 0
        lendingMarketReserveCount = try container.decodeIfPresent(Int.self, forKey: .lendingMarketReserveCount) ?? 0
        lendingProtocolStatuses = try container.decodeIfPresent([String: String].self, forKey: .lendingProtocolStatuses) ?? [:]
        assets = try container.decode([PortfolioSnapshotAsset].self, forKey: .assets)
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
    let nativeStakeLamports: UInt64
    let stakeAccountCount: Int
    let lstHoldingCount: Int
    let lendingPositionCount: Int
    let lendingMarketReserveCount: Int
    let lendingNetValueUSD: Decimal?

    init(snapshot: PortfolioSnapshot) {
        self.snapshotID = snapshot.id
        self.createdAt = snapshot.createdAt
        self.totalUSD = snapshot.totalUSD
        self.walletCount = snapshot.walletCount
        self.assetCount = snapshot.assetCount
        self.unavailablePriceCount = snapshot.unavailablePriceCount
        self.nativeStakeLamports = snapshot.nativeStakeLamports
        self.stakeAccountCount = snapshot.stakeAccountCount
        self.lstHoldingCount = snapshot.lstHoldingCount
        self.lendingPositionCount = snapshot.lendingPositionCount
        self.lendingMarketReserveCount = snapshot.lendingMarketReserveCount
        self.lendingNetValueUSD = snapshot.lendingNetValueUSD
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
