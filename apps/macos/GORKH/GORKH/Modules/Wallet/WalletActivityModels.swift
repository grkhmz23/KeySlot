import SwiftUI

enum WalletActivityCategory: String, CaseIterable, Identifiable {
    case wallet
    case send
    case token
    case swap
    case portfolio
    case pusd
    case privateWallet
    case lending
    case liquidity
    case yield
    case pnl
    case security
    case rpc
    case transactionStudio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wallet:
            return "Wallet"
        case .send:
            return "Send"
        case .token:
            return "Token"
        case .swap:
            return "Swap"
        case .portfolio:
            return "Portfolio"
        case .pusd:
            return "PUSD"
        case .privateWallet:
            return "Private"
        case .lending:
            return "Lending"
        case .liquidity:
            return "Liquidity"
        case .yield:
            return "Yield"
        case .pnl:
            return "PnL"
        case .security:
            return "Security"
        case .rpc:
            return "RPC"
        case .transactionStudio:
            return "Studio"
        }
    }

    var systemImage: String {
        switch self {
        case .wallet:
            return "wallet.pass"
        case .send:
            return "paperplane"
        case .token:
            return "circle.hexagongrid"
        case .swap:
            return "arrow.left.arrow.right"
        case .portfolio:
            return "chart.pie"
        case .pusd:
            return "dollarsign.circle"
        case .privateWallet:
            return "eye.slash"
        case .lending:
            return "building.columns"
        case .liquidity:
            return "drop.triangle"
        case .yield:
            return "chart.line.uptrend.xyaxis"
        case .pnl:
            return "chart.xyaxis.line"
        case .security:
            return "lock.shield"
        case .rpc:
            return "bolt.horizontal"
        case .transactionStudio:
            return "doc.text.magnifyingglass"
        }
    }

    var color: Color {
        switch self {
        case .security, .rpc:
            return GorkhColors.warning
        case .transactionStudio:
            return GorkhColors.accent
        case .pusd, .yield, .pnl:
            return GorkhColors.success
        default:
            return GorkhColors.accent
        }
    }

    static func category(for kind: AuditEvent.Kind) -> WalletActivityCategory {
        switch kind {
        case .walletCreated, .walletImported, .walletUnlocked, .walletLocked, .walletDeleted,
                .watchOnlyWalletAdded, .watchOnlyWalletRemoved, .walletLabelUpdated:
            return .wallet
        case .balanceRefreshed, .transactionDrafted, .transactionSimulated, .transactionApproved,
                .transactionSent, .transactionFailed:
            return .send
        case .tokenBalancesRefreshed, .tokenTransferDrafted, .tokenTransferSimulated,
                .tokenTransferApproved, .tokenTransferSent, .tokenTransferFailed,
                .ataCreationPlanned, .ataCreationIncluded:
            return .token
        case .swapQuoteRequested, .swapQuoteReceived, .swapQuoteFailed, .swapTransactionBuilt,
                .swapSimulationPassed, .swapSimulationFailed, .swapApproved, .swapSent,
                .swapFailed, .swapBlockedByGuard:
            return .swap
        case .pusdTreasuryViewed, .pusdReceiveViewed, .pusdPortfolioRefreshed,
                .pusdCirculationRefreshed, .pusdCirculationUnavailable:
            return .pusd
        case .privateTabViewed, .cloakDepositDraftCreated, .cloakDepositExecutionBlocked,
                .cloakVaultStatusChecked, .cloakPrivateDataCleared, .cloakBridgeHealthChecked,
                .cloakBridgeEnvironmentChecked, .cloakDepositPlanGenerated, .cloakBridgeExecutionRejected,
                .cloakHelperHealthChecked, .cloakHelperEnvironmentChecked, .cloakDepositPlanDryRunChecked,
                .cloakHelperInvocationBlocked, .cloakHelperResponseRejected, .cloakSignerPreflightChecked,
                .cloakSignerRequestRejected, .cloakSignerRequestLocked, .cloakReviewFlowViewed,
                .cloakApprovalRequirementGenerated, .cloakDepositApproved, .cloakDepositConfirmed,
                .cloakWithdrawApproved, .cloakWithdrawConfirmed, .cloakSigningRequestBlocked,
                .cloakPrivateStateStored, .cloakScanRequested, .cloakScanSucceeded,
                .cloakScanFailed, .cloakScanCacheCleared, .cloakActivityReconciled,
                .cloakComplianceSummaryGenerated, .cloakRPCConfigChecked:
            return .privateWallet
        case .lendingRefreshed, .lendingAdapterUnavailable, .lendingAdapterError,
                .lendingSnapshotStored, .lendingActionBlocked:
            return .lending
        case .lpPositionsRefreshed, .meteoraAdapterUnavailable, .meteoraPositionsLoaded,
                .lpSnapshotStored, .lpActionBlocked, .orcaHarvestPlanCreated,
                .orcaHarvestSimulationPassed, .orcaHarvestSimulationFailed, .orcaHarvestApproved,
                .orcaHarvestSent, .orcaHarvestFailed, .orcaHarvestBlockedByGuard:
            return .liquidity
        case .yieldComparisonRefreshed, .yieldSourceUnavailable, .yieldSnapshotStored, .yieldPanelViewed:
            return .yield
        case .pnlPanelViewed, .pnlRefreshed, .costBasisEntryAdded, .costBasisEntryUpdated,
                .costBasisEntryRemoved, .pnlSnapshotGenerated:
            return .pnl
        case .walletAutoLocked, .securityPolicyUpdated, .localAuthenticationFailed:
            return .security
        case .rpcProviderHealthChecked, .rpcProviderDegraded, .rpcProviderTokenMissing,
                .rpcMethodBlocked, .rpcRateLimited:
            return .rpc
        case .transactionStudioOpened, .transactionStudioDecodeAttempted,
                .transactionStudioDecodeSucceeded, .transactionStudioDecodeFailed,
                .transactionStudioSimulationAttempted, .transactionStudioSimulationSucceeded,
                .transactionStudioSimulationFailed, .transactionStudioRiskReviewGenerated,
                .transactionStudioExplanationGenerated, .transactionStudioHandoffCreated:
            return .transactionStudio
        default:
            return .portfolio
        }
    }
}

enum WalletActivityStatus: String {
    case succeeded
    case warning
    case failed

    var title: String {
        switch self {
        case .succeeded:
            return "Done"
        case .warning:
            return "Needs review"
        case .failed:
            return "Failed"
        }
    }

    var color: Color {
        switch self {
        case .succeeded:
            return GorkhColors.success
        case .warning:
            return GorkhColors.warning
        case .failed:
            return GorkhColors.danger
        }
    }

    static func status(for kind: AuditEvent.Kind) -> WalletActivityStatus {
        let raw = kind.rawValue
        if raw.contains("failed") || raw.contains("blocked") || raw.contains("rejected") {
            return .failed
        }
        if raw.contains("unavailable") || raw.contains("missing") || raw.contains("degraded") || raw.contains("locked") {
            return .warning
        }
        return .succeeded
    }
}
