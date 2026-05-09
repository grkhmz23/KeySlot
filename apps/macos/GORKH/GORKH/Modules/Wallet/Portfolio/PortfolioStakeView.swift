import SwiftUI

struct PortfolioStakeView: View {
    let summary: StakePortfolioSummary

    var body: some View {
        GorkhPanel("Stake Accounts") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    GorkhStatusChip(title: summary.status.title, systemImage: "server.rack", color: statusColor)
                    GorkhStatusChip(title: "Read-only", systemImage: "eye", color: GorkhColors.accent)
                    GorkhStatusChip(title: "No stake execution", systemImage: "lock", color: GorkhColors.warning)
                }

                HStack(spacing: 12) {
                    metric("Total Staked", value: solText(summary.totalDelegatedLamports))
                    metric("Active", value: solText(summary.activeLamports))
                    metric("Activating", value: solText(summary.activatingLamports))
                    metric("Deactivating", value: solText(summary.deactivatingLamports))
                    metric("Accounts", value: "\(summary.accountCount)")
                }

                if let estimatedUSD = summary.estimatedUSD {
                    Text("Native stake estimate: \(estimatedUSD.portfolioCurrencyText). Native stake accounts are shown separately from liquid SOL.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                } else if summary.totalDelegatedLamports > 0 {
                    Text("Native stake found, but SOL price is unavailable. USD value is not estimated.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                } else {
                    Text("No native stake accounts detected for the selected scope.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                if let error = summary.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }

                if !summary.wallets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(summary.wallets) { wallet in
                            walletStakeRow(wallet)
                        }
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        switch summary.status {
        case .loaded:
            return GorkhColors.success
        case .stale, .unavailable:
            return GorkhColors.warning
        case .error:
            return GorkhColors.danger
        case .idle, .loading:
            return GorkhColors.accent
        }
    }

    private func walletStakeRow(_ wallet: StakeWalletSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(wallet.walletLabel)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text(wallet.walletPublicAddress.shortAddress)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                }
                Spacer()
                Text(solText(wallet.totalDelegatedLamports))
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                GorkhStatusChip(title: "\(wallet.accounts.count) accounts", systemImage: "list.bullet.rectangle", color: GorkhColors.accent)
            }

            if let error = wallet.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }

            ForEach(wallet.accounts.prefix(4)) { account in
                HStack(spacing: 10) {
                    Text(account.stakeAccountAddress.shortAddress)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                    GorkhStatusChip(title: account.state.title, systemImage: "circle.dashed", color: chipColor(for: account.state))
                    if let vote = account.validator?.voteAccount {
                        Text("Vote \(vote.shortAddress)")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Text(solText(account.delegatedLamports))
                        .font(.caption)
                        .foregroundStyle(GorkhColors.primaryText)
                }
            }
        }
        .padding(10)
        .background(GorkhColors.panelElevated.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func solText(_ lamports: UInt64) -> String {
        "\(TokenAmountFormatter.format(rawAmount: lamports, decimals: 9)) SOL"
    }

    private func chipColor(for state: StakeAccountState) -> Color {
        switch state {
        case .active, .delegated:
            return GorkhColors.success
        case .activating, .deactivating:
            return GorkhColors.warning
        case .inactive, .unknown:
            return GorkhColors.secondaryText
        }
    }
}
