import SwiftUI

struct PortfolioHistoryView: View {
    let snapshots: [PortfolioSnapshot]
    let clearAction: (String) -> Void
    @State private var confirmation = ""

    var body: some View {
        GorkhPanel("Snapshot History") {
            VStack(alignment: .leading, spacing: 12) {
                if snapshots.isEmpty {
                    Text("No portfolio snapshots stored yet.")
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    ForEach(snapshots.prefix(8)) { snapshot in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(snapshot.createdAt.formatted(date: .abbreviated, time: .standard))
                                    .font(.callout)
                                    .foregroundStyle(GorkhColors.primaryText)
                                Text("\(snapshot.walletCount) wallets / \(snapshot.assetCount) assets / \(snapshot.stakeAccountCount) stake / \(snapshot.lstHoldingCount) LST / \(snapshot.lendingPositionCount) lending / \(snapshot.lpPositionCount) LP / \(snapshot.yieldHeldOpportunityCount) yield / \(snapshot.unavailablePriceCount) missing prices")
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.secondaryText)
                            }
                            Spacer()
                            Text(snapshot.totalUSD.portfolioCurrencyText)
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(GorkhColors.primaryText)
                        }
                    }
                }

                HStack {
                    TextField("Type CLEAR HISTORY", text: $confirmation)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                    Button {
                        clearAction(confirmation)
                        confirmation = ""
                    } label: {
                        Label("Clear History", systemImage: "trash")
                    }
                    .buttonStyle(.keyslotSecondary)
                    .disabled(snapshots.isEmpty)
                }
            }
        }
    }
}
