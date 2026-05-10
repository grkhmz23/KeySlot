import Foundation

enum AgentExecutionLaneRouter {
    static func route(_ classification: AgentIntentClassification, walletIsWatchOnly: Bool = false) -> AgentProposalLane {
        if walletIsWatchOnly && classification.intentType.isExecutableIntent {
            return .watchOnlyAnalysis
        }

        switch classification.intentType {
        case .zerionTinySwapRequest, .zerionPrepareTinySwap:
            return .zerionAgentWallet
        case .tokenBuyRequest:
            if classification.input.lowercased().contains("zerion") || classification.input.lowercased().contains("agent wallet") {
                return .zerionAgentWallet
            }
            return .mainWallet
        case .prepareSwap, .tokenSwapRequest, .prepareSend, .tokenSendRequest, .pusdPaymentRequest:
            return .mainWallet
        case .prepareCloakDeposit, .cloakPrivatePaymentRequest, .prepareCloakPrivatePayment:
            return .cloakPrivate
        case .walletOverview,
             .receiveAddress,
             .explainSwap,
             .securityStatus,
             .activitySummary,
             .rpcStatus,
             .portfolioSummary,
             .assetBreakdown,
             .walletBreakdown,
             .pusdTreasurySummary,
             .stakeLstSummary,
             .lendingSummary,
             .liquiditySummary,
             .yieldSummary,
             .costBasisHelp,
             .portfolioHistorySummary,
             .riskSummary,
             .cloakStatus,
             .cloakScanSummary,
             .explainPrivateState,
             .yieldSearch,
             .lpPositionReview,
             .pnlSummary,
             .recentActivitySummary,
             .zerionStatus,
             .zerionPolicySummary,
             .zerionProposalStatus,
             .help,
             .whatCanYouDo,
             .missingFields:
            return .readOnlyAnalysis
        case .unsupported, .unsafe:
            return .unsupported
        }
    }
}
