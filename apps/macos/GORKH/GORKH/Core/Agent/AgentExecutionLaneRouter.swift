import Foundation

enum AgentExecutionLaneRouter {
    static func route(_ classification: AgentIntentClassification, walletIsWatchOnly: Bool = false) -> AgentProposalLane {
        if walletIsWatchOnly && classification.intentType.isExecutableIntent {
            return .watchOnlyAnalysis
        }

        switch classification.intentType {
        case .tokenBuyRequest:
            return .mainWallet
        case .prepareSwap, .tokenSwapRequest, .prepareSend, .tokenSendRequest, .pusdPaymentRequest:
            return .mainWallet
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
             .yieldSearch,
             .lpPositionReview,
             .pnlSummary,
             .recentActivitySummary,
             .help,
             .whatCanYouDo,
             .missingFields:
            return .readOnlyAnalysis
        case .unsupported, .unsafe:
            return .unsupported
        }
    }
}
