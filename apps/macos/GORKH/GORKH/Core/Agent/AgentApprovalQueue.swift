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
}
