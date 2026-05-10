import Foundation

enum AgentProposalType: String, Codable, CaseIterable, Identifiable, Equatable {
    case mainWalletSwapDraft
    case mainWalletSendDraft
    case pusdPaymentDraft
    case cloakPrivatePaymentDraft
    case zerionTinySwap
    case yieldRecommendation
    case lpReviewRecommendation
    case unsupported

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mainWalletSwapDraft:
            return "Wallet swap draft"
        case .mainWalletSendDraft:
            return "Wallet send draft"
        case .pusdPaymentDraft:
            return "PUSD payment draft"
        case .cloakPrivatePaymentDraft:
            return "Private payment draft"
        case .zerionTinySwap:
            return "Zerion tiny swap"
        case .yieldRecommendation:
            return "Yield review"
        case .lpReviewRecommendation:
            return "LP review"
        case .unsupported:
            return "Unsupported"
        }
    }
}

enum AgentProposalLane: String, Codable, CaseIterable, Identifiable, Equatable {
    case mainWallet
    case zerionAgentWallet
    case watchOnlyAnalysis
    case cloakPrivate
    case readOnlyAnalysis
    case unsupported

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mainWallet:
            return "Main Wallet"
        case .zerionAgentWallet:
            return "Zerion Agent Wallet"
        case .watchOnlyAnalysis:
            return "Watch-only Analysis"
        case .cloakPrivate:
            return "Cloak Private"
        case .readOnlyAnalysis:
            return "Read-only Analysis"
        case .unsupported:
            return "Unsupported"
        }
    }
}

enum AgentProposalStatus: String, Codable, CaseIterable, Identifiable, Equatable {
    case draft
    case missingFields = "missing_fields"
    case blocked
    case readyForReview = "ready_for_review"
    case handedOff = "handed_off"
    case approvedInDestination = "approved_in_destination"
    case executedInDestination = "executed_in_destination"
    case failedInDestination = "failed_in_destination"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draft:
            return "Draft"
        case .missingFields:
            return "Needs details"
        case .blocked:
            return "Blocked"
        case .readyForReview:
            return "Ready for review"
        case .handedOff:
            return "Handed off"
        case .approvedInDestination:
            return "Approved in destination"
        case .executedInDestination:
            return "Executed in destination"
        case .failedInDestination:
            return "Failed in destination"
        }
    }
}

enum AgentHandoffTarget: String, Codable, CaseIterable, Identifiable, Equatable {
    case walletOverview
    case walletReceive
    case walletSwap
    case walletSend
    case walletPrivate
    case walletPortfolio
    case portfolioAssets
    case portfolioWallets
    case portfolioPUSD
    case portfolioStake
    case portfolioLending
    case portfolioLiquidity
    case portfolioYield
    case portfolioPnL
    case portfolioHistory
    case walletSecurity
    case walletActivity
    case zerionReview
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walletOverview:
            return "Open Wallet Overview"
        case .walletReceive:
            return "Open Receive"
        case .walletSwap:
            return "Open Swap Review"
        case .walletSend:
            return "Open Send"
        case .walletPrivate:
            return "Open Private"
        case .walletPortfolio:
            return "Open Portfolio"
        case .portfolioAssets:
            return "Open Portfolio Assets"
        case .portfolioWallets:
            return "Open Portfolio Wallets"
        case .portfolioPUSD:
            return "Open PUSD Treasury"
        case .portfolioStake:
            return "Open Stake / LST"
        case .portfolioLending:
            return "Open Lending"
        case .portfolioLiquidity:
            return "Open Liquidity"
        case .portfolioYield:
            return "Open Yield"
        case .portfolioPnL:
            return "Open PnL"
        case .portfolioHistory:
            return "Open Portfolio History"
        case .walletSecurity:
            return "Open Security"
        case .walletActivity:
            return "Open Activity"
        case .zerionReview:
            return "Open Zerion Review"
        case .none:
            return "No handoff"
        }
    }
}

enum AgentPolicyDecisionStatus: String, Codable, Equatable {
    case allowed
    case blocked
    case needsMoreInput = "needs_more_input"
}

struct AgentPolicyDecision: Codable, Equatable {
    let status: AgentPolicyDecisionStatus
    let reasons: [String]
    let warnings: [String]
    let checkedAt: Date

    var canCreateProposal: Bool {
        status == .allowed || status == .needsMoreInput
    }

    static func allowed(warnings: [String] = []) -> AgentPolicyDecision {
        AgentPolicyDecision(status: .allowed, reasons: [], warnings: warnings.map(AgentSafetyRedactor.redact), checkedAt: Date())
    }

    static func blocked(_ reasons: [String], warnings: [String] = []) -> AgentPolicyDecision {
        AgentPolicyDecision(status: .blocked, reasons: reasons.map(AgentSafetyRedactor.redact), warnings: warnings.map(AgentSafetyRedactor.redact), checkedAt: Date())
    }

    static func needsMoreInput(_ reasons: [String], warnings: [String] = []) -> AgentPolicyDecision {
        AgentPolicyDecision(status: .needsMoreInput, reasons: reasons.map(AgentSafetyRedactor.redact), warnings: warnings.map(AgentSafetyRedactor.redact), checkedAt: Date())
    }
}

struct AgentProposal: Codable, Equatable, Identifiable {
    let id: UUID
    let type: AgentProposalType
    let lane: AgentProposalLane
    let status: AgentProposalStatus
    let title: String
    let summary: String
    let amount: Decimal?
    let sourceAsset: String?
    let targetAsset: String?
    let chain: String?
    let recipient: String?
    let riskFlags: [AgentRiskFlag]
    let policyDecision: AgentPolicyDecision
    let handoffTarget: AgentHandoffTarget
    let expiresAt: Date
    let createdAt: Date

    init(
        id: UUID = UUID(),
        type: AgentProposalType,
        lane: AgentProposalLane,
        status: AgentProposalStatus,
        title: String,
        summary: String,
        amount: Decimal?,
        sourceAsset: String?,
        targetAsset: String?,
        chain: String?,
        recipient: String?,
        riskFlags: [AgentRiskFlag],
        policyDecision: AgentPolicyDecision,
        handoffTarget: AgentHandoffTarget,
        expiresAt: Date = Date().addingTimeInterval(10 * 60),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.lane = lane
        self.status = status
        self.title = AgentSafetyRedactor.redact(title)
        self.summary = AgentSafetyRedactor.redact(summary)
        self.amount = amount
        self.sourceAsset = sourceAsset.map(AgentSafetyRedactor.redact)
        self.targetAsset = targetAsset.map(AgentSafetyRedactor.redact)
        self.chain = chain.map { $0.lowercased() }
        self.recipient = recipient.map(AgentSafetyRedactor.redact)
        self.riskFlags = riskFlags
        self.policyDecision = policyDecision
        self.handoffTarget = handoffTarget
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }

    var isExpired: Bool {
        expiresAt <= Date()
    }

    func replacingStatus(_ newStatus: AgentProposalStatus) -> AgentProposal {
        AgentProposal(
            id: id,
            type: type,
            lane: lane,
            status: newStatus,
            title: title,
            summary: summary,
            amount: amount,
            sourceAsset: sourceAsset,
            targetAsset: targetAsset,
            chain: chain,
            recipient: recipient,
            riskFlags: riskFlags,
            policyDecision: policyDecision,
            handoffTarget: handoffTarget,
            expiresAt: expiresAt,
            createdAt: createdAt
        )
    }
}
