import Foundation

enum AgentProposalFactory {
    static func makeProposal(
        classification: AgentIntentClassification,
        lane: AgentProposalLane,
        decision: AgentPolicyDecision
    ) -> AgentProposal {
        let status: AgentProposalStatus = {
            switch decision.status {
            case .allowed:
                return .readyForReview
            case .needsMoreInput:
                return .missingFields
            case .blocked:
                return .blocked
            }
        }()

        let type = proposalType(for: classification.intentType, lane: lane)
        return AgentProposal(
            type: type,
            lane: lane,
            status: status,
            title: type.title,
            summary: summary(for: classification, lane: lane),
            amount: classification.amount,
            sourceAsset: classification.sourceAsset,
            targetAsset: classification.targetAsset,
            chain: classification.chain,
            recipient: classification.recipient,
            riskFlags: classification.riskFlags,
            policyDecision: decision,
            handoffTarget: handoffTarget(for: type)
        )
    }

    private static func proposalType(for intent: AgentIntentType, lane: AgentProposalLane) -> AgentProposalType {
        switch intent {
        case .prepareSwap, .tokenBuyRequest, .tokenSwapRequest:
            return .mainWalletSwapDraft
        case .prepareSend, .tokenSendRequest:
            return .mainWalletSendDraft
        case .pusdPaymentRequest:
            return .pusdPaymentDraft
        case .yieldSearch, .yieldSummary:
            return .yieldRecommendation
        case .lpPositionReview, .liquiditySummary:
            return .lpReviewRecommendation
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
             .costBasisHelp,
             .portfolioHistorySummary,
             .riskSummary,
             .pnlSummary,
             .recentActivitySummary,
             .help,
             .whatCanYouDo,
             .missingFields,
             .unsupported,
             .unsafe,
            return .unsupported
        }
    }

    private static func handoffTarget(for type: AgentProposalType) -> AgentHandoffTarget {
        switch type {
        case .mainWalletSwapDraft:
            return .walletSwap
        case .mainWalletSendDraft, .pusdPaymentDraft:
            return .walletSend
        case .yieldRecommendation:
            return .portfolioYield
        case .lpReviewRecommendation:
            return .portfolioLiquidity
        case .unsupported:
            return .none
        }
    }

    private static func summary(for classification: AgentIntentClassification, lane: AgentProposalLane) -> String {
        switch classification.intentType {
        case .tokenBuyRequest:
            return "Prepare a wallet swap draft to buy \(classification.targetAsset ?? "token") using \(classification.sourceAsset ?? "source asset")."
        case .prepareSwap, .tokenSwapRequest:
            return "Prepare a \(lane.title) swap proposal from \(classification.sourceAsset ?? "source") to \(classification.targetAsset ?? "target"). Agent Chat will not execute it; review continues in the destination module."
        case .prepareSend, .tokenSendRequest:
            return "Prepare a wallet send draft. Wallet must simulate, review, and approve it before anything can move."
        case .pusdPaymentRequest:
            return "Prepare a PUSD payment handoff through the existing Wallet send/receive flow. Agent does not send from chat."
        default:
            return classification.summary
        }
    }
}
