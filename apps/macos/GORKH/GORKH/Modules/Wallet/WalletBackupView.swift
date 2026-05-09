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

            if !status.recoveryPhraseExportAvailable {
                Text("GORKH cannot reveal this recovery phrase again because only the derived signing seed is stored in Keychain.")
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
