import Foundation

enum ZerionProposalActionType: String, Codable, CaseIterable, Identifiable {
    case swap
    case bridge
    case send
    case rebalance
    case dca

    var id: String { rawValue }

    var label: String {
        switch self {
        case .swap:
            return "Swap"
        case .bridge:
            return "Bridge"
        case .send:
            return "Send"
        case .rebalance:
            return "Rebalance"
        case .dca:
            return "DCA"
        }
    }
}

enum ZerionProposalStatus: String, Codable, Equatable {
    case draft
    case blocked
    case readyForReview = "ready_for_review"
    case futureExecution = "future_execution"

    var label: String {
        switch self {
        case .draft:
            return "Draft only"
        case .blocked:
            return "Blocked"
        case .readyForReview:
            return "Ready for future review"
        case .futureExecution:
            return "Future execution"
        }
    }
}

struct ZerionProposal: Codable, Equatable, Identifiable {
    let id: UUID
    let source: String
    let actionType: ZerionProposalActionType
    let chain: String
    let amount: String
    let fromToken: String
    let toTokenOrRecipient: String
    let policyID: String?
    let expiresAt: Date?
    let status: ZerionProposalStatus
    let riskNotes: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        source: String = "zerion",
        actionType: ZerionProposalActionType,
        chain: String,
        amount: String,
        fromToken: String,
        toTokenOrRecipient: String,
        policyID: String?,
        expiresAt: Date?,
        status: ZerionProposalStatus = .draft,
        riskNotes: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.actionType = actionType
        self.chain = chain
        self.amount = amount
        self.fromToken = fromToken
        self.toTokenOrRecipient = toTokenOrRecipient
        self.policyID = policyID
        self.expiresAt = expiresAt
        self.status = status
        self.riskNotes = riskNotes.map(ZerionRedaction.redact)
        self.createdAt = createdAt
    }

    var canExecuteInA1: Bool {
        false
    }

    static let sampleDraft = ZerionProposal(
        actionType: .rebalance,
        chain: "base",
        amount: "preview only",
        fromToken: "USDC",
        toTokenOrRecipient: "ETH",
        policyID: nil,
        expiresAt: nil,
        riskNotes: [
            "Draft-only proposal. A1 cannot call Zerion trading or signing commands.",
            "Requires a separate tiny-funded Zerion wallet and scoped policy before a future review phase."
        ]
    )
}
