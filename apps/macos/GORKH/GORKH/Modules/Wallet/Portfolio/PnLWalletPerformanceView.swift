import SwiftUI

struct PnLWalletPerformanceView: View {
    let wallets: [PnLWalletPerformance]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wallet performance estimates")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)

            if wallets.isEmpty {
                Text("Wallet performance appears after a portfolio refresh.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                ForEach(wallets.prefix(6)) { wallet in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(wallet.walletLabel)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(GorkhColors.primaryText)
                            Text("\(wallet.assetCount) assets / \(wallet.missingPriceCount) missing prices")
                                .font(.caption2)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(wallet.valueDeltaUSD?.portfolioCurrencyText ?? "Unavailable")
                                .font(.caption)
                                .foregroundStyle(wallet.valueDeltaUSD == nil ? GorkhColors.warning : (wallet.valueDeltaUSD! >= 0 ? GorkhColors.success : GorkhColors.danger))
                            Text(wallet.status.title)
                                .font(.caption2)
                                .foregroundStyle(wallet.status == .loaded ? GorkhColors.success : GorkhColors.warning)
                        }
                    }
                }
            }
        }
    }
}
