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

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], alignment: .leading, spacing: 10) {
                    metric("Wallets", value: "\(summary.wallets.count)")
                    metric("Assets", value: "\(summary.assetCount)")
                    metric("Liquid SOL", value: "\(TokenAmountFormatter.format(rawAmount: summary.liquidSolLamports, decimals: 9)) SOL")
                    metric("Staked SOL", value: "\(TokenAmountFormatter.format(rawAmount: summary.nativeStakeSummary.totalDelegatedLamports, decimals: 9)) SOL")
                    metric("PUSD", value: "\(summary.pusdTreasurySummary.uiAmountString) PUSD")
                    metric("LSTs", value: "\(summary.lstSummary.holdingCount)")
                    metric("Lending Net", value: summary.lendingSummary.netValueUSD?.portfolioCurrencyText ?? "Separate")
                    metric("Missing Prices", value: "\(summary.unavailablePriceCount)")
                    metric("Source", value: summary.priceSource)
                }

                Text("Lending values are tracked separately from wallet token balances and are not added to total value.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                if summary.pusdTreasurySummary.priceSource == .stablecoinPegEstimate {
                    Text(PUSDConstants.pegEstimateDescription)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
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
