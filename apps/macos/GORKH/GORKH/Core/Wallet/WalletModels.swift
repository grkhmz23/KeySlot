import Foundation

struct WalletProfile: Codable, Equatable, Identifiable {
    let id: UUID
    var label: String
    var publicAddress: String
    var accounts: [WalletAccount]
    var selectedNetwork: WalletNetwork
    var walletOrigin: WalletOrigin
    var profileKind: WalletProfileKind
    var derivationPath: String?
    var isPinned: Bool
    var colorTag: String?
    var createdAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        label: String,
        publicAddress: String,
        selectedNetwork: WalletNetwork = .devnet,
        walletOrigin: WalletOrigin = .legacyKeypair,
        profileKind: WalletProfileKind? = nil,
        derivationPath: String? = nil,
        isPinned: Bool = false,
        colorTag: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.label = label
        self.publicAddress = publicAddress
        self.accounts = [
            WalletAccount(id: id, publicAddress: publicAddress, label: label, derivationPath: derivationPath)
        ]
        self.selectedNetwork = selectedNetwork
        self.walletOrigin = walletOrigin
        self.profileKind = profileKind ?? WalletProfileKind.inferred(from: walletOrigin)
        self.derivationPath = derivationPath
        self.isPinned = isPinned
        self.colorTag = colorTag
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    var canSign: Bool {
        profileKind.canSign
    }

    var isWatchOnly: Bool {
        profileKind == .watchOnly
    }

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case publicAddress
        case accounts
        case selectedNetwork
        case walletOrigin
        case profileKind
        case derivationPath
        case isPinned
        case colorTag
        case createdAt
        case lastUsedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        publicAddress = try container.decode(String.self, forKey: .publicAddress)
        selectedNetwork = try container.decode(WalletNetwork.self, forKey: .selectedNetwork)
        walletOrigin = try container.decodeIfPresent(WalletOrigin.self, forKey: .walletOrigin) ?? .legacyKeypair
        profileKind = try container.decodeIfPresent(WalletProfileKind.self, forKey: .profileKind)
            ?? WalletProfileKind.inferred(from: walletOrigin)
        derivationPath = try container.decodeIfPresent(String.self, forKey: .derivationPath)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        colorTag = try container.decodeIfPresent(String.self, forKey: .colorTag)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        accounts = try container.decodeIfPresent([WalletAccount].self, forKey: .accounts) ?? [
            WalletAccount(id: id, publicAddress: publicAddress, label: label, derivationPath: derivationPath)
        ]
    }
}

struct WalletAccount: Codable, Equatable, Identifiable {
    let id: UUID
    var publicAddress: String
    var label: String
    var derivationPath: String?
}

enum WalletProfileKind: String, Codable, CaseIterable, Identifiable {
    case localSigner = "local_signer"
    case mnemonicDerived = "recovery_derived"
    case importedPrivateKey = "imported_private_key"
    case watchOnly = "watch_only"
    case hardwarePlaceholder = "hardware_placeholder"
    case multisigPlaceholder = "multisig_placeholder"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .localSigner:
            return "Local signer"
        case .mnemonicDerived:
            return "Recovery-derived"
        case .importedPrivateKey:
            return "Imported private key"
        case .watchOnly:
            return "Watch-only"
        case .hardwarePlaceholder:
            return "Hardware wallet"
        case .multisigPlaceholder:
            return "Multisig"
        }
    }

    var canSign: Bool {
        switch self {
        case .localSigner, .mnemonicDerived, .importedPrivateKey:
            return true
        case .watchOnly, .hardwarePlaceholder, .multisigPlaceholder:
            return false
        }
    }

    static func inferred(from origin: WalletOrigin) -> WalletProfileKind {
        switch origin {
        case .generatedRecovery, .importedRecovery:
            return .mnemonicDerived
        case .importedPrivateKey:
            return .importedPrivateKey
        case .legacyKeypair:
            return .localSigner
        case .watchOnly:
            return .watchOnly
        case .hardwarePlaceholder:
            return .hardwarePlaceholder
        case .multisigPlaceholder:
            return .multisigPlaceholder
        }
    }
}

enum WalletOrigin: String, Codable, CaseIterable {
    case generatedRecovery = "generated_recovery"
    case importedRecovery = "imported_recovery"
    case importedPrivateKey = "advanced_import"
    case legacyKeypair = "legacy_local"
    case watchOnly = "watch_only"
    case hardwarePlaceholder = "hardware_placeholder"
    case multisigPlaceholder = "multisig_placeholder"

