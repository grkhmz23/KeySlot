import SwiftUI

struct PnLSummaryView: View {
    let summary: PnLPortfolioSummary

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
            metric("Current Value", summary.currentValueUSD?.portfolioCurrencyText ?? "Unavailable")
            metric("30d Delta", summary.primaryPerformance?.valueDeltaUSD?.portfolioCurrencyText ?? "Insufficient history")
            metric("30d Change", percent(summary.primaryPerformance?.percentageDelta))
            metric("Realized PnL", summary.realized.estimatedUSD?.portfolioCurrencyText ?? "Unavailable")
            metric("Unrealized PnL", summary.unrealized.estimatedUSD?.portfolioCurrencyText ?? "Partial")
            metric("Cost Basis", "\(summary.costBasisCoverage.coveredAssetCount)/\(summary.costBasisCoverage.coveredAssetCount + summary.costBasisCoverage.missingAssetCount) assets")
            metric("Swap Hints", "\(summary.swapActivityHintCount)")
            metric("Snapshots", "\(summary.historyPointCount)")
        }

        VStack(alignment: .leading, spacing: 4) {
            statusLine("Realized", status: summary.realized.status, reason: summary.realized.reason)
            statusLine("Unrealized", status: summary.unrealized.status, reason: summary.unrealized.reason ?? "Cost basis coverage is complete for known assets.")
            statusLine("Cost basis", status: summary.costBasisCoverage.status, reason: summary.costBasisCoverage.reason ?? "Manual cost basis entries cover current assets.")
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
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

    private func statusLine(_ title: String, status: PnLDataStatus, reason: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)
            Text(status.title)
                .font(.caption)
                .foregroundStyle(status == .loaded ? GorkhColors.success : GorkhColors.warning)
            Text(reason)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func percent(_ value: Decimal?) -> String {
        guard let value else {
            return "Unavailable"
        }
        return "\(NSDecimalNumber(decimal: value).doubleValue.formatted(.number.precision(.fractionLength(2))))%"
    }
}
