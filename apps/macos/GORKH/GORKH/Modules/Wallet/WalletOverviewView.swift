import SwiftUI

struct WalletOverviewView: View {
    @EnvironmentObject private var walletManager: WalletManager
    let navigate: (WalletSection) -> Void
    @State private var showingReceive = false
    private let actionColumns = [GridItem(.adaptive(minimum: 128), spacing: 8)]
    private let metricColumns = [GridItem(.adaptive(minimum: 180), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if walletManager.selectedProfile == nil {
                WalletEmptyStateView(content: .noWallet)
            }

            GorkhPanel("Overview") {
                VStack(alignment: .leading, spacing: 14) {
                    WalletSecurityStatusStripView()

                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                        overviewMetric("Total value", value: walletManager.portfolioSummary.totalUSD.portfolioCurrencyText, icon: "chart.pie")
                        overviewMetric("SOL", value: solBalanceText, icon: "circle.grid.cross")
                        overviewMetric("PUSD", value: "\(walletManager.portfolioSummary.pusdTreasurySummary.uiAmountString) PUSD", icon: "dollarsign.circle")
                        overviewMetric("Private", value: privateStatusText, icon: "eye.slash")
                    }

                    if let profile = walletManager.selectedProfile {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active wallet")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            HStack {
                                Text(profile.label)
                                    .font(.headline)
                                    .foregroundStyle(GorkhColors.primaryText)
                                GorkhStatusChip(
                                    title: profile.profileKind.displayName,
                                    systemImage: profile.canSign ? "key" : "eye",
                                    color: profile.canSign ? GorkhColors.accent : GorkhColors.warning
                                )
                                Spacer()
                            }
                            Text(profile.publicAddress)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(GorkhColors.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                    }

                    LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 8) {
                        primaryAction("Send", systemImage: "paperplane", section: .send, disabled: walletManager.selectedProfile?.canSign != true)
                        primaryAction("Swap", systemImage: "arrow.left.arrow.right", section: .swap, disabled: walletManager.selectedProfile?.canSign != true)
                        Button {
                            showingReceive.toggle()
                        } label: {
                            Label("Receive", systemImage: "qrcode")
                        }
                        .buttonStyle(.gorkhSecondary)
                        .disabled(walletManager.selectedProfile == nil)
                        .accessibilityLabel("Receive public address")
                        primaryAction("Private", systemImage: "eye.slash", section: .privateWallet, disabled: walletManager.selectedProfile?.canSign != true)
                        primaryAction("Portfolio", systemImage: "chart.pie", section: .portfolio, disabled: false)
                    }

                    if showingReceive {
                        WalletReceiveView()
                    }
                }
            }

            topAssets
            portfolioState
            recentActivity
        }
        .accessibilityIdentifier("wallet.overview")
    }

    private var solBalanceText: String {
        if let balance = walletManager.balance {
            return balance.solText
        }
        if let sol = walletManager.portfolioSummary.consolidatedAssets.first(where: { $0.isNativeSOL }) {
            return "\(sol.uiAmountString) SOL"
        }
        return "Not loaded"
    }

    private var privateStatusText: String {
        let unspent = walletManager.cloakPrivateRecords.filter { $0.state == .deposited }.count
        if unspent > 0 {
            return "\(unspent) local record\(unspent == 1 ? "" : "s")"
        }
        return walletManager.cloakVaultStatus.privateWalletStatus.title
    }

    private var topAssets: some View {
        GorkhPanel("Top Assets") {
            let assets = walletManager.portfolioSummary.consolidatedAssets.prefix(5)
            if assets.isEmpty {
                WalletEmptyStateView(content: .noBalance) {
                    Task { await walletManager.refreshPortfolio() }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(assets)) { asset in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(asset.symbol)
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(GorkhColors.primaryText)
                                Text(asset.isNativeSOL ? "Solana" : asset.mintAddress.shortAddress)
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.secondaryText)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(asset.uiAmountString)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(GorkhColors.primaryText)
                                Text(asset.totalUSD?.portfolioCurrencyText ?? "Price unavailable")
                                    .font(.caption)
                                    .foregroundStyle(asset.totalUSD == nil ? GorkhColors.warning : GorkhColors.secondaryText)
                            }
                        }
                    }
                }
            }
        }
    }

    private var portfolioState: some View {
        GorkhPanel("What Can I Safely Do?") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], alignment: .leading, spacing: 10) {
                safetyItem("Send", value: walletManager.selectedProfile?.canSign == true ? "Requires unlock, simulation, approval" : "Watch-only")
                safetyItem("Swap", value: "Quote, review, simulate, approve")
                safetyItem("DeFi", value: "Lending and yield are read-only")
                safetyItem("LP", value: "Only Orca harvest has guarded execution")
                safetyItem("Private", value: "Mainnet only, local private state")
                safetyItem("PnL", value: "Estimate, not tax-grade")
            }
        }
    }

    private var recentActivity: some View {
        GorkhPanel("Recent Activity") {
            if walletManager.auditEvents.isEmpty {
                WalletEmptyStateView(content: WalletEmptyStateContent(
                    title: "No recent activity",
                    message: "Wallet activity will appear after refreshes, sends, swaps, private actions, and security events.",
                    systemImage: "clock",
                    actionTitle: nil
                ))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(walletManager.auditEvents.prefix(5)) { event in
                        let category = WalletActivityCategory.category(for: event.kind)
                        HStack(spacing: 8) {
                            GorkhStatusChip(title: category.title, systemImage: category.systemImage, color: category.color)
                            Text(event.message)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.primaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            Text(event.createdAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                    }

                    Button {
                        navigate(.activity)
                    } label: {
                        Label("Open Activity", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.gorkhSecondary)
                }
            }
        }
    }

    private func overviewMetric(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(.system(.callout, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(10)
        .background(GorkhColors.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func safetyItem(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(GorkhColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func primaryAction(_ title: String, systemImage: String, section: WalletSection, disabled: Bool) -> some View {
        Button {
            navigate(section)
        } label: {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(title == "Send" ? .gorkhPrimary : .gorkhSecondary)
        .disabled(disabled)
        .accessibilityLabel(title)
    }
}
