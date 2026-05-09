import SwiftUI

struct PortfolioLSTView: View {
    let summary: LSTPortfolioSummary

    var body: some View {
        GorkhPanel("LST Intelligence") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    GorkhStatusChip(title: "\(summary.holdingCount) holdings", systemImage: "drop", color: GorkhColors.accent)
                    GorkhStatusChip(title: "Read-only", systemImage: "eye", color: GorkhColors.accent)
                    GorkhStatusChip(title: "No LST swap", systemImage: "lock", color: GorkhColors.warning)
                }

                Text("LST holdings are included in SPL token totals. Native stake accounts are shown separately.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                if summary.holdings.isEmpty {
                    Text("No supported liquid staking token holdings detected in the selected scope.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(summary.holdings) { holding in
                            holdingRow(holding)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Comparison")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(GorkhColors.primaryText)

                    ForEach(summary.comparison) { entry in
                        comparisonRow(entry)
                    }
                }
            }
        }
    }

    private func holdingRow(_ holding: LSTHoldingSummary) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(holding.symbol)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(GorkhColors.primaryText)
                    GorkhStatusChip(title: "LST", systemImage: "leaf", color: GorkhColors.success)
                    if holding.priceUnavailable {
                        GorkhStatusChip(title: "Price missing", systemImage: "exclamationmark.triangle", color: GorkhColors.warning)
                    }
                }
                Text("\(holding.uiAmountString) / \(holding.mintAddress.shortAddress)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(GorkhColors.secondaryText)
                    .textSelection(.enabled)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let value = holding.estimatedUSD {
                    Text(value.portfolioCurrencyText)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(GorkhColors.primaryText)
                } else {
                    Text("USD unavailable")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }
                Text("\(holding.walletBreakdown.count) wallet entries")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
        .padding(10)
        .background(GorkhColors.panelElevated.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func comparisonRow(_ entry: LSTComparisonEntry) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(entry.symbol) - \(entry.name)")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text(entry.mintAddress.shortAddress)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                }
                Spacer()
                GorkhStatusChip(title: entry.availability.title, systemImage: "waveform.path.ecg", color: availabilityColor(entry.availability))
            }

            HStack(spacing: 10) {
                smallMetric("Holding", value: entry.uiAmountString)
                smallMetric("USD", value: entry.estimatedUSD?.portfolioCurrencyText ?? "Unavailable")
                smallMetric("Exchange Rate", value: entry.exchangeRate.map(String.init(describing:)) ?? "Unavailable")
                smallMetric("APY", value: entry.apy.map { "\($0)%" } ?? "Unavailable")
                smallMetric("TVL", value: entry.tvlUSD?.portfolioCurrencyText ?? "Unavailable")
            }

            Text(entry.unavailableReason ?? entry.riskNote)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
        .padding(10)
        .background(GorkhColors.panelElevated.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func smallMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(.caption)
                .foregroundStyle(GorkhColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func availabilityColor(_ availability: LSTDataAvailability) -> Color {
        switch availability {
        case .available:
            return GorkhColors.success
        case .priceOnly:
            return GorkhColors.accent
        case .unavailable, .stale:
            return GorkhColors.warning
        }
    }
}
