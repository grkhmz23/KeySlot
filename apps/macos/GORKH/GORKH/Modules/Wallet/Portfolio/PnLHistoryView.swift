import SwiftUI

struct PnLHistoryView: View {
    let summary: PnLPortfolioSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Snapshot performance")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)

            ForEach(summary.timeframePerformances) { item in
                HStack {
                    Text(item.timeframe.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(GorkhColors.primaryText)
                        .frame(width: 42, alignment: .leading)
                    Text(item.valueDeltaUSD?.portfolioCurrencyText ?? "Insufficient history")
                        .font(.caption)
                        .foregroundStyle(item.valueDeltaUSD == nil ? GorkhColors.warning : deltaColor(item.valueDeltaUSD))
                    Text(percent(item.percentageDelta))
                        .font(.caption)
                        .foregroundStyle(item.percentageDelta == nil ? GorkhColors.secondaryText : deltaColor(item.valueDeltaUSD))
                    Spacer()
                    Text(item.baselineTimestamp?.formatted(date: .abbreviated, time: .omitted) ?? item.status.title)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }
        }
    }

    private func percent(_ value: Decimal?) -> String {
        guard let value else {
            return "Unavailable"
        }
        return "\(NSDecimalNumber(decimal: value).doubleValue.formatted(.number.precision(.fractionLength(2))))%"
    }

    private func deltaColor(_ value: Decimal?) -> Color {
        guard let value else {
            return GorkhColors.secondaryText
        }
        return value >= 0 ? GorkhColors.success : GorkhColors.danger
    }
}