    var displayName: String {
        switch self {
        case .generatedRecovery:
            return "Generated recovery phrase"
        case .importedRecovery:
            return "Imported recovery phrase"
        case .importedPrivateKey:
            return "Imported private key"
        case .legacyKeypair:
            return "Legacy local keypair"
        case .watchOnly:
            return "Watch-only address"
        case .hardwarePlaceholder:
            return "Hardware wallet placeholder"
        case .multisigPlaceholder:
            return "Multisig placeholder"
        }
    }
}

enum WalletVaultState: Equatable {
    case missing
    case locked
    case unlocked
    case error(String)

    var title: String {
        switch self {
        case .missing:
            return "Missing"
        case .locked:
            return "Locked"
        case .unlocked:
            return "Unlocked"
        case .error:
            return "Error"
        }
    }
}

struct WalletBalance: Codable, Equatable {
    var lamports: UInt64
    var network: WalletNetwork
    var fetchedAt: Date
    var errorMessage: String?

    var solText: String {
        let sol = Decimal(lamports) / Decimal(SolanaConstants.lamportsPerSol)
        return "\(sol) SOL"
    }
}

struct TransactionDraft: Codable, Equatable, Identifiable {
    let id: UUID
    var network: WalletNetwork
    var fromAddress: String
    var toAddress: String
    var amountLamports: UInt64
    var memo: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        network: WalletNetwork,
        fromAddress: String,
        toAddress: String,
        amountLamports: UInt64,
        memo: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.network = network
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.amountLamports = amountLamports
        self.memo = memo
        self.createdAt = createdAt
    }

    var amountSOLText: String {
        let sol = Decimal(amountLamports) / Decimal(SolanaConstants.lamportsPerSol)
        return "\(sol) SOL"
    }
}

struct SimulationResult: Codable, Equatable {
    enum Status: String, Codable {
        case success
        case failed
        case unavailable
    }

    var status: Status
    var logs: [String]
    var estimatedFeeLamports: UInt64?
    var errorMessage: String?
    var simulatedAt: Date

    static func unavailable(_ message: String) -> SimulationResult {
        SimulationResult(
            status: .unavailable,
            logs: [],
            estimatedFeeLamports: nil,
            errorMessage: message,
            simulatedAt: Date()
        )
    }
}

enum ApprovalState: Equatable {
    case idle
    case drafted
    case simulated
    case approved
    case sending
    case sent(String)
    case failed(String)
}

