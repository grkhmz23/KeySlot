import Foundation

enum AgentProposalDecision: String, Codable, Equatable {
    case pending
    case approved
    case rejected
    case blocked
    case executed
    case failed
}

enum AgentProposalActionStyle: String, Codable, Equatable {
    case approve
    case sign
    case execute
    case openHandoff
    case review
}

struct AgentProposalCardDisplay: Identifiable, Codable, Equatable {
    let id: String
    let agentID: KeySlotAgentID
    let title: String
    let summary: String
    let details: [String]
    let riskLevel: String
    let status: AgentProposalDecision
    let primaryActionTitle: String
    let primaryActionStyle: AgentProposalActionStyle
    let rejectTitle: String
    let blockedReason: String?
    let requiresApproval: Bool
    let requiresSignature: Bool
    let handoffTarget: KeySlotAgentID?
    let prefill: [String: String]
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        agentID: KeySlotAgentID,
        title: String,
        summary: String,
        details: [String] = [],
        riskLevel: String = "low",
        status: AgentProposalDecision = .pending,
        primaryActionTitle: String = "Review",
        primaryActionStyle: AgentProposalActionStyle = .review,
        rejectTitle: String = "Reject",
        blockedReason: String? = nil,
        requiresApproval: Bool = false,
        requiresSignature: Bool = false,
        handoffTarget: KeySlotAgentID? = nil,
        prefill: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.agentID = agentID
        self.title = title
        self.summary = summary
        self.details = details
        self.riskLevel = riskLevel
        self.status = status
        self.primaryActionTitle = primaryActionTitle
        self.primaryActionStyle = primaryActionStyle
        self.rejectTitle = rejectTitle
        self.blockedReason = blockedReason
        self.requiresApproval = requiresApproval
        self.requiresSignature = requiresSignature
        self.handoffTarget = handoffTarget
        self.prefill = prefill
        self.createdAt = createdAt
    }
}

extension AgentProposalCardDisplay {
    static func from(globalProposal: GlobalAgentProposal, agentID: KeySlotAgentID = .global) -> AgentProposalCardDisplay {
        let primaryStyle: AgentProposalActionStyle
        let primaryTitle: String
        if globalProposal.blockedReason != nil {
            primaryStyle = .review
            primaryTitle = "Blocked"
        } else if let handoffTarget = globalProposal.handoffTarget {
            primaryStyle = .openHandoff
            primaryTitle = "Open Developer Workstation"
        } else if globalProposal.requiresApproval {
            primaryStyle = .review
            primaryTitle = "Review"
        } else {
            primaryStyle = .review
            primaryTitle = "Review"
        }

        return AgentProposalCardDisplay(
            id: globalProposal.id.uuidString,
            agentID: agentID,
            title: globalProposal.title,
            summary: globalProposal.summary,
            details: globalProposal.details,
            riskLevel: globalProposal.riskLevel,
            status: globalProposal.blockedReason != nil ? .blocked : .pending,
            primaryActionTitle: primaryTitle,
            primaryActionStyle: primaryStyle,
            blockedReason: globalProposal.blockedReason,
            requiresApproval: globalProposal.requiresApproval,
            handoffTarget: globalProposal.handoffTarget,
            prefill: globalProposal.sendPrefill.map { ["amount": $0.amount, "recipient": $0.recipient, "token": $0.token].compactMapValues { $0 } } ?? [:]
        )
    }
}
