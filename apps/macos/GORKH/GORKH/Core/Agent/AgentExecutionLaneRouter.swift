import Foundation

enum AgentExecutionLaneRouter {
    static func route(_ classification: AgentIntentClassification, walletIsWatchOnly: Bool = false) -> AgentProposalLane {
        if walletIsWatchOnly && classification.intentType.isExecutableIntent {
            return .watchOnlyAnalysis
        }

        switch classification.intentType {
        case .zerionTinySwapRequest:
            return .zerionAgentWallet
        case .tokenBuyRequest:
            if classification.input.lowercased().contains("zerion") || classification.input.lowercased().contains("agent wallet") {
                return .zerionAgentWallet
            }
            return .mainWallet
        case .tokenSwapRequest, .tokenSendRequest, .pusdPaymentRequest:
            return .mainWallet
        case .cloakPrivatePaymentRequest:
            return .cloakPrivate
        case .portfolioSummary, .riskSummary, .yieldSearch, .lpPositionReview, .pnlSummary, .recentActivitySummary:
            return .readOnlyAnalysis
        case .unsupported, .unsafe:
            return .unsupported
        }
    }
}
