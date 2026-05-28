import Foundation

enum AgentToolID: String, Codable, CaseIterable, Identifiable, Equatable {
    case getWalletOverviewSummary
    case getPortfolioSummary
    case getAssetSummary
    case getPUSDSummary
    case getStakeLstSummary
    case getLendingSummary
    case getLiquiditySummary
    case getYieldSummary
    case getPnLSummary
    case getActivitySummary
    case getSecuritySummary
    case getRPCStatus
    case draftMainWalletSwap
    case draftMainWalletSend
    case draftPUSDPayment
    case executeSwap
    case executeSend
    case executeBridge
    case signTransaction
    case sendTransaction
    case runShell
    case exportSeed
    case revealPrivateKey
    case arbitraryCommand

    var id: String { rawValue }
}

enum AgentToolMode: String, Codable, Equatable {
    case readOnly = "read_only"
    case draftOnly = "draft_only"
    case blocked
}

enum AgentToolRedactionClass: String, Codable, Equatable {
    case publicSummary = "public_summary"
    case walletSummary = "wallet_summary"
    case proposalSummary = "proposal_summary"
    case blocked
}

struct AgentToolDeclaration: Codable, Equatable, Identifiable {
    let id: AgentToolID
    let lane: AgentProposalLane
    let mode: AgentToolMode
    let requiredInputs: [String]
    let forbiddenFields: [String]
    let outputRedactionClass: AgentToolRedactionClass

    var isAllowed: Bool {
        mode != .blocked
    }
}

struct AgentToolInvocation: Codable, Equatable, Identifiable {
    let id: UUID
    let toolID: AgentToolID
    let classificationID: UUID
    let createdAt: Date

    init(id: UUID = UUID(), toolID: AgentToolID, classificationID: UUID, createdAt: Date = Date()) {
        self.id = id
        self.toolID = toolID
        self.classificationID = classificationID
        self.createdAt = createdAt
    }
}
