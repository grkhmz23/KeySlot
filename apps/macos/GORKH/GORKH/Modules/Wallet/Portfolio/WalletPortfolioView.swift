import SwiftUI

struct WalletPortfolioView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GorkhPanel("Portfolio") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Picker("Scope", selection: Binding(
                            get: { walletManager.selectedPortfolioScope },
                            set: { walletManager.setPortfolioScope($0) }
                        )) {
                            ForEach(PortfolioWalletScope.allCases) { scope in
                                Text(scope.title).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 520)

                        Spacer()

                        Button {
                            Task { await walletManager.refreshPortfolio() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.keyslotPrimary)
                        .disabled(walletManager.isBusy)
                    }

                    HStack(spacing: 8) {
                        GorkhStatusChip(
                            title: walletManager.portfolioStatus.title,
                            systemImage: walletManager.portfolioStatus == .loaded ? "checkmark.seal" : "clock",
                            color: walletManager.portfolioStatus == .loaded ? GorkhColors.success : GorkhColors.warning
                        )
                        GorkhStatusChip(
                            title: walletManager.selectedNetwork.displayName,
                            systemImage: walletManager.selectedNetwork.isMainnet ? "exclamationmark.triangle.fill" : "network",
                            color: walletManager.selectedNetwork.isMainnet ? GorkhColors.warning : GorkhColors.accent
                        )
                        GorkhStatusChip(title: "Read-only", systemImage: "eye", color: GorkhColors.accent)
                    }

                    Text("USD values are estimates from public price data. Portfolio never requests signing and never builds transactions.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)

                    if let error = walletManager.portfolioErrorMessage, !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.warning)
                    }
                }
            }

            portfolioSectionHeader(
                "Summary",
                subtitle: "Estimated value, PUSD treasury, and read-only scope."
            )
            PortfolioSummaryView(summary: walletManager.portfolioSummary)
            PUSDTreasuryView()

            portfolioSectionHeader(
                "Assets & Wallets",
                subtitle: "Token balances and per-wallet exposure."
            )
            PortfolioAssetListView(summary: walletManager.portfolioSummary)
            PortfolioWalletBreakdownView(summary: walletManager.portfolioSummary)

            portfolioSectionHeader(
                "Performance",
                subtitle: "Snapshot-based performance estimates and local cost-basis completeness."
            )
            PortfolioPnLView(
                summary: walletManager.portfolioPnLSummary,
                costBasisEntries: walletManager.costBasisEntries
            )

            portfolioSectionHeader(
                "History",
                subtitle: "Local snapshots used for trend and performance estimates."
            )
            PortfolioHistoryView(
                snapshots: walletManager.portfolioHistory,
                clearAction: walletManager.clearPortfolioHistory(confirmation:)
            )
        }
        .accessibilityIdentifier("wallet.portfolio")
    }

    private func portfolioSectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
        .padding(.top, 4)
    }
}
