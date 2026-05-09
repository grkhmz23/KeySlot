import SwiftUI

struct PortfolioAssetListView: View {
    let summary: PortfolioAggregateSummary

    var body: some View {
        GorkhPanel("Consolidated Assets") {
            if summary.consolidatedAssets.isEmpty {
                Text("No portfolio balances loaded.")
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(summary.consolidatedAssets) { asset in
                        consolidatedRow(asset)
                    }
                }
            }
        }
    }

    private func consolidatedRow(_ asset: PortfolioConsolidatedAsset) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(asset.symbol)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(GorkhColors.primaryText)
                    if asset.isNativeSOL {
                        GorkhStatusChip(title: "SOL", systemImage: "circle.grid.cross", color: GorkhColors.accent)
                    }
                    if LSTComparisonProvider.knownToken(mintAddress: asset.mintAddress, network: summary.network) != nil {
                        GorkhStatusChip(title: "LST", systemImage: "leaf", color: GorkhColors.success)
                    }
                    if asset.walletBreakdown.contains(where: { $0.asset.walletProfileKind == .watchOnly }) {
                        GorkhStatusChip(title: "Includes watch-only", systemImage: "eye", color: GorkhColors.warning)
                    }
                    ForEach(asset.warnings.prefix(2)) { warning in
                        GorkhStatusChip(title: warning.title, systemImage: "exclamationmark.triangle", color: GorkhColors.warning)
                    }
                }

                Text("\(asset.uiAmountString) / \(asset.isNativeSOL ? "Native SOL" : asset.mintAddress.shortAddress)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(GorkhColors.secondaryText)
                    .textSelection(.enabled)

                Text("\(asset.walletBreakdown.count) wallet entries")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let usdValue = asset.totalUSD {
                    Text(usdValue.portfolioCurrencyText)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(GorkhColors.primaryText)
                } else {
                    Text(asset.unavailablePriceCount > 0 ? "Price missing" : "No USD price")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }

                if let price = asset.priceQuote?.usdPrice {
                    Text("@ \(price.portfolioCurrencyText)")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    Text(asset.name)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .background(GorkhColors.panelElevated.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
