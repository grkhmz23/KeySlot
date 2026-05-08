import SwiftUI

struct TokenBalancesView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var selectedToken: TokenBalance?

    var body: some View {
        GorkhPanel("SPL Tokens") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    GorkhStatusChip(
                        title: walletManager.selectedNetwork.displayName,
                        systemImage: walletManager.selectedNetwork.isMainnet ? "exclamationmark.triangle.fill" : "network",
                        color: walletManager.selectedNetwork.isMainnet ? GorkhColors.warning : GorkhColors.accent
                    )

                    if let fetchedAt = walletManager.tokenBalancesFetchedAt {
                        Text("Updated \(fetchedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }

                    Spacer()

                    Button {
                        Task { await walletManager.refreshTokenBalances() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.gorkhSecondary)
                    .disabled(walletManager.selectedProfile == nil || walletManager.isBusy)
                }

                if let error = walletManager.tokenBalanceError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.danger)
                } else if walletManager.tokenBalances.isEmpty {
                    Text("No SPL token accounts found for this wallet on the selected network.")
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    VStack(spacing: 8) {
                        ForEach(walletManager.tokenBalances) { token in
                            tokenRow(token)
                        }
                    }
                }

                if let selectedToken {
                    SendTokenView(token: selectedToken) {
                        self.selectedToken = nil
                    }
                }
            }
        }
    }

    private func tokenRow(_ token: TokenBalance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(token.displayLabel)
                        .font(.headline)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text(token.mintAddress)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GorkhColors.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(token.uiAmountString)
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(GorkhColors.primaryText)
                    GorkhStatusChip(
                        title: token.programKind.shortName,
                        systemImage: token.programKind == .splToken ? "circle.hexagongrid" : "exclamationmark.triangle",
                        color: token.programKind == .splToken ? GorkhColors.accent : GorkhColors.warning
                    )
                }
            }

            HStack(spacing: 8) {
                Text("Account \(token.tokenAccountAddress.shortAddress)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(GorkhColors.secondaryText)
                    .textSelection(.enabled)

                if token.state == .frozen {
                    GorkhStatusChip(title: "Frozen", systemImage: "snowflake", color: GorkhColors.warning)
                }
                if token.delegateAddress != nil {
                    GorkhStatusChip(title: "Delegated", systemImage: "person.badge.key", color: GorkhColors.warning)
                }
                if token.closeAuthorityAddress != nil {
                    GorkhStatusChip(title: "Close authority", systemImage: "xmark.seal", color: GorkhColors.warning)
                }

                Spacer()

                Button {
                    selectedToken = token
                } label: {
                    Label("Send", systemImage: "paperplane")
                }
                .buttonStyle(.gorkhSecondary)
                .disabled(!token.canSend || walletManager.vaultState != .unlocked || walletManager.isBusy)
            }
        }
        .padding(12)
        .background(GorkhColors.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
