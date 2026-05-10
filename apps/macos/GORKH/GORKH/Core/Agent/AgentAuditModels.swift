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
        case zerionProposalBlocked = "zerion_proposal_blocked"
        case zerionProposalApproved = "zerion_proposal_approved"
        case zerionExecutionStarted = "zerion_execution_started"
        case zerionExecutionSucceeded = "zerion_execution_succeeded"
        case zerionExecutionFailed = "zerion_execution_failed"
        case zerionPolicyValidationFailed = "zerion_policy_validation_failed"
        case zerionCommandBlocked = "zerion_command_blocked"
        case zerionCommandFailed = "zerion_command_failed"
        case agentChatMessageReceived = "agent_chat_message_received"
        case agentIntentClassified = "agent_intent_classified"
        case agentProposalCreated = "agent_proposal_created"
        case agentProposalBlocked = "agent_proposal_blocked"
        case agentProposalHandedOff = "agent_proposal_handed_off"
        case agentPolicyDecisionMade = "agent_policy_decision_made"
        case agentReadOnlyAnalysisPerformed = "agent_read_only_analysis_performed"
        case agentUnsupportedRequestBlocked = "agent_unsupported_request_blocked"
        case agentUnsafeRequestBlocked = "agent_unsafe_request_blocked"

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
            case .zerionProposalBlocked:
                return "Zerion proposal blocked"
            case .zerionProposalApproved:
                return "Zerion proposal approved"
            case .zerionExecutionStarted:
                return "Zerion execution started"
            case .zerionExecutionSucceeded:
                return "Zerion execution succeeded"
            case .zerionExecutionFailed:
                return "Zerion execution failed"
            case .zerionPolicyValidationFailed:
                return "Zerion policy validation failed"
            case .zerionCommandBlocked:
                return "Zerion command blocked"
            case .zerionCommandFailed:
                return "Zerion command failed"
            case .agentChatMessageReceived:
                return "Agent chat message received"
            case .agentIntentClassified:
                return "Agent intent classified"
            case .agentProposalCreated:
                return "Agent proposal created"
            case .agentProposalBlocked:
                return "Agent proposal blocked"
            case .agentProposalHandedOff:
                return "Agent proposal handed off"
            case .agentPolicyDecisionMade:
                return "Agent policy decision made"
            case .agentReadOnlyAnalysisPerformed:
                return "Agent read-only analysis performed"
            case .agentUnsupportedRequestBlocked:
                return "Agent unsupported request blocked"
            case .agentUnsafeRequestBlocked:
                return "Agent unsafe request blocked"
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
            message: "Agent foundation loaded with A2 tiny-swap execution gated.",
            details: ["mainWalletAccess": AgentMainWalletAccess.disabled.rawValue]
        )
    ])
}
