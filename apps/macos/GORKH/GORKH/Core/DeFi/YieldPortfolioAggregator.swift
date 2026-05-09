import Foundation

enum YieldPortfolioAggregator {
    static func aggregate(
        scope: PortfolioWalletScope,
        network: WalletNetwork,
        lstSummary: LSTPortfolioSummary,
        lendingSummary: LendingPortfolioSummary,
        lpSummary: LPPortfolioSummary,
        pusdTreasurySummary: PUSDTreasurySummary,
        refreshedAt: Date = Date()
    ) -> YieldPortfolioSummary {
        YieldComparisonProvider.buildSummary(
            scope: scope,
            network: network,
            lstSummary: lstSummary,
            lendingSummary: lendingSummary,
            lpSummary: lpSummary,
            pusdTreasurySummary: pusdTreasurySummary,
            refreshedAt: refreshedAt
        )
    }
}
