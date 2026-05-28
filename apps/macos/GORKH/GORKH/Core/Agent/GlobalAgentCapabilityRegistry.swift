import Foundation

enum GlobalAgentCapabilityID: String, Codable, CaseIterable {
    case appHelp
    case portfolioExplain
    case walletExplain
    case transactionReview
    case draftSendPayment
    case draftReceiveRequest
    case draftDeposit
    case draftSwap
    case handoffDeveloperWorkstation
    case developerExplainOnly
    case securityExplain
}

enum GlobalAgentCapabilityStatus: String, Codable {
    case available
    case proposalOnly
    case approvalRequired
    case handoffOnly
    case blocked
    case unavailable
}

struct GlobalAgentCapability: Identifiable, Codable, Equatable {
    let id: GlobalAgentCapabilityID
    let title: String
    let summary: String
    let status: GlobalAgentCapabilityStatus
    let allowedOutputs: [String]
    let blockedActions: [String]
    let requiredApproval: String?
    let handoffTarget: KeySlotAgentID?
}

enum GlobalAgentCapabilityRegistry {
    static let allCapabilities: [GlobalAgentCapability] = [
        GlobalAgentCapability(
            id: .appHelp,
            title: "App Help",
            summary: "Explain KeySlot features, navigation, and settings.",
            status: .available,
            allowedOutputs: ["explanation", "navigation hint"],
            blockedActions: [],
            requiredApproval: nil,
            handoffTarget: nil
        ),
        GlobalAgentCapability(
            id: .portfolioExplain,
            title: "Portfolio Explanation",
            summary: "Summarize assets, positions, PnL, and yield.",
            status: .available,
            allowedOutputs: ["summary", "read-only report"],
            blockedActions: ["trade execution", "position mutation"],
            requiredApproval: nil,
            handoffTarget: nil
        ),
        GlobalAgentCapability(
            id: .walletExplain,
            title: "Wallet Explanation",
            summary: "Describe wallet status, balances, and security.",
            status: .available,
            allowedOutputs: ["status summary", "balance overview"],
            blockedActions: ["signing", "transaction broadcast"],
            requiredApproval: nil,
            handoffTarget: nil
        ),
        GlobalAgentCapability(
            id: .transactionReview,
            title: "Transaction Review",
            summary: "Explain transaction details, risks, and flags.",
            status: .available,
            allowedOutputs: ["review summary", "risk flags"],
            blockedActions: ["signing", "broadcasting"],
            requiredApproval: nil,
            handoffTarget: nil
        ),
        GlobalAgentCapability(
            id: .securityExplain,
            title: "Security Explanation",
            summary: "Describe security posture, RPC status, and vault state.",
            status: .available,
            allowedOutputs: ["security summary", "recommendation"],
            blockedActions: ["key access", "vault mutation"],
            requiredApproval: nil,
            handoffTarget: nil
        ),
        GlobalAgentCapability(
            id: .draftSendPayment,
            title: "Draft Send Payment",
            summary: "Create a send-payment proposal for Wallet review.",
            status: .proposalOnly,
            allowedOutputs: ["payment draft", "recipient summary"],
            blockedActions: ["direct send", "transaction broadcast"],
            requiredApproval: "Wallet approval flow",
            handoffTarget: nil
        ),
        GlobalAgentCapability(
            id: .draftReceiveRequest,
            title: "Draft Receive Request",
            summary: "Create a receive-request proposal.",
            status: .proposalOnly,
            allowedOutputs: ["receive draft", "address summary"],
            blockedActions: ["direct execution"],
            requiredApproval: "Wallet approval flow",
            handoffTarget: nil
        ),
        GlobalAgentCapability(
            id: .draftDeposit,
            title: "Draft Deposit",
            summary: "Create a deposit proposal for Wallet review.",
            status: .proposalOnly,
            allowedOutputs: ["deposit draft"],
            blockedActions: ["direct deposit execution"],
            requiredApproval: "Wallet approval flow",
            handoffTarget: nil
        ),
        GlobalAgentCapability(
            id: .draftSwap,
            title: "Draft Swap",
            summary: "Create a swap proposal for Wallet review.",
            status: .proposalOnly,
            allowedOutputs: ["swap draft", "quote summary"],
            blockedActions: ["direct swap execution"],
            requiredApproval: "Wallet approval flow",
            handoffTarget: nil
        ),
        GlobalAgentCapability(
            id: .handoffDeveloperWorkstation,
            title: "Developer Workstation Handoff",
            summary: "Route Solana developer requests to Developer Workstation.",
            status: .handoffOnly,
            allowedOutputs: ["handoff message"],
            blockedActions: ["direct command execution", "mainnet deploy"],
            requiredApproval: nil,
            handoffTarget: .developerWorkstation
        ),
        GlobalAgentCapability(
            id: .developerExplainOnly,
            title: "Developer Explanation",
            summary: "Explain Solana concepts at a high level without tool execution.",
            status: .available,
            allowedOutputs: ["concept explanation"],
            blockedActions: ["command execution", "program deploy"],
            requiredApproval: nil,
            handoffTarget: nil
        )
    ]

    static let blockedCapabilities: [GlobalAgentCapability] = [
        GlobalAgentCapability(
            id: .appHelp,
            title: "Arbitrary Shell",
            summary: "Running arbitrary shell commands is never allowed.",
            status: .blocked,
            allowedOutputs: [],
            blockedActions: ["shell execution", "process spawning"],
            requiredApproval: nil,
            handoffTarget: nil
        ),
        GlobalAgentCapability(
            id: .appHelp,
            title: "Raw Terminal",
            summary: "Raw terminal access is never allowed.",
            status: .blocked,
            allowedOutputs: [],
            blockedActions: ["terminal execution", "interactive shell"],
            requiredApproval: nil,
            handoffTarget: nil
        ),
        GlobalAgentCapability(
            id: .appHelp,
            title: "Reveal Private Key",
            summary: "Private key access is never allowed.",
            status: .blocked,
            allowedOutputs: [],
            blockedActions: ["private key reveal", "key export"],
            requiredApproval: nil,
            handoffTarget: nil
        ),
        GlobalAgentCapability(
            id: .appHelp,
            title: "Reveal Seed Phrase",
            summary: "Seed phrase access is never allowed.",
            status: .blocked,
            allowedOutputs: [],
            blockedActions: ["seed phrase reveal", "mnemonic export"],
            requiredApproval: nil,
            handoffTarget: nil
        ),
        GlobalAgentCapability(
            id: .appHelp,
            title: "Generic sendTransaction",
            summary: "Generic transaction sending outside approved flows is blocked.",
            status: .blocked,
            allowedOutputs: [],
            blockedActions: ["generic sendTransaction", "unreviewed broadcast"],
            requiredApproval: nil,
            handoffTarget: nil
        )
    ]

    static func capability(for id: GlobalAgentCapabilityID) -> GlobalAgentCapability? {
        allCapabilities.first { $0.id == id }
    }

    static func capabilities(withStatus status: GlobalAgentCapabilityStatus) -> [GlobalAgentCapability] {
        allCapabilities.filter { $0.status == status }
    }

    static func isBlocked(_ action: String) -> Bool {
        let blockedKeywords = blockedCapabilities.flatMap(\.blockedActions)
            + allCapabilities.filter { $0.status == .blocked }.flatMap(\.blockedActions)
        let lowercased = action.lowercased()
        return blockedKeywords.contains { keyword in
            lowercased.contains(keyword.lowercased()) || keyword.lowercased().contains(lowercased)
        }
    }
}
