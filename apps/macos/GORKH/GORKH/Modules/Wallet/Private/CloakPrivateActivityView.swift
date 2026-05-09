import SwiftUI

struct CloakPrivateActivityView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        GorkhPanel("Private Activity") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    GorkhStatusChip(title: "\(walletManager.cloakPrivateRecords.count) local", systemImage: "tray.full", color: GorkhColors.accent)
                    GorkhStatusChip(title: "\(walletManager.cloakScanSummary.transactionCount) scanned", systemImage: "link", color: walletManager.cloakScanSummary.transactionCount > 0 ? GorkhColors.success : GorkhColors.secondaryText)
                    GorkhStatusChip(title: "\(matchedCount) matched", systemImage: "checkmark.circle", color: matchedCount > 0 ? GorkhColors.success : GorkhColors.secondaryText)
                }

                if walletManager.cloakReconciledActivity.isEmpty {
                    Text("No private activity is available yet. Local shield records appear after Shield SOL, and chain activity appears after a successful read-only scan.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    VStack(spacing: 8) {
                        ForEach(walletManager.cloakReconciledActivity) { activity in
                            activityRow(activity)
                        }
                    }
                }
            }
        }
    }

    private var matchedCount: Int {
        walletManager.cloakReconciledActivity.filter { $0.state == .matched }.count
    }

    private func activityRow(_ activity: CloakReconciledActivity) -> some View {
        HStack(alignment: .top, spacing: 12) {
            GorkhStatusChip(
                title: activity.state.title,
                systemImage: icon(for: activity.state),
                color: color(for: activity.state)
            )
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(CloakScanTransactionSummary.solText(activity.amountLamports))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GorkhColors.primaryText)
                    Spacer()
                    Text(activity.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Time unavailable")
                        .font(.caption2)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
                Text("Status: \(activity.statusText)")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                HStack(spacing: 12) {
                    Text("Commitment \(activity.commitmentPrefix ?? "unavailable")")
                    Text("Tx \(activity.chainSignature?.shortAddress ?? "unavailable")")
                }
                .font(.caption2)
                .foregroundStyle(GorkhColors.secondaryText)
                .textSelection(.enabled)
            }
        }
        .padding(10)
        .background(GorkhColors.panel.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private func icon(for state: CloakActivityReconciliationState) -> String {
        switch state {
        case .matched:
            return "checkmark.seal"
        case .localOnly:
            return "externaldrive"
        case .chainOnly:
            return "link"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private func color(for state: CloakActivityReconciliationState) -> Color {
        switch state {
        case .matched:
            return GorkhColors.success
        case .localOnly, .chainOnly:
            return GorkhColors.warning
        case .unknown:
            return GorkhColors.secondaryText
        }
    }
}
