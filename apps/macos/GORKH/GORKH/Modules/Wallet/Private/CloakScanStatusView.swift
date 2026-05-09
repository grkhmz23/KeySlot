import SwiftUI

struct CloakScanStatusView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        GorkhPanel("Private History Scan") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    GorkhStatusChip(
                        title: walletManager.cloakScanSummary.status.title,
                        systemImage: walletManager.cloakScanSummary.status == .loaded ? "checkmark.seal" : "magnifyingglass",
                        color: chipColor
                    )
                    GorkhStatusChip(
                        title: "Viewing key \(credentialStatus.title)",
                        systemImage: credentialStatus == .stored ? "key.fill" : "lock",
                        color: credentialStatus == .stored ? GorkhColors.success : GorkhColors.warning
                    )
                    GorkhStatusChip(
                        title: rpcStatusText,
                        systemImage: "network",
                        color: rpcColor
                    )
                }

                Text("Rescan decrypts Cloak chain notes locally through the helper and returns safe activity summaries only. Private state stays in Keychain and is never shown to Agent or logs.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], alignment: .leading, spacing: 8) {
                    metric("Transactions", value: "\(walletManager.cloakScanSummary.transactionCount)")
                    metric("Final balance", value: CloakScanTransactionSummary.solText(walletManager.cloakScanSummary.finalBalanceLamports))
                    metric("Net change", value: CloakScanTransactionSummary.solText(walletManager.cloakScanSummary.netChangeLamports))
                    metric("Last scan", value: lastScanText)
                    metric("RPC host", value: walletManager.cloakScanSummary.rpcHost ?? rpcHostText)
                    metric("RPC provider", value: walletManager.cloakScanSummary.rpcProvider ?? rpcProviderText)
                }

                if let error = walletManager.cloakScanSummary.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }

                HStack(spacing: 8) {
                    Button {
                        Task {
                            await walletManager.rescanCloakPrivateActivity()
                        }
                    } label: {
                        Label("Rescan Private Activity", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.gorkhPrimary)
                    .disabled(!canScan)

                    Button {
                        walletManager.clearCloakScanCache()
                    } label: {
                        Label("Clear Scan Cache", systemImage: "trash")
                    }
                    .buttonStyle(.gorkhSecondary)
                    .disabled(walletManager.selectedProfile == nil || walletManager.isBusy)
                }

                Text("Private balance requires a successful scan; current value is unavailable when scan status is missing, failed, or stale.")
                    .font(.caption2)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }

    private var credentialStatus: CloakScanCredentialStatus {
        CloakScanPolicy.credentialStatus(
            vaultStatus: walletManager.cloakVaultStatus,
            vaultState: walletManager.vaultState
        )
    }

    private var canScan: Bool {
        CloakScanPolicy.canScan(
            vaultStatus: walletManager.cloakVaultStatus,
            vaultState: walletManager.vaultState,
            network: walletManager.selectedNetwork
        ) && !walletManager.isBusy
    }

    private var chipColor: Color {
        switch walletManager.cloakScanSummary.status {
        case .loaded, .empty:
            return GorkhColors.success
        case .scanning:
            return GorkhColors.accent
        case .partial, .unavailable, .error, .cacheCleared:
            return GorkhColors.warning
        case .idle:
            return GorkhColors.secondaryText
        }
    }

    private var rpcStatusText: String {
        if let validation = walletManager.cloakBridgeContractResponse?.environmentValidation {
            return validation.rpcFastTokenStatus == "present" ? "RPC Fast ready" : "RPC fallback"
        }
        return "RPC unchecked"
    }

    private var rpcColor: Color {
        walletManager.cloakBridgeContractResponse?.environmentValidation?.rpcFastTokenStatus == "present"
            ? GorkhColors.success
            : GorkhColors.warning
    }

    private var rpcHostText: String {
        walletManager.cloakBridgeContractResponse?.environmentValidation?.rpcHost ?? "Unchecked"
    }

    private var rpcProviderText: String {
        walletManager.cloakBridgeContractResponse?.environmentValidation?.rpcProvider ?? "Unchecked"
    }

    private var lastScanText: String {
        guard walletManager.cloakScanSummary.status != .idle else {
            return "Never"
        }
        return walletManager.cloakScanSummary.scannedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
