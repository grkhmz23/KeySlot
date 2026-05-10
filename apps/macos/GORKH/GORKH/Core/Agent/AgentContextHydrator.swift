import Foundation

struct AgentHydratedContext: Codable, Equatable {
    let redactedContext: AgentRedactedContext
    let moduleSummaries: [String]
    let safetyMetadata: [String]

    var summaryText: String {
        (moduleSummaries + safetyMetadata).joined(separator: " | ")
    }
}

enum AgentContextHydrator {
    static func hydrate(
        portfolioSummary: PortfolioAggregateSummary,
        pnlSummary: PnLPortfolioSummary,
        pusdCirculationSnapshot: PUSDCirculationSnapshot,
        auditEvents: [AuditEvent],
        selectedProfile: WalletProfile?,
        selectedNetwork: WalletNetwork,
        rpcSecurityStatus: RPCProviderSecurityStatus,
        zerionStatus: ZerionStatusSnapshot,
        builtAt: Date = Date()
    ) throws -> AgentHydratedContext {
        let context = try AgentRedactedContextBuilder.build(
            portfolioSummary: portfolioSummary,
            pnlSummary: pnlSummary,
            pusdCirculationSnapshot: pusdCirculationSnapshot,
            auditEvents: auditEvents,
            selectedProfile: selectedProfile,
            selectedNetwork: selectedNetwork,
            rpcSecurityStatus: rpcSecurityStatus,
            zerionStatus: zerionStatus,
            builtAt: builtAt
        )
        let summaries = [
            "wallet:\(context.wallet.walletKind ?? "none"):\(context.wallet.network)",
            "portfolio:\(context.portfolio.status):assets=\(context.portfolio.assetCount)",
            "pusd:\(context.pusd.balance):wallets=\(context.pusd.walletCount)",
            "liquidity:\(context.liquidity.status):positions=\(context.liquidity.positionCount)",
            "yield:\(context.yield.status):apy=\(context.yield.apyAvailableCount)",
            "pnl:\(context.pnl.status):history=\(context.pnl.historyPointCount)",
            "security:\(context.security.signingGuard)",
            "zerion:\(context.zerion.cliStatus):policy=\(context.zerion.policyStatus)"
        ]
        let hydrated = AgentHydratedContext(
            redactedContext: context,
            moduleSummaries: summaries,
            safetyMetadata: context.safetyMetadata + [
                "hosted_ai_advisory_only",
                "deterministic_policy_source_of_truth",
                "no_direct_chat_execution"
            ]
        )
        try validate(hydrated)
        return hydrated
    }

    static func validate(_ hydrated: AgentHydratedContext) throws {
        let data = try JSONEncoder().encode(hydrated)
        let payload = String(data: data, encoding: .utf8) ?? ""
        if let forbidden = AgentRedactedContextBuilder.firstForbiddenMatch(in: payload) {
            throw AgentRedactedContextError.forbiddenFieldDetected(forbidden)
        }
    }
}
