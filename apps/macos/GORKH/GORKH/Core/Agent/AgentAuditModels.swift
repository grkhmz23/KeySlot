import Foundation

struct AgentAuditEvent: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        case agentSectionViewed = "agent_section_viewed"
        case zerionCLIStatusChecked = "zerion_cli_status_checked"
        case zerionAPIKeyStatusChecked = "zerion_api_key_status_checked"
        case zerionWalletListChecked = "zerion_wallet_list_checked"
        case zerionPoliciesChecked = "zerion_policies_checked"
        case zerionTokensChecked = "zerion_tokens_checked"
        case zerionProposalDrafted = "zerion_proposal_drafted"
        case zerionCommandBlocked = "zerion_command_blocked"
        case zerionCommandFailed = "zerion_command_failed"

        var label: String {
            switch self {
            case .agentSectionViewed:
                return "Agent section viewed"
            case .zerionCLIStatusChecked:
                return "Zerion CLI status checked"
            case .zerionAPIKeyStatusChecked:
                return "Zerion API key status checked"
            case .zerionWalletListChecked:
                return "Zerion wallet list checked"
            case .zerionPoliciesChecked:
                return "Zerion policies checked"
            case .zerionTokensChecked:
                return "Zerion tokens checked"
            case .zerionProposalDrafted:
                return "Zerion proposal drafted"
            case .zerionCommandBlocked:
                return "Zerion command blocked"
            case .zerionCommandFailed:
                return "Zerion command failed"
            }
        }
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    let message: String
    let details: [String: String]

    init(
        id: UUID = UUID(),
        kind: Kind,
        createdAt: Date = Date(),
        message: String,
        details: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.message = ZerionRedaction.redact(message)
        self.details = ZerionRedaction.safeDetails(details)
    }
}

struct AgentAuditTimeline: Codable, Equatable {
    let events: [AgentAuditEvent]

    static let initial = AgentAuditTimeline(events: [
        AgentAuditEvent(
            kind: .agentSectionViewed,
            message: "Agent foundation loaded in no-execution A1 mode.",
            details: ["mainWalletAccess": AgentMainWalletAccess.disabled.rawValue]
        )
    ])
}
