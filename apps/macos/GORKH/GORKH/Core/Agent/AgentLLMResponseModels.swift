import Foundation

struct AgentHostedPolicyState: Codable, Equatable {
    let mainWalletExecution: String
    let zerionExecution: String
    let cloakExecution: String
    let watchOnlyExecution: String
    let requiredApproval: String
    let safetyMode: String

    static let current = AgentHostedPolicyState(
        mainWalletExecution: "blocked_in_agent_handoff_only",
        zerionExecution: "existing_a2_tiny_swap_review_only",
        cloakExecution: "wallet_private_handoff_only",
        watchOnlyExecution: "analysis_only",
        requiredApproval: "destination_module_policy_and_user_approval",
        safetyMode: "redacted_context_minimized"
    )
}

struct AgentAIProposalDraft: Codable, Equatable {
    let title: String?
    let explanation: String?
    let riskNotes: [String]
    let missingFields: [String]

    init(title: String? = nil, explanation: String? = nil, riskNotes: [String] = [], missingFields: [String] = []) {
        self.title = title.map(AgentSafetyRedactor.redact)
        self.explanation = explanation.map(AgentSafetyRedactor.redact)
        self.riskNotes = riskNotes.map(AgentSafetyRedactor.redact)
        self.missingFields = missingFields.map(AgentSafetyRedactor.redact)
    }
}

struct AgentLLMChatRequest: Codable, Equatable {
    let conversationID: UUID
    let userMessage: String
    let deterministicIntent: AgentIntentClassification
    let redactedContext: AgentRedactedContext
    let enabledLocalTools: [AgentToolSuggestion]
    let policyState: AgentHostedPolicyState
    let safetyMode: String
}

struct AgentLLMChatResponse: Codable, Equatable {
    let assistantMessage: String
    let suggestedIntent: String?
    let proposalDraft: AgentAIProposalDraft?
    let missingFields: [String]
    let toolCallSuggestions: [String]
    let safetyWarnings: [String]
    let modelInfo: AgentHostedModelInfo?
    let requestID: String?

    init(
        assistantMessage: String,
        suggestedIntent: String? = nil,
        proposalDraft: AgentAIProposalDraft? = nil,
        missingFields: [String] = [],
        toolCallSuggestions: [String] = [],
        safetyWarnings: [String] = [],
        modelInfo: AgentHostedModelInfo? = nil,
        requestID: String? = nil
    ) {
        self.assistantMessage = AgentSafetyRedactor.redact(assistantMessage)
        self.suggestedIntent = suggestedIntent.map(AgentSafetyRedactor.redact)
        self.proposalDraft = proposalDraft
        self.missingFields = missingFields.map(AgentSafetyRedactor.redact)
        self.toolCallSuggestions = toolCallSuggestions.map(AgentSafetyRedactor.redact)
        self.safetyWarnings = safetyWarnings.map(AgentSafetyRedactor.redact)
        self.modelInfo = modelInfo
        self.requestID = requestID.map(AgentSafetyRedactor.redact)
    }
}

struct AgentLLMProviderResult: Codable, Equatable {
    let response: AgentLLMChatResponse
    let status: AgentAIStatus
    let toolBoundaryDecision: AgentToolBoundaryDecision
}
