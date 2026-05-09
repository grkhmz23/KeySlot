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
                    Text("Future live deposits must pass wallet unlock, LocalAuthentication, signer preflight, Shield review, explicit approval, and audit.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text("Dry-run helper invocation is disabled by default and allowlisted to health, env-check, and deposit-plan.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                    Text("Phase 2.4 adds a locked native signer bridge contract. No transaction or message payloads are created.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
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

                    if let sdkValidation = contractResponse.sdkValidation {
                        HStack(spacing: 8) {
                            GorkhStatusChip(
                                title: sdkValidation.sdkImportOk ? "SDK import OK" : "SDK import unavailable",
                                systemImage: sdkValidation.sdkImportOk ? "checkmark.seal" : "exclamationmark.triangle",
                                color: sdkValidation.sdkImportOk ? GorkhColors.success : GorkhColors.warning
                            )
                            GorkhStatusChip(
                                title: sdkValidation.programIDMatches ? "Program match" : "Program mismatch",
                                systemImage: sdkValidation.programIDMatches ? "equal.circle" : "exclamationmark.triangle.fill",
                                color: sdkValidation.programIDMatches ? GorkhColors.success : GorkhColors.danger
                            )
                            if let version = sdkValidation.sdkVersion {
                                GorkhStatusChip(title: "SDK \(version)", systemImage: "shippingbox", color: GorkhColors.accent)
                            }
                        }
                    }

                    if let feeValidation = contractResponse.feeValidation {
                        GorkhStatusChip(
                            title: feeValidation.allSamplesMatch == true ? "Fee cross-check OK" : "Fee cross-check unavailable",
                            systemImage: feeValidation.allSamplesMatch == true ? "checkmark.circle" : "questionmark.circle",
                            color: feeValidation.allSamplesMatch == true ? GorkhColors.success : GorkhColors.warning
                        )
                    }

                    if let environmentValidation = contractResponse.environmentValidation {
                        HStack(spacing: 8) {
                            GorkhStatusChip(
                                title: environmentValidation.solanaRPCURLStatus == .presentRedacted ? "RPC configured" : "RPC missing",
                                systemImage: "network",
                                color: environmentValidation.solanaRPCURLStatus == .presentRedacted ? GorkhColors.success : GorkhColors.warning
                            )
                            GorkhStatusChip(
                                title: environmentValidation.networkSupportedForFutureExecution ? "Mainnet target" : "Mainnet required later",
                                systemImage: "exclamationmark.triangle",
                                color: environmentValidation.networkSupportedForFutureExecution ? GorkhColors.warning : GorkhColors.accent
                            )
                        }
                    }
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
