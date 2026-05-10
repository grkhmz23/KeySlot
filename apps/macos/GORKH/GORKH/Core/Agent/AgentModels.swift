import Foundation

enum AgentSection: String, CaseIterable, Identifiable, Codable {
    case overview
    case zerionExecutor
    case policyCenter
    case proposals
    case audit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .zerionExecutor:
            return "Zerion Executor"
        case .policyCenter:
            return "Policy Center"
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
    let canReadCloakVault: Bool
    let canRunTradingCommands: Bool
    let safetyBanner: String
    let invariants: [String]

    static let zerionA1 = AgentSafetyPolicy(
        mainWalletAccess: .disabled,
        executionStatus: .draftOnly,
        canUseNativeSigner: false,
        canReadCloakVault: false,
        canRunTradingCommands: false,
        safetyBanner: "GORKH Agent can observe, summarize, draft, and hand off. It cannot directly sign, execute, trade, or use the main wallet without explicit approval.",
        invariants: [
            "Zerion wallet is separate from the GORKH wallet.",
            "No GORKH Keychain signer, recovery phrase, private key, or Cloak private state is exposed.",
            "A1 allows read/status Zerion CLI commands only.",
            "Draft proposals cannot execute or sign."
        ]
    )
}

struct AgentOverviewSnapshot: Codable, Equatable {
    let walletContextAvailable: Bool
    let zerionStatus: ZerionCLIInstallStatus
    let apiKeyStatus: ZerionSecretStatus
    let policyStatus: ZerionPolicyReadStatus
    let draftProposalCount: Int
    let mainWalletAccess: AgentMainWalletAccess
    let updatedAt: Date

    static func from(status: ZerionStatusSnapshot, draftProposalCount: Int) -> AgentOverviewSnapshot {
        AgentOverviewSnapshot(
            walletContextAvailable: true,
            zerionStatus: status.cliStatus,
            apiKeyStatus: status.apiKeyStatus,
            policyStatus: status.policyStatus,
            draftProposalCount: draftProposalCount,
            mainWalletAccess: .disabled,
            updatedAt: status.checkedAt
        )
    }
}
