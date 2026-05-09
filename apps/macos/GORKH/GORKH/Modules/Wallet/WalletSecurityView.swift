import SwiftUI

struct WalletSecurityView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        GorkhPanel("Wallet Security") {
            VStack(alignment: .leading, spacing: 14) {
                WalletSecurityStatusStripView()

                HStack(spacing: 8) {
                    GorkhStatusChip(
                        title: "Auto-lock \(walletManager.securityPolicy.autoLockTimeout.displayName)",
                        systemImage: "timer",
                        color: walletManager.securityPolicy.autoLockTimeout == .never ? GorkhColors.warning : GorkhColors.accent
                    )
                    GorkhStatusChip(
                        title: walletManager.securityPolicy.requireLocalAuthenticationForSigning ? "Auth before signing" : "Auth disabled",
                        systemImage: walletManager.securityPolicy.requireLocalAuthenticationForSigning ? "touchid" : "exclamationmark.triangle",
                        color: walletManager.securityPolicy.requireLocalAuthenticationForSigning ? GorkhColors.success : GorkhColors.warning
                    )
                }

                if let warning = walletManager.securityPolicy.autoLockTimeout.warning {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }

                if let backupStatus = walletManager.selectedBackupStatus {
                    WalletBackupView(status: backupStatus)
                }

                WalletDeleteView()
            }
        }
    }
}
