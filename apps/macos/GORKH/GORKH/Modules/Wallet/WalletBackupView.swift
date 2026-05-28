import SwiftUI

struct WalletBackupView: View {
    let status: WalletBackupStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                GorkhStatusChip(
                    title: status.riskStatus.displayName,
                    systemImage: status.recoveryPhraseExportAvailable ? "key.viewfinder" : "key.slash",
                    color: statusColor
                )
                Spacer()
                Text(status.recoveryPhraseExportAvailable ? "Export available" : "Phrase export unavailable")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            Text(status.title)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)

            Text(status.message)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if status.recoveryPhraseExportAvailable {
                Text("Export requires Local Authentication plus your Vault Export Code.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.success)
            } else if !status.recoveryPhraseConfirmed && status.riskStatus == .seedOnlyWallet {
                Text("This wallet has no recovery phrase in KeySlot.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            } else if status.recoveryPhraseConfirmed && !status.recoveryPhraseExportAvailable {
                Text("This wallet was created before Vault Export Code support. Recovery phrase export is unavailable.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }
        }
    }

    private var statusColor: Color {
        switch status.riskStatus {
        case .backedUp:
            return GorkhColors.success
        case .notVerified, .cannotVerify:
            return GorkhColors.warning
        case .seedOnlyWallet:
            return GorkhColors.danger
        }
    }
}
