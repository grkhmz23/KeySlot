import SwiftUI

struct CloakStatusView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        GorkhPanel("Cloak Status") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    GorkhStatusChip(
                        title: walletManager.selectedNetwork.displayName,
                        systemImage: walletManager.selectedNetwork.isMainnet ? "exclamationmark.triangle.fill" : "network",
                        color: walletManager.selectedNetwork.isMainnet ? GorkhColors.warning : GorkhColors.accent
                    )
                    GorkhStatusChip(
                        title: walletManager.cloakVaultStatus.privateWalletStatus.title,
                        systemImage: "externaldrive.badge.lock",
                        color: GorkhColors.warning
                    )
                    GorkhStatusChip(
                        title: "Program \(CloakConstants.programID.shortAddress)",
                        systemImage: "shield.lefthalf.filled",
                        color: GorkhColors.accent
                    )
                    GorkhStatusChip(
                        title: walletManager.cloakHelperInvocationStatus.title,
                        systemImage: walletManager.cloakHelperInvocationStatus == .dryRunEnabled ? "terminal" : "lock",
                        color: walletManager.cloakHelperInvocationStatus == .dryRunEnabled ? GorkhColors.success : GorkhColors.warning
                    )
                }

                HStack(spacing: 8) {
                    GorkhStatusChip(title: "Private balance placeholder", systemImage: "eye.slash", color: GorkhColors.warning)
                    GorkhStatusChip(
                        title: walletManager.cloakVaultStatus.hasViewingKeyReference ? "Viewing reference present" : "No viewing reference",
                        systemImage: "key.viewfinder",
                        color: walletManager.cloakVaultStatus.hasViewingKeyReference ? GorkhColors.success : GorkhColors.warning
                    )
                    GorkhStatusChip(title: "Agent no access", systemImage: "person.crop.circle.badge.xmark", color: GorkhColors.accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Cloak is mainnet-oriented in the current SDK documentation.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text("Future live deposits must pass wallet unlock, LocalAuthentication, review, explicit approval, and audit.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text("Dry-run helper invocation is disabled by default and allowlisted to health, env-check, and deposit-plan.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                    Text(walletManager.cloakVaultStatus.storageDescription)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                if let contractResponse = walletManager.cloakBridgeContractResponse {
                    HStack(spacing: 8) {
                        GorkhStatusChip(
                            title: "Contract \(contractResponse.command.rawValue)",
                            systemImage: "curlybraces",
                            color: GorkhColors.accent
                        )
                        GorkhStatusChip(
                            title: contractResponse.status.rawValue,
                            systemImage: contractResponse.status == .ok ? "checkmark.seal" : "lock",
                            color: contractResponse.status == .ok ? GorkhColors.success : GorkhColors.warning
                        )
                    }
                    Text(contractResponse.message)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                HStack {
                    Button {
                        Task { await walletManager.checkCloakBridgeHealth() }
                    } label: {
                        Label("Bridge Health", systemImage: "heart.text.square")
                    }
                    .buttonStyle(.gorkhSecondary)

                    Button {
                        Task { await walletManager.checkCloakBridgeEnvironment() }
                    } label: {
                        Label("Env Check", systemImage: "checklist")
                    }
                    .buttonStyle(.gorkhSecondary)

                    Button {
                        walletManager.refreshCloakVaultStatus()
                    } label: {
                        Label("Private Vault", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.gorkhSecondary)
                }
            }
        }
    }
}
