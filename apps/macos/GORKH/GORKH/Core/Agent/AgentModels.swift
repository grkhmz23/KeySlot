import Foundation

enum AgentSection: String, CaseIterable, Identifiable, Codable {
    case overview
    case chat
    case proposals
    case audit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .chat:
            return "Chat"
        case .proposals:
            return "Proposals"
        case .audit:
            return "Audit"
        }
    }
}

enum AgentMainWalletAccess: String, Codable, Equatable {
    case disabled

    var label: String {
        switch self {
        case .disabled:
            return "Main-wallet access disabled"
        }
    }
}

enum AgentExecutionStatus: String, Codable, Equatable {
    case observeOnly
    case draftOnly
    case blocked

    var label: String {
        switch self {
        case .observeOnly:
            return "Observe only"
        case .draftOnly:
            return "Draft only"
        case .blocked:
            return "Execution blocked"
        }
    }
}

struct AgentSafetyPolicy: Codable, Equatable {
    let mainWalletAccess: AgentMainWalletAccess
    let executionStatus: AgentExecutionStatus
    let canUseNativeSigner: Bool
    let canRunTradingCommands: Bool
    let safetyBanner: String
    let invariants: [String]

    static let baseline = AgentSafetyPolicy(
        mainWalletAccess: .disabled,
        executionStatus: .draftOnly,
        canUseNativeSigner: false,
        canRunTradingCommands: false,
        safetyBanner: "KeySlot Agent can observe, summarize, draft, and hand off. It cannot directly sign, execute, trade, or use the main wallet without explicit approval.",
        invariants: [
            "Draft proposals cannot execute or sign."
        ]
    )
}

struct AgentOverviewSnapshot: Codable, Equatable {
    let walletContextAvailable: Bool
    let draftProposalCount: Int
    let mainWalletAccess: AgentMainWalletAccess
    let updatedAt: Date
}