struct AuditEvent: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        case walletCreated = "wallet_created"
        case walletImported = "wallet_imported"
        case walletUnlocked = "wallet_unlocked"
        case walletLocked = "wallet_locked"
        case walletDeleted = "wallet_deleted"
        case walletAutoLocked = "wallet_auto_locked"
        case securityPolicyUpdated = "security_policy_updated"
        case localAuthenticationFailed = "local_authentication_failed"
        case balanceRefreshed = "balance_refreshed"
        case transactionDrafted = "transaction_drafted"
        case transactionSimulated = "transaction_simulated"
        case transactionApproved = "transaction_approved"
        case transactionSent = "transaction_sent"
        case transactionFailed = "transaction_failed"
        case tokenBalancesRefreshed = "token_balances_refreshed"
        case tokenTransferDrafted = "token_transfer_drafted"
        case tokenTransferSimulated = "token_transfer_simulated"
        case tokenTransferApproved = "token_transfer_approved"
        case tokenTransferSent = "token_transfer_sent"
        case tokenTransferFailed = "token_transfer_failed"
        case ataCreationPlanned = "ata_creation_planned"
        case ataCreationIncluded = "ata_creation_included"
        case privateTabViewed = "private_tab_viewed"
        case cloakDepositDraftCreated = "cloak_deposit_draft_created"
        case cloakDepositExecutionBlocked = "cloak_deposit_execution_blocked"
        case cloakVaultStatusChecked = "cloak_vault_status_checked"
        case cloakPrivateDataCleared = "cloak_private_data_cleared"
        case cloakBridgeHealthChecked = "cloak_bridge_health_checked"
        case cloakBridgeEnvironmentChecked = "cloak_bridge_environment_checked"
        case cloakDepositPlanGenerated = "cloak_deposit_plan_generated"
        case cloakBridgeExecutionRejected = "cloak_bridge_execution_rejected"
        case cloakHelperHealthChecked = "cloak_helper_health_checked"
        case cloakHelperEnvironmentChecked = "cloak_helper_environment_checked"
        case cloakDepositPlanDryRunChecked = "cloak_deposit_plan_dry_run_checked"
        case cloakHelperInvocationBlocked = "cloak_helper_invocation_blocked"
        case cloakHelperResponseRejected = "cloak_helper_response_rejected"
        case cloakSignerPreflightChecked = "cloak_signer_preflight_checked"
        case cloakSignerRequestRejected = "cloak_signer_request_rejected"
        case cloakSignerRequestLocked = "cloak_signer_request_locked"
        case cloakReviewFlowViewed = "cloak_review_flow_viewed"
        case cloakApprovalRequirementGenerated = "cloak_approval_requirement_generated"
        case portfolioRefreshed = "portfolio_refreshed"
        case portfolioPriceRefreshFailed = "portfolio_price_refresh_failed"
        case portfolioSnapshotStored = "portfolio_snapshot_stored"
        case portfolioHistoryCleared = "portfolio_history_cleared"
        case watchOnlyWalletAdded = "watch_only_wallet_added"
        case watchOnlyWalletRemoved = "watch_only_wallet_removed"
        case walletLabelUpdated = "wallet_label_updated"
        case multiWalletPortfolioRefreshed = "multi_wallet_portfolio_refreshed"
        case stakeAccountsRefreshed = "stake_accounts_refreshed"
        case stakeRefreshFailed = "stake_refresh_failed"
        case lstComparisonRefreshed = "lst_comparison_refreshed"
        case lstDataUnavailable = "lst_data_unavailable"
        case portfolioStakeSnapshotStored = "portfolio_stake_snapshot_stored"
        case lendingRefreshed = "lending_refreshed"
        case lendingAdapterUnavailable = "lending_adapter_unavailable"
        case lendingAdapterError = "lending_adapter_error"
        case lendingSnapshotStored = "lending_snapshot_stored"
        case lendingActionBlocked = "lending_action_blocked"
        case lpPositionsRefreshed = "lp_positions_refreshed"
        case meteoraAdapterUnavailable = "meteora_adapter_unavailable"
        case meteoraPositionsLoaded = "meteora_positions_loaded"
        case lpSnapshotStored = "lp_snapshot_stored"
        case lpActionBlocked = "lp_action_blocked"
        case pusdTreasuryViewed = "pusd_treasury_viewed"
        case pusdReceiveViewed = "pusd_receive_viewed"
        case pusdPortfolioRefreshed = "pusd_portfolio_refreshed"
        case pusdCirculationRefreshed = "pusd_circulation_refreshed"
        case pusdCirculationUnavailable = "pusd_circulation_unavailable"
        case swapQuoteRequested = "swap_quote_requested"
        case swapQuoteReceived = "swap_quote_received"
        case swapQuoteFailed = "swap_quote_failed"
        case swapTransactionBuilt = "swap_transaction_built"
        case swapSimulationPassed = "swap_simulation_passed"
        case swapSimulationFailed = "swap_simulation_failed"
        case swapApproved = "swap_approved"
        case swapSent = "swap_sent"
        case swapFailed = "swap_failed"
        case swapBlockedByGuard = "swap_blocked_by_guard"
        case rpcProviderHealthChecked = "rpc_provider_health_checked"
        case rpcProviderDegraded = "rpc_provider_degraded"
        case rpcProviderTokenMissing = "rpc_provider_token_missing"
        case rpcMethodBlocked = "rpc_method_blocked"
        case rpcRateLimited = "rpc_rate_limited"
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    let walletID: UUID?
    let network: WalletNetwork?
    let publicAddress: String?
    let transactionSignature: String?
    let message: String
    let details: [String: String]

    init(
        id: UUID = UUID(),
        kind: Kind,
        createdAt: Date = Date(),
        walletID: UUID?,
        network: WalletNetwork?,
        publicAddress: String?,
        transactionSignature: String? = nil,
        message: String,
        details: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.walletID = walletID
        self.network = network
        self.publicAddress = publicAddress
        self.transactionSignature = transactionSignature
        self.message = message
        self.details = Redaction.safeDetails(details)
    }
}

enum SolanaConstants {
    static let lamportsPerSol: UInt64 = 1_000_000_000
    static let systemProgramID = "11111111111111111111111111111111"
    static let splTokenProgramID = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    static let associatedTokenAccountProgramID = "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
    static let token2022ProgramID = "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
}

enum TransactionApprovalPolicy {
    static let requiredMainnetConfirmation = "I understand this is a real mainnet transaction."

    static func canApprove(
        network: WalletNetwork,
        simulation: SimulationResult?,
        mainnetConfirmation: String,
        hasCompletedDevnetSmoke: Bool,
        allowsUnavailableSimulation: Bool
    ) -> Bool {
        if network.isMainnet {
            guard mainnetConfirmation == requiredMainnetConfirmation, hasCompletedDevnetSmoke else {
                return false
            }
        }

        guard let simulation else {
            return false
        }

        switch simulation.status {
        case .success:
            return true
        case .unavailable:
            return allowsUnavailableSimulation
        case .failed:
            return false
        }
    }
}
