import SwiftUI

struct PortfolioSummaryView: View {
    let summary: PortfolioAggregateSummary

    var body: some View {
        GorkhPanel("Estimated Value") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(summary.totalUSD.portfolioCurrencyText)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(GorkhColors.primaryText)
                    Spacer()
                    Text("Updated \(summary.refreshedAt.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                HStack(spacing: 10) {
                    metric("Wallets", value: "\(summary.wallets.count)")
                    metric("Assets", value: "\(summary.assetCount)")
                    metric("Missing Prices", value: "\(summary.unavailablePriceCount)")
                    metric("Source", value: summary.priceSource)
                }

                if summary.status == .idle {
                    Text("Refresh Portfolio to load read-only SOL, SPL, and USD estimates.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
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
                .font(.system(.callout, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(GorkhColors.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
