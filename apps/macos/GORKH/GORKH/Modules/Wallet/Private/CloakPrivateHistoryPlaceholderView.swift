import SwiftUI

struct CloakPrivateHistoryPlaceholderView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        GorkhPanel("Private Activity") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    GorkhStatusChip(title: "\(walletManager.cloakPrivateRecords.count) local records", systemImage: "tray.full", color: walletManager.cloakPrivateRecords.isEmpty ? GorkhColors.warning : GorkhColors.success)
                    GorkhStatusChip(title: "Scan placeholder", systemImage: "eye.slash", color: GorkhColors.warning)
                }

                Text("Activity is built from local safe metadata. Viewing-key scan history is not connected yet, so GORKH does not claim a complete private balance beyond locally stored records.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                if walletManager.cloakPrivateRecords.isEmpty {
                    Text("No local Cloak deposits or withdraws recorded for this wallet.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    VStack(spacing: 8) {
                        ForEach(walletManager.cloakPrivateRecords.sorted(by: { $0.updatedAt > $1.updatedAt })) { record in
                            recordRow(record)
                        }
                    }
                }
            }
        }
    }

    private func recordRow(_ record: CloakPrivateRecordMetadata) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.state == .deposited ? "arrow.down.to.line.compact" : "arrow.up.right")
                .foregroundStyle(record.state == .deposited ? GorkhColors.success : GorkhColors.warning)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.state == .deposited ? "Shielded SOL deposit" : "Private pay / full withdraw")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                Text("\(record.amountSOLText) / commitment \(record.shortCommitment)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(GorkhColors.secondaryText)
                    .textSelection(.enabled)
                Text(record.updatedAt.formatted(date: .abbreviated, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            Spacer()

            GorkhStatusChip(
                title: record.state.rawValue,
                systemImage: record.state == .deposited ? "checkmark.seal" : "archivebox",
                color: record.state == .deposited ? GorkhColors.success : GorkhColors.accent
            )
        }
        .padding(10)
        .background(GorkhColors.panelElevated.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
