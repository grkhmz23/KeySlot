import Foundation

enum AgentProposalApprovalResult: Equatable {
    case openedReview(destination: String)
    case openedHandoff(agent: KeySlotAgentID)
    case preparedPreview(summary: String)
    case blocked(reason: String)
    case unavailable(reason: String)
}
