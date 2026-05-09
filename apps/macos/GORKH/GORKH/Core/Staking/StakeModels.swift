import Foundation

enum StakeConstants {
    static let stakeProgramID = "Stake11111111111111111111111111111111111111"
    static let source = "solana-rpc"
    static let deactivationEpochNever = UInt64.max
}

enum StakeAccountState: String, Codable, Equatable, CaseIterable, Identifiable {
    case active
    case activating
    case deactivating
    case inactive
    case delegated
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            return "Active"
        case .activating:
            return "Activating"
        case .deactivating:
            return "Deactivating"
        case .inactive:
            return "Inactive"
        case .delegated:
            return "Delegated"
        case .unknown:
            return "Unknown"
        }
    }
}

enum StakeDataStatus: String, Codable, Equatable {
    case idle
    case loading
    case loaded
    case stale
    case unavailable
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
        case .unavailable:
            return "Unavailable"
        case .error:
            return "Error"
        }
    }
}

struct StakeDelegationSummary: Codable, Equatable {
    let voteAccount: String?
    let delegatedLamports: UInt64
    let activationEpoch: UInt64?
    let deactivationEpoch: UInt64?
    let state: StakeAccountState
}

struct StakeValidatorSummary: Codable, Equatable, Identifiable {
    var id: String { voteAccount }

    let voteAccount: String
    let validatorIdentity: String?
    let name: String?
    let source: String
}

struct StakeRewardsSummary: Codable, Equatable {
    let rewardsLamports: Int64?
    let epoch: UInt64?
    let source: String
    let unavailableReason: String?

    static let unavailable = StakeRewardsSummary(
        rewardsLamports: nil,
        epoch: nil,
        source: StakeConstants.source,
        unavailableReason: "Rewards history is not fetched in Portfolio Core."
    )
}

struct StakeAccountSummary: Codable, Equatable, Identifiable {
    var id: String { stakeAccountAddress }

    let stakeAccountAddress: String
    let walletID: UUID
    let walletLabel: String
    let walletPublicAddress: String
    let network: WalletNetwork
    let state: StakeAccountState
    let delegation: StakeDelegationSummary?
    let validator: StakeValidatorSummary?
    let rentExemptReserveLamports: UInt64?
    let stakerAuthorityMatches: Bool
    let withdrawerAuthorityMatches: Bool
    let source: String
    let fetchedAt: Date
    let errorMessage: String?

    var delegatedLamports: UInt64 {
        delegation?.delegatedLamports ?? 0
    }

    var activeStakeLamports: UInt64 {
        switch state {
        case .active, .delegated:
            return delegatedLamports
        case .activating, .deactivating, .inactive, .unknown:
            return 0
        }
    }

    var activatingStakeLamports: UInt64 {
        state == .activating ? delegatedLamports : 0
    }

    var deactivatingStakeLamports: UInt64 {
        state == .deactivating ? delegatedLamports : 0
    }

    var inactiveStakeLamports: UInt64 {
        state == .inactive ? delegatedLamports : 0
    }
}

struct StakeWalletSummary: Codable, Equatable, Identifiable {
    let id: UUID
    let walletLabel: String
    let walletPublicAddress: String
    let profileKind: WalletProfileKind
    let accounts: [StakeAccountSummary]
    let totalDelegatedLamports: UInt64
    let activeLamports: UInt64
    let activatingLamports: UInt64
    let deactivatingLamports: UInt64
    let inactiveLamports: UInt64
    let errorMessage: String?

    init(profile: WalletProfile, accounts: [StakeAccountSummary], errorMessage: String? = nil) {
        self.id = profile.id
        self.walletLabel = profile.label
        self.walletPublicAddress = profile.publicAddress
        self.profileKind = profile.profileKind
        self.accounts = accounts
        self.totalDelegatedLamports = accounts.reduce(UInt64(0)) { $0.saturatingAdd($1.delegatedLamports) }
        self.activeLamports = accounts.reduce(UInt64(0)) { $0.saturatingAdd($1.activeStakeLamports) }
        self.activatingLamports = accounts.reduce(UInt64(0)) { $0.saturatingAdd($1.activatingStakeLamports) }
        self.deactivatingLamports = accounts.reduce(UInt64(0)) { $0.saturatingAdd($1.deactivatingStakeLamports) }
        self.inactiveLamports = accounts.reduce(UInt64(0)) { $0.saturatingAdd($1.inactiveStakeLamports) }
        self.errorMessage = errorMessage
    }
}

struct StakePortfolioSummary: Codable, Equatable {
    let status: StakeDataStatus
    let wallets: [StakeWalletSummary]
    let totalDelegatedLamports: UInt64
    let activeLamports: UInt64
    let activatingLamports: UInt64
    let deactivatingLamports: UInt64
    let inactiveLamports: UInt64
    let accountCount: Int
    let validatorCount: Int
    let estimatedUSD: Decimal?
    let priceUnavailable: Bool
    let source: String
    let refreshedAt: Date
    let errorMessage: String?

    static func empty(status: StakeDataStatus = .idle, source: String = StakeConstants.source) -> StakePortfolioSummary {
        StakePortfolioSummary(
            status: status,
            wallets: [],
            totalDelegatedLamports: 0,
            activeLamports: 0,
            activatingLamports: 0,
            deactivatingLamports: 0,
            inactiveLamports: 0,
            accountCount: 0,
            validatorCount: 0,
            estimatedUSD: nil,
            priceUnavailable: false,
            source: source,
            refreshedAt: Date(),
            errorMessage: nil
        )
    }
}

private extension UInt64 {
    func saturatingAdd(_ other: UInt64) -> UInt64 {
        let result = addingReportingOverflow(other)
        return result.overflow ? UInt64.max : result.partialValue
    }
}
