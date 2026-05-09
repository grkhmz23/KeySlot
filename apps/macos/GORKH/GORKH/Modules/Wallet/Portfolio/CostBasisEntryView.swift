import SwiftUI

struct CostBasisEntryView: View {
    let entries: [CostBasisEntry]
    let coverage: CostBasisCoverage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cost basis")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)

            HStack(spacing: 8) {
                GorkhStatusChip(title: coverage.status.title, systemImage: coverage.status == .loaded ? "checkmark.seal" : "exclamationmark.triangle", color: coverage.status == .loaded ? GorkhColors.success : GorkhColors.warning)
                Text(coverage.reason ?? "Manual entries are local to this Mac.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            if entries.isEmpty {
                Text("Manual cost basis entries are not configured. PnL remains an estimate from snapshots until local cost basis is added.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                ForEach(entries.prefix(5)) { entry in
                    HStack {
                        Text(entry.tokenSymbol ?? entry.tokenMint.shortAddress)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.primaryText)
                        Spacer()
                        Text(entry.totalCostUSD.portfolioCurrencyText)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.primaryText)
                    }
                }
            }
        }
    }
}
