import SwiftUI

struct PortfolioAssetListView: View {
    let summary: PortfolioAggregateSummary

    var body: some View {
        GorkhPanel("Assets") {
            if summary.wallets.isEmpty {
                Text("No portfolio balances loaded.")
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(summary.wallets) { wallet in
                        walletSection(wallet)
                    }
                }
            }
        }
    }

    private func walletSection(_ wallet: PortfolioWalletSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(wallet.label)
                        .font(.headline)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text(wallet.publicAddress.shortAddress)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                }
                Spacer()
                Text(wallet.totalUSD.portfolioCurrencyText)
                    .font(.headline)
                    .foregroundStyle(GorkhColors.primaryText)
            }

            ForEach(wallet.assets) { value in
                assetRow(value)
            }

            if let error = wallet.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }
        }
        .padding(.vertical, 4)
    }

    private func assetRow(_ value: PortfolioTokenValue) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(value.asset.symbol)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(GorkhColors.primaryText)
                    if value.asset.isNativeSOL {
                        GorkhStatusChip(title: "SOL", systemImage: "circle.grid.cross", color: GorkhColors.accent)
                    } else if let kind = value.asset.tokenProgramKind {
                        GorkhStatusChip(title: kind.shortName, systemImage: "tag", color: GorkhColors.accent)
                    }
                    ForEach(value.asset.warnings.prefix(2)) { warning in
                        GorkhStatusChip(title: warning.title, systemImage: "exclamationmark.triangle", color: GorkhColors.warning)
                    }
                }

                Text("\(value.asset.uiAmountString) / \(value.asset.displayMint)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(GorkhColors.secondaryText)
                    .textSelection(.enabled)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let usdValue = value.usdValue {
                    Text(usdValue.portfolioCurrencyText)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(GorkhColors.primaryText)
                } else {
                    Text("No USD price")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }

                if let price = value.priceQuote?.usdPrice {
                    Text("@ \(price.portfolioCurrencyText)")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                } else if let reason = value.priceUnavailableReason {
                    Text(reason)
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
