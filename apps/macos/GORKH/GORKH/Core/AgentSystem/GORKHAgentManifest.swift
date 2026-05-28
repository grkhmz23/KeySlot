import Foundation

enum KeySlotAgentID: String, Codable, CaseIterable {
    case global
    case developerWorkstation
}

struct KeySlotAgentManifest: Identifiable, Codable, Equatable {
    let id: KeySlotAgentID
    let title: String
    let shortDescription: String
    let scopeSummary: String
    let allowedDomains: [String]
    let blockedDomains: [String]
    let walletBoundary: String
    let executionBoundary: String
    let routeName: String
}

extension KeySlotAgentManifest {
    static let global = KeySlotAgentManifest(
        id: .global,
        title: "Global Agent",
        shortDescription: "General KeySlot assistant and app orchestrator.",
        scopeSummary: "General KeySlot assistant / app orchestrator",
        allowedDomains: [
            "app help",
            "wallet/portfolio explanation",
            "transaction review",
            "safe proposal drafting",
            "handoff to specialized agents"
        ],
        blockedDomains: [
            "arbitrary shell",
            "raw terminal",
            "private key or seed phrase access",
            "direct unreviewed financial execution",
            "Developer Workstation command execution without workstation gates",
        ],
        walletBoundary: "Uses app-approved proposal/review flows only. It must not reveal or store wallet secrets.",
        executionBoundary: "Execution requires the relevant app policy and approval flow.",
        routeName: "agent"
    )

    static let developerWorkstation = KeySlotAgentManifest(
        id: .developerWorkstation,
        title: "Developer Workstation Agent",
        shortDescription: "Solana developer tools only.",
        scopeSummary: "Solana developer tools only",
        allowedDomains: [
            "Project Brain",
            "IDL",
            "PDA",
            "account decode",
            "transaction debug",
            "localnet/devnet workstation operations through gates",
            "test/build/deploy only through fixed command preview and trust gates"
        ],
        blockedDomains: [
            "main KeySlot wallet",
            "arbitrary shell",
            "raw terminal",
            "mainnet program writes",
            "private key/seed access"
        ],
        walletBoundary: "Uses Developer Workstation dev wallet metadata/approved localnet-devnet flows only. Main KeySlot wallet is not used.",
        executionBoundary: "Write/execute actions require project trust, fixed preview, and explicit approval.",
        routeName: "developerWorkstation"
    )

}
