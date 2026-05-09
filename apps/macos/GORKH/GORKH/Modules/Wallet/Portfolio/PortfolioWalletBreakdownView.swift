import SwiftUI

struct PortfolioWalletBreakdownView: View {
    let summary: PortfolioAggregateSummary

    var body: some View {
        GorkhPanel("Wallet Breakdown") {
            if summary.wallets.isEmpty {
                Text("No wallet breakdown loaded.")
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(summary.wallets) { wallet in
                        walletRow(wallet)
                    }
                }
            }
        }
    }

    private func walletRow(_ wallet: PortfolioWalletSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(wallet.label)
                            .font(.headline)
                            .foregroundStyle(GorkhColors.primaryText)
                        GorkhStatusChip(
                            title: wallet.profileKind.displayName,
                            systemImage: wallet.isWatchOnly ? "eye" : "key",
                            color: wallet.isWatchOnly ? GorkhColors.warning : GorkhColors.accent
                        )
                    }
                    Text(wallet.publicAddress.shortAddress)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(wallet.totalUSD.portfolioCurrencyText)
                        .font(.headline)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text("\(wallet.splTokenCount) SPL / \(wallet.unavailablePriceCount) missing prices")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }

            HStack(spacing: 10) {
                metric("SOL", value: wallet.solBalance?.asset.uiAmountString ?? "0")
                metric("Assets", value: "\(wallet.assets.count)")
                metric("Updated", value: wallet.fetchedAt.formatted(date: .omitted, time: .shortened))
            }

            if let error = wallet.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }
        }
        .padding(12)
        .background(GorkhColors.panelElevated.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
