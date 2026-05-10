import Foundation

enum AgentApprovalQueueFilter: String, Codable, CaseIterable, Identifiable {
    case all
    case wallet
    case zerion
    case privateWallet
    case readOnly
    case blocked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .wallet:
            return "Wallet"
        case .zerion:
            return "Zerion"
        case .privateWallet:
            return "Private"
        case .readOnly:
            return "Read-only"
        case .blocked:
            return "Blocked"
        }
    }
}

struct AgentApprovalQueueItem: Codable, Equatable, Identifiable {
    let id: UUID
    let proposalID: UUID
    let title: String
    let lane: AgentProposalLane
    let status: AgentProposalStatus
    let handoffTarget: AgentHandoffTarget
    let statusDetail: String
    let canOpenHandoff: Bool
    let createdAt: Date
    let expiresAt: Date
}

struct AgentApprovalQueue: Codable, Equatable {
    let items: [AgentApprovalQueueItem]

    init(proposals: [AgentProposal]) {
        items = proposals.map { proposal in
            AgentApprovalQueueItem(
                id: proposal.id,
                proposalID: proposal.id,
                title: proposal.title,
                lane: proposal.lane,
                status: proposal.status,
                handoffTarget: proposal.handoffTarget,
                statusDetail: AgentApprovalQueue.statusDetail(for: proposal),
                canOpenHandoff: proposal.status == .readyForReview && proposal.handoffTarget != .none && proposal.isExpired == false,
                createdAt: proposal.createdAt,
                expiresAt: proposal.expiresAt
            )
        }
    }

    func filtered(by filter: AgentApprovalQueueFilter) -> [AgentApprovalQueueItem] {
        switch filter {
        case .all:
            return items
        case .wallet:
            return items.filter { $0.lane == .mainWallet }
        case .zerion:
            return items.filter { $0.lane == .zerionAgentWallet }
        case .privateWallet:
            return items.filter { $0.lane == .cloakPrivate }
        case .readOnly:
            return items.filter { $0.lane == .readOnlyAnalysis || $0.lane == .watchOnlyAnalysis }
        case .blocked:
            return items.filter { $0.status == .blocked || $0.status == .missingFields }
        }
    }

    var readyCount: Int {
        items.filter { $0.status == .readyForReview }.count
    }

    private static func statusDetail(for proposal: AgentProposal) -> String {
        if proposal.isExpired {
            return "Expired. Create a fresh proposal before review."
        }
        switch proposal.status {
        case .readyForReview:
            return "Ready for handoff. Review and approval stay in \(proposal.handoffTarget.title)."
        case .missingFields:
            return proposal.policyDecision.reasons.first ?? "More details are needed before review."
        case .blocked:
            return proposal.policyDecision.reasons.first ?? "Blocked by local Agent policy."
        case .draft:
            return "Draft only. It cannot execute from Agent Chat."
        case .handedOff:
            return "Handed off. Continue in the destination module."
        case .approvedInDestination:
            return "Approved in destination module."
        case .executedInDestination:
            return "Executed by destination module, not Agent Chat."
        case .failedInDestination:
            return "Destination module reported failure."
        }
    }
}
