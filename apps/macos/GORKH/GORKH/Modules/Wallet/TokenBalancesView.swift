import SwiftUI

struct TokenBalancesView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var selectedToken: TokenBalance?
    @State private var searchText = ""

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

                if !walletManager.tokenBalances.isEmpty {
                    TextField("Search symbol, mint, or token account", text: $searchText)
                        .textFieldStyle(.roundedBorder)
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
                        ForEach(filteredTokens) { token in
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

    private var filteredTokens: [TokenBalance] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return walletManager.tokenBalances
        }

        return walletManager.tokenBalances.filter { token in
            let metadata = TokenMetadataResolver.resolve(balance: token, network: walletManager.selectedNetwork)
            return metadata.symbol.lowercased().contains(query)
                || metadata.name.lowercased().contains(query)
                || token.mintAddress.lowercased().contains(query)
                || token.tokenAccountAddress.lowercased().contains(query)
        }
    }

    private func tokenRow(_ token: TokenBalance) -> some View {
        let metadata = TokenMetadataResolver.resolve(balance: token, network: walletManager.selectedNetwork)
        let warnings = TokenMetadataResolver.warnings(for: token, metadata: metadata)
        let canSend = TokenMetadataResolver.canSend(balance: token, metadata: metadata)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metadata.displayTitle)
                        .font(.headline)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text("\(metadata.displaySubtitle) / decimals \(metadata.decimals.map(String.init) ?? "unavailable")")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GorkhColors.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    if let warning = metadata.warning {
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.warning)
                    }
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

                ForEach(warnings.prefix(4)) { warning in
                    GorkhStatusChip(
                        title: warning.title,
                        systemImage: warningSystemImage(warning),
                        color: warning.blocksSend ? GorkhColors.danger : GorkhColors.warning
                    )
                }

                Spacer()

                if walletManager.selectedProfile?.canSign == true {
                    Button {
                        selectedToken = token
                    } label: {
                        Label("Send", systemImage: "paperplane")
                    }
                    .buttonStyle(.gorkhSecondary)
                    .disabled(!canSend || walletManager.vaultState != .unlocked || walletManager.isBusy)
                } else {
                    GorkhStatusChip(title: "Watch-only", systemImage: "eye", color: GorkhColors.warning)
                }
            }
        }
        .padding(12)
        .background(GorkhColors.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func warningSystemImage(_ warning: TokenWarning) -> String {
        switch warning {
        case .unknownToken, .devnetToken:
            return "questionmark.diamond"
        case .frozenAccount:
            return "snowflake"
        case .delegatedAccount:
            return "person.badge.key"
        case .closeAuthorityPresent:
            return "xmark.seal"
        case .zeroBalance:
            return "0.circle"
        case .decimalsUnavailable:
            return "number"
        case .token2022Unsupported:
            return "lock.trianglebadge.exclamationmark"
        }
    }
}
