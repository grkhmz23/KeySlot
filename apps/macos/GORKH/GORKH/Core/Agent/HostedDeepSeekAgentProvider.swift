import Foundation

struct HostedDeepSeekProvider: AgentLLMProvider {
    let client: AgentHostedAPIClient

    var currentStatus: AgentAIStatus {
        guard let endpointHost = client.configuration.endpointHost else {
            return .localSafeMode(reason: "Hosted AI endpoint is not configured.")
        }
        return .hosted(
            state: .available,
            redactionStatus: .clean,
            endpointHost: endpointHost,
            responseStatus: "ready",
            message: "Hosted AI configured."
        )
    }

    func respond(to request: AgentLLMChatRequest, redactionStatus: AgentRedactionStatus) async -> AgentLLMProviderResult {
        guard let endpointHost = client.configuration.endpointHost else {
            return await LocalDeterministicFallbackProvider(reason: "Hosted AI endpoint is not configured.")
                .respond(to: request, redactionStatus: redactionStatus)
        }

        do {
            let response = try await client.send(request)
            let boundary = AgentToolBoundary.evaluate(response.toolCallSuggestions)
            let state: AgentLLMProviderState = boundary.hasBlockedTools ? .degraded : .available
            return AgentLLMProviderResult(
                response: response,
                status: .hosted(
                    state: state,
                    redactionStatus: redactionStatus,
                    endpointHost: endpointHost,
                    responseStatus: "received",
                    message: boundary.hasBlockedTools ? "Hosted AI response received with blocked tool suggestions." : "Hosted AI response received."
                ),
                toolBoundaryDecision: boundary
            )
        } catch {
            return AgentLLMProviderResult(
                response: AgentLLMChatResponse(
                    assistantMessage: "Hosted AI unavailable; using local safe mode. \(request.deterministicIntent.summary)",
                    suggestedIntent: request.deterministicIntent.intentType.rawValue,
                    missingFields: request.deterministicIntent.missingFields,
                    safetyWarnings: ["Hosted response failed: \(AgentSafetyRedactor.redact(String(describing: error)))"]
                ),
                status: .localSafeMode(reason: "Hosted AI unavailable; using local safe mode."),
                toolBoundaryDecision: .init(allowed: [], blocked: [])
            )
        }
    }
}

