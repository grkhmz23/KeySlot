import SwiftUI

struct PortfolioPnLView: View {
    @EnvironmentObject private var walletManager: WalletManager
    let summary: PnLPortfolioSummary
    let costBasisEntries: [CostBasisEntry]
    @State private var didRecordView = false

    var body: some View {
        GorkhPanel("PnL / Performance") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    GorkhStatusChip(title: summary.status.title, systemImage: icon(for: summary.status), color: color(for: summary.status))
                    GorkhStatusChip(title: "Snapshot estimate", systemImage: "chart.xyaxis.line", color: GorkhColors.accent)
                    GorkhStatusChip(title: "No execution", systemImage: "lock", color: GorkhColors.warning)
                }

                Text(PnLConstants.notTaxGradeCopy)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                PnLSummaryView(summary: summary)
                PnLHistoryView(summary: summary)
                PnLAssetPerformanceView(assets: summary.assetPerformances)
                PnLWalletPerformanceView(wallets: summary.walletPerformances)
                CostBasisEntryView(entries: costBasisEntries, coverage: summary.costBasisCoverage)

                HStack(spacing: 8) {
                    lockedButton("Cost basis import")
                    lockedButton("Realized estimate")
                    lockedButton("Export locked")
                }

                if let reason = summary.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }

                Text("Realized and unrealized PnL stay unavailable or partial unless local snapshots, known holdings, and cost basis are sufficient. External swaps, transfers, rewards, LP changes, and private flows can make performance incomplete.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task {
            if !didRecordView {
                didRecordView = true
                walletManager.recordPnLPanelViewed()
            }
        }
    }

    private func lockedButton(_ title: String) -> some View {
        Button {
        } label: {
            Label(title, systemImage: "lock")
        }
        .buttonStyle(.gorkhSecondary)
        .disabled(true)
    }

    private func icon(for status: PnLDataStatus) -> String {
        switch status {
        case .loaded:
            return "checkmark.seal"
        case .partial:
            return "exclamationmark.magnifyingglass"
        case .unavailable:
            return "tray"
        case .stale:
            return "clock.badge.exclamationmark"
        case .error:
            return "xmark.octagon"
        }
    }

    private func color(for status: PnLDataStatus) -> Color {
        switch status {
        case .loaded:
            return GorkhColors.success
        case .partial, .unavailable, .stale:
            return GorkhColors.warning
        case .error:
            return GorkhColors.danger
        }
    }
}
