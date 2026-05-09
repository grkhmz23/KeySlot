import SwiftUI

struct CloakComplianceSummaryView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        GorkhPanel("Compliance Summary") {
            VStack(alignment: .leading, spacing: 12) {
                if let summary = walletManager.cloakScanSummary.complianceSummary {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], alignment: .leading, spacing: 8) {
                        metric("Transactions", value: "\(summary.transactionCount)")
                        metric("Deposits", value: CloakScanTransactionSummary.solText(summary.totalDepositsLamports))
                        metric("Withdrawals", value: CloakScanTransactionSummary.solText(summary.totalWithdrawalsLamports))
                        metric("Fees", value: CloakScanTransactionSummary.solText(summary.totalFeesLamports))
                        metric("Final balance", value: CloakScanTransactionSummary.solText(summary.finalBalanceLamports))
                        metric("Generated", value: summary.generatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    Text("This is an aggregate summary derived from read-only scan results. It does not expose decrypted raw payloads or local vault material.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    HStack(spacing: 8) {
                        GorkhStatusChip(title: "Locked until scan", systemImage: "lock", color: GorkhColors.warning)
                        Text("Run a successful private activity scan to generate a safe aggregate report summary.")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                }
            }
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
