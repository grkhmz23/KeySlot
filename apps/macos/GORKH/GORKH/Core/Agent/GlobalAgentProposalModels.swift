import Foundation

enum GlobalAgentProposalKind: String, Codable {
    case sendPaymentDraft
    case receiveRequestDraft
    case depositDraft
    case swapDraft
    case transactionReview
    case developerWorkstationHandoff
    case unsupported
}

struct SendPrefillData: Codable, Equatable {
    let amount: String?
    let recipient: String?
    let token: String?
}

struct GlobalAgentProposal: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: GlobalAgentProposalKind
    let title: String
    let summary: String
    let details: [String]
    let riskLevel: String
    let requiresApproval: Bool
    let handoffTarget: KeySlotAgentID?
    let blockedReason: String?
    let sendPrefill: SendPrefillData?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: GlobalAgentProposalKind,
        title: String,
        summary: String,
        details: [String] = [],
        riskLevel: String = "low",
        requiresApproval: Bool = false,
        handoffTarget: KeySlotAgentID? = nil,
        blockedReason: String? = nil,
        sendPrefill: SendPrefillData? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.details = details
        self.riskLevel = riskLevel
        self.requiresApproval = requiresApproval
        self.handoffTarget = handoffTarget
        self.blockedReason = blockedReason
        self.sendPrefill = sendPrefill
        self.createdAt = createdAt
    }

    static func blocked(title: String, reason: String, details: [String] = []) -> GlobalAgentProposal {
        GlobalAgentProposal(
            kind: .unsupported,
            title: title,
            summary: "Blocked: \(reason)",
            details: details,
            riskLevel: "blocked",
            blockedReason: reason
        )
    }

    static func handoff(target: KeySlotAgentID, title: String, summary: String, details: [String] = []) -> GlobalAgentProposal {
        GlobalAgentProposal(
            kind: .developerWorkstationHandoff,
            title: title,
            summary: summary,
            details: details,
            riskLevel: "low",
            handoffTarget: target
        )
    }
}
