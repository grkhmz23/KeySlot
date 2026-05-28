import SwiftUI

enum DeFiTab: String, CaseIterable, Identifiable {
    case pusd = "PUSD"
    case yield = "Yield"
    case lending = "Lending"
    case stake = "Stake & LST"
    case liquidity = "Liquidity"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .pusd: return "dollarsign.circle"
        case .yield: return "chart.line.uptrend.xyaxis"
        case .lending: return "banknote"
        case .stake: return "server.rack"
        case .liquidity: return "drop"
        }
    }
}

struct WalletDeFiView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var selectedTab: DeFiTab = .pusd
    @State private var orcaHarvestMainnetConfirmation = ""
    @State private var orcaHarvestDevnetSmokeCompleted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GorkhPanel("DeFi") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        GorkhStatusChip(
                            title: walletManager.selectedNetwork.displayName,
                            systemImage: walletManager.selectedNetwork.isMainnet ? "exclamationmark.triangle.fill" : "network",
                            color: walletManager.selectedNetwork.isMainnet ? GorkhColors.warning : GorkhColors.accent
                        )
                        GorkhStatusChip(title: "Read-only", systemImage: "eye", color: GorkhColors.accent)
                        GorkhStatusChip(title: "Execution locked", systemImage: "lock", color: GorkhColors.warning)
                    }

                    Text("DeFi positions are read-only summaries. No transactions are built or signed without explicit review.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)

                    Picker("DeFi Section", selection: $selectedTab) {
                        ForEach(DeFiTab.allCases) { tab in
                            Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 520)

                    Button {
                        Task { await walletManager.refreshPortfolio() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.keyslotPrimary)
                    .disabled(walletManager.isBusy)
                }
            }

            switch selectedTab {
            case .pusd:
                PUSDTreasuryView()
            case .yield:
                PortfolioYieldView(summary: walletManager.portfolioSummary.yieldSummary)
            case .lending:
                PortfolioLendingView(summary: walletManager.portfolioSummary.lendingSummary)
            case .stake:
                PortfolioStakeView(summary: walletManager.portfolioSummary.nativeStakeSummary)
                PortfolioLSTView(summary: walletManager.portfolioSummary.lstSummary)
            case .liquidity:
                PortfolioLiquidityView(
                    summary: walletManager.portfolioSummary.lpSummary,
                    harvestDraft: walletManager.currentOrcaHarvestDraft,
                    harvestReview: walletManager.currentOrcaHarvestReview,
                    harvestSimulation: walletManager.orcaHarvestSimulationResult,
                    harvestApprovalState: walletManager.orcaHarvestApprovalState,
                    harvestErrorMessage: walletManager.orcaHarvestErrorMessage,
                    mainnetConfirmation: $orcaHarvestMainnetConfirmation,
                    completedDevnetSmoke: $orcaHarvestDevnetSmokeCompleted,
                    prepareHarvestAction: { position in
                        Task { await walletManager.prepareOrcaHarvest(position: position) }
                    },
                    simulateHarvestAction: {
                        Task { await walletManager.simulateCurrentOrcaHarvest() }
                    },
                    approveHarvestAction: {
                        Task {
                            await walletManager.approveAndSendOrcaHarvest(
                                mainnetConfirmation: orcaHarvestMainnetConfirmation,
                                hasCompletedDevnetSmoke: orcaHarvestDevnetSmokeCompleted
                            )
                        }
                    },
                    resetHarvestAction: walletManager.resetOrcaHarvestState
                )
            }
        }
        .accessibilityIdentifier("wallet.defi")
    }
}
