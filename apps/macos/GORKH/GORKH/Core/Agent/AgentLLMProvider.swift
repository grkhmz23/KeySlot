import Foundation

protocol AgentLLMProvider {
    var currentStatus: AgentAIStatus { get }
    func respond(to request: AgentLLMChatRequest, redactionStatus: AgentRedactionStatus) async -> AgentLLMProviderResult
}

struct LocalDeterministicFallbackProvider: AgentLLMProvider {
    let reason: String

    var currentStatus: AgentAIStatus {
        .localSafeMode(reason: reason)
    }

    func respond(to request: AgentLLMChatRequest, redactionStatus: AgentRedactionStatus) async -> AgentLLMProviderResult {
        let response = AgentLLMChatResponse(
            assistantMessage: "Hosted AI unavailable; using local safe mode. \(request.deterministicIntent.summary)",
            suggestedIntent: request.deterministicIntent.intentType.rawValue,
            missingFields: request.deterministicIntent.missingFields,
            toolCallSuggestions: [],
            safetyWarnings: ["Local deterministic classifier and policy engine are active."]
        )
        return AgentLLMProviderResult(
            response: response,
            status: .localSafeMode(reason: reason),
            toolBoundaryDecision: .init(allowed: [], blocked: [])
        )
    }
}

