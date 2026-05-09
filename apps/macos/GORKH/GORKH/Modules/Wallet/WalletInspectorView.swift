import SwiftUI

struct WalletInspectorView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Status")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)

            GorkhPanel {
                VStack(alignment: .leading, spacing: 10) {
                    inspectorRow("Network", walletManager.selectedNetwork.displayName)
                    inspectorRow("Vault", walletManager.vaultState.title)
                    inspectorRow("Signer", walletManager.vaultState == .unlocked ? "Available locally" : "Locked")
                    inspectorRow("Auto-lock", walletManager.securityPolicy.autoLockTimeout.displayName)
                    inspectorRow("Auth", walletManager.securityPolicy.requireLocalAuthenticationForSigning ? "Required before signing" : "Disabled")
                    inspectorRow("Mainnet", walletManager.selectedNetwork.isMainnet ? "Explicit phrase required" : "Disabled for current draft")
                    if let backupStatus = walletManager.selectedBackupStatus {
                        inspectorRow("Backup", backupStatus.riskStatus.displayName)
                    }
                }
            }

            GorkhPanel("Safety") {
                VStack(alignment: .leading, spacing: 8) {
                    safetyLine("No hidden signing")
                    safetyLine("No automatic send")
                    safetyLine("No backend secret upload")
                    safetyLine("No agent signer access")
                    safetyLine("Swaps require review and approval")
                    safetyLine("No lending or DeFi execution")
                }
            }

            if let message = walletManager.statusMessage {
                GorkhPanel("Last Message") {
                    Text(message)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(20)
        .background(GorkhColors.sidebar)
    }

    private func inspectorRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(GorkhColors.secondaryText)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .foregroundStyle(GorkhColors.primaryText)
            Spacer()
        }
        .font(.callout)
    }

    private func safetyLine(_ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(GorkhColors.success)
            Text(title)
                .foregroundStyle(GorkhColors.secondaryText)
        }
        .font(.caption)
    }
}
