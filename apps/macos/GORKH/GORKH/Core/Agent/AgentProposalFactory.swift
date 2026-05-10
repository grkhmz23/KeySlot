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

    static func makeZerionTinySwap(from proposal: AgentProposal) -> ZerionTinySwapProposal? {
        guard proposal.type == .zerionTinySwap,
              let amount = proposal.amount,
              let from = proposal.sourceAsset,
              let to = proposal.targetAsset else {
            return nil
        }
        let chain = ZerionExecutionChain(rawValue: proposal.chain ?? "solana") ?? .solana
        let estimatedUSD: Decimal? = from.uppercased() == "USDC" ? amount : nil
        return ZerionTinySwapProposal(
            zerionWalletName: "manual-zerion-wallet",
            chain: chain,
            fromToken: from,
            toToken: to,
            amount: amount,
            estimatedNotionalUSD: estimatedUSD,
            policyID: "manual-policy",
            policyName: "manual-policy",
            expiresAt: proposal.expiresAt,
            riskNotes: proposal.riskFlags.map(\.label) + [
                "Created by Agent chat. Execution must continue through Zerion review."
            ],
            createdAt: proposal.createdAt
        )
    }

    private static func proposalType(for intent: AgentIntentType, lane: AgentProposalLane) -> AgentProposalType {
        if lane == .zerionAgentWallet {
            return .zerionTinySwap
        }
        switch intent {
        case .tokenBuyRequest, .tokenSwapRequest:
            return .mainWalletSwapDraft
        case .tokenSendRequest:
            return .mainWalletSendDraft
        case .pusdPaymentRequest:
            return .pusdPaymentDraft
        case .cloakPrivatePaymentRequest:
            return .cloakPrivatePaymentDraft
        case .yieldSearch:
            return .yieldRecommendation
        case .lpPositionReview:
            return .lpReviewRecommendation
        case .portfolioSummary, .riskSummary, .pnlSummary, .recentActivitySummary, .unsupported, .unsafe, .zerionTinySwapRequest:
            return .unsupported
        }
    }

    private static func handoffTarget(for type: AgentProposalType) -> AgentHandoffTarget {
        switch type {
        case .mainWalletSwapDraft:
            return .walletSwap
        case .mainWalletSendDraft, .pusdPaymentDraft:
            return .walletSend
        case .cloakPrivatePaymentDraft:
            return .walletPrivate
        case .zerionTinySwap:
            return .zerionReview
        case .yieldRecommendation, .lpReviewRecommendation:
            return .walletPortfolio
        case .unsupported:
            return .none
        }
    }

    private static func summary(for classification: AgentIntentClassification, lane: AgentProposalLane) -> String {
        switch classification.intentType {
        case .tokenBuyRequest:
            return "Prepare a wallet swap draft to buy \(classification.targetAsset ?? "token") using \(classification.sourceAsset ?? "source asset")."
        case .tokenSwapRequest, .zerionTinySwapRequest:
            return "Prepare a \(lane.title) swap proposal from \(classification.sourceAsset ?? "source") to \(classification.targetAsset ?? "target")."
        case .tokenSendRequest:
            return "Prepare a wallet send draft. The Wallet module must simulate and approve it."
        case .pusdPaymentRequest:
            return "Prepare a PUSD payment handoff through the existing Wallet send/receive flow."
        case .cloakPrivatePaymentRequest:
            return "Prepare a Cloak private payment draft for Wallet -> Private review."
        default:
            return classification.summary
        }
    }
}
