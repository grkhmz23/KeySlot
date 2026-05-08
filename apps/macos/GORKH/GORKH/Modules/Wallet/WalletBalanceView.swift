import SwiftUI

struct WalletBalanceView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        GorkhPanel("SOL Balance") {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(walletManager.balance?.solText ?? "Not loaded")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(GorkhColors.primaryText)

                    if let balance = walletManager.balance {
                        Text("Fetched \(balance.fetchedAt.formatted(date: .abbreviated, time: .standard)) on \(balance.network.displayName)")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    } else {
                        Text("Manual refresh uses the selected Solana RPC endpoint.")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                }

                Spacer()

                Button {
                    Task { await walletManager.refreshBalance() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.gorkhSecondary)
                .disabled(walletManager.isBusy)
            }
        }
    }
}
