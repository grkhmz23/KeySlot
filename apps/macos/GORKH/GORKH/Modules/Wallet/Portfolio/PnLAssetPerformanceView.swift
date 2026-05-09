import SwiftUI

struct PnLAssetPerformanceView: View {
    let assets: [PnLAssetPerformance]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Asset performance estimates")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)

            if assets.isEmpty {
                Text("No asset performance is available until Portfolio has current balances.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                ForEach(assets.prefix(8)) { asset in
                    HStack(spacing: 8) {
                        GorkhStatusChip(title: asset.status.title, systemImage: asset.status == .loaded ? "checkmark" : "exclamationmark.triangle", color: asset.status == .loaded ? GorkhColors.success : GorkhColors.warning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(asset.tokenSymbol)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(GorkhColors.primaryText)
                            Text(asset.reason ?? asset.tokenMint.shortAddress)
                                .font(.caption2)
                                .foregroundStyle(GorkhColors.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(asset.valueDeltaUSD?.portfolioCurrencyText ?? "Unavailable")
                                .font(.caption)
                                .foregroundStyle(asset.valueDeltaUSD == nil ? GorkhColors.warning : (asset.valueDeltaUSD! >= 0 ? GorkhColors.success : GorkhColors.danger))
                            Text("Current \(asset.currentValueUSD?.portfolioCurrencyText ?? "value unavailable")")
                                .font(.caption2)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                    }
                }
            }
        }
    }
}
