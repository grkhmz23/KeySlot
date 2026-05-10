import Foundation

enum AgentDeFiOpportunityAnalyzer {
    static func analyze(
        classification: AgentIntentClassification,
        portfolioSummary: PortfolioAggregateSummary,
        pnlSummary: PnLPortfolioSummary,
        auditEvents: [AuditEvent]
    ) -> AgentToolResult {
        switch classification.intentType {
        case .lpPositionReview:
            return AgentToolResult(
                title: "LP position review",
                status: .readyForReview,
                summary: "Read-only LP review prepared from existing Meteora, Orca, and Raydium summaries.",
                bullets: [
                    "LP positions: \(portfolioSummary.lpSummary.positionCount)",
                    "Estimated LP value: \(portfolioSummary.lpSummary.estimatedValueUSD?.portfolioCurrencyText ?? "unavailable")",
                    "Partial LP adapters: \(portfolioSummary.lpSummary.partialAdapterCount)",
                    "Candidate action: review pools with higher reported yield only after checking range, liquidity, and protocol risk."
                ]
            )
        case .yieldSearch:
            return AgentToolResult(
                title: "Yield search",
                status: .readyForReview,
                summary: "Read-only yield comparison prepared from existing Wallet analytics.",
                bullets: [
                    "Held yield sources: \(portfolioSummary.yieldSummary.heldOpportunityCount)",
                    "Rates available: \(portfolioSummary.yieldSummary.apyAvailableCount)",
                    "Unavailable sources: \(portfolioSummary.yieldSummary.unavailableCount)",
                    "Candidate action: compare reported APY with risk labels; no deposit or rebalance is prepared."
                ]
            )
        case .portfolioSummary, .riskSummary:
            return AgentToolResult(
                title: classification.intentType == .riskSummary ? "Portfolio risk summary" : "Portfolio summary",
                status: .readyForReview,
                summary: "Read-only portfolio summary prepared from local Wallet data.",
                bullets: [
                    "Total value: \(portfolioSummary.totalUSD.portfolioCurrencyText)",
                    "Wallet count: \(portfolioSummary.wallets.count)",
                    "Assets: \(portfolioSummary.consolidatedAssets.count)",
                    "Lending status: \(portfolioSummary.lendingSummary.status.title)",
                    "Liquidity status: \(portfolioSummary.lpSummary.status.title)"
                ]
            )
        case .pnlSummary:
            return AgentToolResult(
                title: "Performance estimate",
                status: pnlSummary.status == .loaded ? .readyForReview : .missingFields,
                summary: "Snapshot-based performance estimate prepared. It is not tax-grade accounting.",
                bullets: [
                    "Status: \(pnlSummary.status.title)",
                    "History points: \(pnlSummary.historyPointCount)",
                    "Asset performance rows: \(pnlSummary.assetPerformances.count)",
                    "Realized PnL: \(pnlSummary.realized.status.title)"
                ]
            )
        case .recentActivitySummary:
            return AgentToolResult(
                title: "Recent activity",
                status: .readyForReview,
                summary: "Recent local activity summarized from the Wallet activity timeline.",
                bullets: auditEvents.prefix(5).map { "\($0.kind.rawValue): \($0.message)" } + (auditEvents.isEmpty ? ["No activity recorded yet."] : [])
            )
        default:
            return AgentToolResult(
                title: "No analysis available",
                status: .blocked,
                summary: "This request does not map to a read-only analysis path.",
                bullets: ["Create a proposal or ask for portfolio, risk, yield, LP, PnL, or activity analysis."]
            )
        }
    }
}
