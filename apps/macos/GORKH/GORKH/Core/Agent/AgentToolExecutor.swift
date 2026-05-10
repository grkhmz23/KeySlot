import Foundation

struct AgentToolExecutionContext {
    let portfolioSummary: PortfolioAggregateSummary
    let pnlSummary: PnLPortfolioSummary
    let pusdCirculationSnapshot: PUSDCirculationSnapshot
    let auditEvents: [AuditEvent]
    let selectedProfile: WalletProfile?
    let selectedNetwork: WalletNetwork
    let walletBalance: WalletBalance?
    let vaultState: WalletVaultState
    let rpcSecurityStatus: RPCProviderSecurityStatus
    let cloakAdapterStatus: CloakAdapterStatus
    let cloakVaultStatus: CloakVaultStatus
    let cloakScanSummary: CloakScanSummary
    let zerionStatus: ZerionStatusSnapshot
}

enum AgentToolExecutor {
    static func execute(
        classification: AgentIntentClassification,
        context: AgentToolExecutionContext
    ) -> AgentToolResult? {
        guard let toolID = AgentToolRegistry.defaultTool(for: classification.intentType),
              let declaration = AgentToolRegistry.declaration(for: toolID),
              declaration.mode == .readOnly else {
            return nil
        }

        switch toolID {
        case .getWalletOverviewSummary:
            return AgentToolResult(
                title: "Wallet overview",
                status: .readyForReview,
                summary: "Wallet overview prepared from local state. No transaction was built.",
                bullets: [
                    "Active wallet: \(context.selectedProfile?.label ?? "No wallet selected")",
                    "Network: \(context.selectedNetwork.displayName)",
                    "SOL balance: \(context.walletBalance?.solText ?? "unavailable")",
                    "Portfolio value: \(context.portfolioSummary.totalUSD.portfolioCurrencyText)",
                    "Receive uses a public address only and never exposes wallet secrets."
                ]
            )
        case .getPortfolioSummary:
            return AgentToolResult(
                title: classification.intentType == .riskSummary ? "Portfolio risk summary" : "Portfolio summary",
                status: .readyForReview,
                summary: "Portfolio summary prepared from existing Wallet analytics.",
                bullets: [
                    "Total value: \(context.portfolioSummary.totalUSD.portfolioCurrencyText)",
                    "Wallets: \(context.portfolioSummary.wallets.count)",
                    "Assets: \(context.portfolioSummary.consolidatedAssets.count)",
                    "Unavailable prices: \(context.portfolioSummary.unavailablePriceCount)",
                    "DeFi values are shown separately where GORKH avoids double-counting."
                ]
            )
        case .getAssetSummary:
            return AgentToolResult(
                title: "Asset breakdown",
                status: context.portfolioSummary.consolidatedAssets.isEmpty ? .missingFields : .readyForReview,
                summary: "Asset breakdown prepared from consolidated token balances.",
                bullets: context.portfolioSummary.consolidatedAssets.prefix(5).map {
                    "\($0.symbol): \($0.uiAmountString), value \($0.totalUSD?.portfolioCurrencyText ?? "unavailable")"
                } + (context.portfolioSummary.consolidatedAssets.isEmpty ? ["No assets are loaded for the selected scope."] : [])
            )
        case .getPUSDSummary:
            return AgentToolResult(
                title: "PUSD Treasury",
                status: .readyForReview,
                summary: "PUSD treasury summary prepared. PUSD send still uses the existing Wallet approval flow.",
                bullets: [
                    "Balance: \(context.portfolioSummary.pusdTreasurySummary.uiAmountString) PUSD",
                    "Estimated value: \(context.portfolioSummary.pusdTreasurySummary.estimatedUSD?.portfolioCurrencyText ?? "unavailable")",
                    "Wallets holding PUSD: \(context.portfolioSummary.pusdTreasurySummary.holdingWalletCount)",
                    "Circulation API: \(context.pusdCirculationSnapshot.status.title)",
                    "PUSD yield is not active in GORKH."
                ]
            )
        case .getStakeLstSummary:
            return AgentToolResult(
                title: "Stake / LST summary",
                status: .readyForReview,
                summary: "Stake and liquid-staking summary prepared from Portfolio data.",
                bullets: [
                    "Native stake accounts: \(context.portfolioSummary.nativeStakeSummary.accountCount)",
                    "Native stake estimated value: \(context.portfolioSummary.nativeStakeSummary.estimatedUSD?.portfolioCurrencyText ?? "unavailable")",
                    "LST holdings: \(context.portfolioSummary.lstSummary.holdingCount)",
                    "LST value: \(context.portfolioSummary.lstSummary.totalUSD?.portfolioCurrencyText ?? "unavailable")",
                    "Stake and unstake execution is not available from Agent chat."
                ]
            )
        case .getLendingSummary:
            return AgentToolResult(
                title: "Lending summary",
                status: .readyForReview,
                summary: "Lending summary prepared from read-only Kamino and MarginFi data.",
                bullets: [
                    "Status: \(context.portfolioSummary.lendingSummary.status.title)",
                    "Positions: \(context.portfolioSummary.lendingSummary.positionCount)",
                    "Supplied: \(context.portfolioSummary.lendingSummary.suppliedValueUSD?.portfolioCurrencyText ?? "unavailable")",
                    "Borrowed: \(context.portfolioSummary.lendingSummary.borrowedValueUSD?.portfolioCurrencyText ?? "unavailable")",
                    "Agent chat cannot deposit, borrow, repay, or withdraw."
                ]
            )
        case .getLiquiditySummary:
            return AgentToolResult(
                title: "Liquidity summary",
                status: .readyForReview,
                summary: "LP summary prepared from Meteora, Orca, and Raydium coverage.",
                bullets: [
                    "Status: \(context.portfolioSummary.lpSummary.status.title)",
                    "Positions: \(context.portfolioSummary.lpSummary.positionCount)",
                    "Estimated value: \(context.portfolioSummary.lpSummary.estimatedValueUSD?.portfolioCurrencyText ?? "unavailable")",
                    "Partial adapters: \(context.portfolioSummary.lpSummary.partialAdapterCount)",
                    "Agent chat can review positions but cannot add, remove, or close liquidity."
                ]
            )
        case .getYieldSummary:
            return AgentToolResult(
                title: "Yield summary",
                status: .readyForReview,
                summary: "Yield comparison prepared from existing read-only Wallet sources.",
                bullets: [
                    "Status: \(context.portfolioSummary.yieldSummary.status.title)",
                    "Held sources: \(context.portfolioSummary.yieldSummary.heldOpportunityCount)",
                    "Rates available: \(context.portfolioSummary.yieldSummary.apyAvailableCount)",
                    "Unavailable sources: \(context.portfolioSummary.yieldSummary.unavailableCount)",
                    "Reported APY/APR is shown only when available from safe sources."
                ]
            )
        case .getPnLSummary:
            return AgentToolResult(
                title: classification.intentType == .costBasisHelp ? "Cost basis help" : "Performance estimate",
                status: context.pnlSummary.status == .loaded ? .readyForReview : .missingFields,
                summary: "Snapshot-based performance estimate prepared. It is not tax-grade accounting.",
                bullets: [
                    "Status: \(context.pnlSummary.status.title)",
                    "History points: \(context.pnlSummary.historyPointCount)",
                    "Asset rows: \(context.pnlSummary.assetPerformances.count)",
                    "Realized PnL: \(context.pnlSummary.realized.status.title)",
                    "Manual cost basis may be needed when history or prices are incomplete."
                ]
            )
        case .getActivitySummary:
            return AgentToolResult(
                title: "Activity summary",
                status: .readyForReview,
                summary: "Recent local activity summarized from the Wallet Activity timeline.",
                bullets: context.auditEvents.prefix(5).map { "\($0.kind.rawValue): \($0.message)" } + (context.auditEvents.isEmpty ? ["No activity recorded yet."] : [])
            )
        case .getSecuritySummary:
            return AgentToolResult(
                title: "Security summary",
                status: .readyForReview,
                summary: "Security status prepared from local Wallet and RPC settings.",
                bullets: [
                    "Wallet lock: \(context.vaultState.title)",
                    "Selected wallet can sign: \(context.selectedProfile?.canSign == true ? "yes" : "no")",
                    "LocalAuthentication: required by approval flows where available",
                    "Mainnet protection: exact confirmation remains required",
                    "Agent cannot directly move funds from chat."
                ]
            )
        case .getRPCStatus:
            return AgentToolResult(
                title: "RPC status",
                status: .readyForReview,
                summary: "RPC status prepared with token values redacted.",
                bullets: [
                    "Provider: \(context.rpcSecurityStatus.provider.displayName)",
                    "Network: \(context.rpcSecurityStatus.network.rawValue)",
                    "Token status: \(context.rpcSecurityStatus.tokenStatus.displayName)",
                    "Health: \(context.rpcSecurityStatus.beamStatus)"
                ]
            )
        case .getCloakStatus:
            return AgentToolResult(
                title: "Cloak status",
                status: .readyForReview,
                summary: "Cloak private wallet status prepared without exposing private state.",
                bullets: [
                    "Adapter: \(context.cloakAdapterStatus.title)",
                    "Vault: \(context.cloakVaultStatus.privateWalletStatus.title)",
                    "Viewing key reference: \(context.cloakVaultStatus.hasViewingKeyReference ? "stored locally" : "unavailable")",
                    "Scan status: \(context.cloakScanSummary.status.title)",
                    "Cloak execution stays inside Wallet -> Private review."
                ]
            )
        case .getZerionStatus:
            return AgentToolResult(
                title: "Zerion status",
                status: .readyForReview,
                summary: "Zerion executor status prepared with API key and agent token redacted.",
                bullets: [
                    "CLI: \(context.zerionStatus.cliStatus.label)",
                    "API key: \(context.zerionStatus.apiKeyStatus.label)",
                    "Agent token: \(context.zerionStatus.agentTokenStatus.label)",
                    "Policy: \(context.zerionStatus.policyStatus.label)",
                    "Tiny swap shape: \(context.zerionStatus.swapCommandShape.label)"
                ]
            )
        case .draftMainWalletSwap,
             .draftMainWalletSend,
             .draftPUSDPayment,
             .draftCloakPayment,
             .draftZerionTinySwap,
             .executeSwap,
             .executeSend,
             .executeBridge,
             .executeCloakPayment,
             .signTransaction,
             .sendTransaction,
             .runShell,
             .exportSeed,
             .revealPrivateKey,
             .arbitraryCommand:
            return nil
        }
    }
}
