import SwiftUI

struct AuditLogView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var filter: AuditLogFilter = .all

    var body: some View {
        GorkhPanel("Audit Log") {
            if walletManager.auditEvents.isEmpty {
                Text("No sensitive wallet actions have been recorded yet.")
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Audit filter", selection: $filter) {
                        ForEach(AuditLogFilter.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    ForEach(filteredEvents.prefix(20)) { event in
                        auditRow(event)
                    }
                }
            }
        }
    }

    private var filteredEvents: [AuditEvent] {
        walletManager.auditEvents.filter { filter.includes($0) }
    }

    private func auditRow(_ event: AuditEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                Spacer()
                Text(event.createdAt.formatted(date: .abbreviated, time: .standard))
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            Text(event.message)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)

            HStack(spacing: 8) {
                if let network = event.network {
                    GorkhStatusChip(
                        title: network.displayName,
                        systemImage: network.isMainnet ? "exclamationmark.triangle.fill" : "network",
                        color: network.isMainnet ? GorkhColors.warning : GorkhColors.accent
                    )
                }
                if let publicAddress = event.publicAddress {
                    Text(publicAddress.shortAddress)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                }
                if let signature = event.transactionSignature {
                    Text("sig \(signature.shortAddress)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                }
            }

            let summary = event.summaryDetails
            if !summary.isEmpty {
                Text(summary)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(GorkhColors.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 6)
    }
}

private enum AuditLogFilter: String, CaseIterable, Identifiable {
    case all
    case wallet
    case sol
    case spl
    case swap
    case portfolio
    case privateWallet
    case security
    case failed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .wallet:
            return "Wallet"
        case .sol:
            return "SOL"
        case .spl:
            return "SPL"
        case .swap:
            return "Swap"
        case .portfolio:
            return "Portfolio"
        case .privateWallet:
            return "Private"
        case .security:
            return "Security"
        case .failed:
            return "Failed"
        }
    }

    func includes(_ event: AuditEvent) -> Bool {
        switch self {
        case .all:
            return true
        case .wallet:
            return [
                .walletCreated,
                .walletImported,
                .walletUnlocked,
                .walletLocked,
                .walletDeleted,
                .watchOnlyWalletAdded,
                .watchOnlyWalletRemoved,
                .walletLabelUpdated
            ].contains(event.kind)
        case .sol:
            return [.balanceRefreshed, .transactionDrafted, .transactionSimulated, .transactionApproved, .transactionSent].contains(event.kind)
        case .spl:
            return [
                .tokenBalancesRefreshed,
                .tokenTransferDrafted,
                .tokenTransferSimulated,
                .tokenTransferApproved,
                .tokenTransferSent,
                .ataCreationPlanned,
                .ataCreationIncluded
            ].contains(event.kind)
        case .swap:
            return [
                .swapQuoteRequested,
                .swapQuoteReceived,
                .swapQuoteFailed,
                .swapTransactionBuilt,
                .swapSimulationPassed,
                .swapSimulationFailed,
                .swapApproved,
                .swapSent,
                .swapFailed,
                .swapBlockedByGuard
            ].contains(event.kind)
        case .privateWallet:
            return [
                .privateTabViewed,
                .cloakDepositDraftCreated,
                .cloakDepositExecutionBlocked,
                .cloakVaultStatusChecked,
                .cloakPrivateDataCleared,
                .cloakBridgeHealthChecked,
                .cloakBridgeEnvironmentChecked,
                .cloakDepositPlanGenerated,
                .cloakBridgeExecutionRejected,
                .cloakHelperHealthChecked,
                .cloakHelperEnvironmentChecked,
                .cloakDepositPlanDryRunChecked,
                .cloakHelperInvocationBlocked,
                .cloakHelperResponseRejected,
                .cloakSignerPreflightChecked,
                .cloakSignerRequestRejected,
                .cloakSignerRequestLocked,
                .cloakReviewFlowViewed,
                .cloakApprovalRequirementGenerated
            ].contains(event.kind)
        case .portfolio:
            return [
                .portfolioRefreshed,
                .multiWalletPortfolioRefreshed,
                .portfolioPriceRefreshFailed,
                .portfolioSnapshotStored,
                .portfolioHistoryCleared,
                .stakeAccountsRefreshed,
                .stakeRefreshFailed,
                .lstComparisonRefreshed,
                .lstDataUnavailable,
                .portfolioStakeSnapshotStored,
                .lendingRefreshed,
                .lendingAdapterUnavailable,
                .lendingAdapterError,
                .lendingSnapshotStored,
                .lendingActionBlocked
            ].contains(event.kind)
        case .security:
            return [.walletAutoLocked, .securityPolicyUpdated, .localAuthenticationFailed].contains(event.kind)
        case .failed:
            return [
                .transactionFailed,
                .tokenTransferFailed,
                .localAuthenticationFailed,
                .cloakDepositExecutionBlocked,
                .cloakBridgeExecutionRejected,
                .cloakHelperInvocationBlocked,
                .cloakHelperResponseRejected,
                .cloakSignerRequestRejected,
                .cloakSignerRequestLocked,
                .portfolioPriceRefreshFailed,
                .stakeRefreshFailed,
                .lstDataUnavailable,
                .lendingAdapterUnavailable,
                .lendingAdapterError,
                .lendingActionBlocked,
                .swapQuoteFailed,
                .swapSimulationFailed,
                .swapFailed,
                .swapBlockedByGuard
            ].contains(event.kind)
        }
    }
}

private extension AuditEvent {
    var summaryDetails: String {
        let keys = [
            "network",
            "amountLamports",
            "amountRaw",
            "expectedOutputRaw",
            "minimumOutputRaw",
            "tokenSymbol",
            "inputMint",
            "outputMint",
            "slippageBps",
            "route",
            "apiMode",
            "transactionVersion",
            "feePayer",
            "programCount",
            "estimatedFeeLamports",
            "riskWarningsCount",
            "balanceDeltaVerification",
            "mint",
            "to",
            "recipientOwner",
            "createsAssociatedTokenAccount",
            "cloakAction",
            "grossLamports",
            "feeLamports",
            "netLamports",
            "bridgeStatus",
            "bridgeCommand",
            "errorCategory",
            "vaultStatus",
            "requestID",
            "signerState",
            "draftFingerprint",
            "requirementsCount",
            "requiresMainnetPhrase",
            "portfolioScope",
            "profileKind",
            "tag",
            "walletCount",
            "assetCount",
            "stakeAccountCount",
            "activeStakeLamports",
            "deactivatingStakeLamports",
            "nativeStakeLamports",
            "lstHoldingCount",
            "lstPriceUnavailableCount",
            "lendingPositionCount",
            "lendingRiskyPositionCount",
            "lendingPartialAdapterCount",
            "lendingSuppliedPositionCount",
            "lendingBorrowedPositionCount",
            "lendingUnavailableAdapterCount",
            "lendingMarketReserveCount",
            "lendingProtocolStatuses",
            "unavailablePriceCount",
            "priceSource",
            "status",
            "warningsCount"
        ]

        return keys.compactMap { key in
            guard let value = details[key], !value.isEmpty else {
                return nil
            }
            return "\(key)=\(value)"
        }
        .joined(separator: "  ")
    }
}
