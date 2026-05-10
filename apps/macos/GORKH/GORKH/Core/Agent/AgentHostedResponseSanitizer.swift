import Foundation

struct AgentHostedValidatedResponse: Codable, Equatable {
    let response: AgentLLMChatResponse
    let toolBoundaryDecision: AgentToolBoundaryDecision
    let ignoredProposalSuggestion: Bool
}

enum AgentHostedResponseSanitizer {
    static func sanitize(_ hostedResponse: AgentHostedChatResponse) throws -> AgentHostedValidatedResponse {
        try AgentHostedAPIValidator.validateInbound(hostedResponse)

        let toolNames = hostedResponse.toolSuggestions.map(\.name)
        let boundary = AgentToolBoundary.evaluate(toolNames)
        let ignoredProposal = hostedResponse.proposalSuggestion?.claimsExecutionAuthority == true

        var warnings = hostedResponse.safetyWarnings.map(\.message)
        if boundary.hasBlockedTools {
            warnings.append("Unsafe backend tool suggestions were blocked locally.")
        }
        if ignoredProposal {
            warnings.append("Backend execution approval was ignored; proposals require local policy review.")
        }

        let response = AgentLLMChatResponse(
            assistantMessage: hostedResponse.assistantMessage,
            suggestedIntent: hostedResponse.suggestedIntent,
            proposalDraft: ignoredProposal ? nil : hostedResponse.proposalSuggestion?.advisoryDraft,
            missingFields: hostedResponse.missingFields,
            toolCallSuggestions: boundary.allowed,
            safetyWarnings: warnings,
            modelInfo: hostedResponse.modelInfo,
            requestID: hostedResponse.requestID
        )

        return AgentHostedValidatedResponse(
            response: response,
            toolBoundaryDecision: boundary,
            ignoredProposalSuggestion: ignoredProposal
        )
    }
}
