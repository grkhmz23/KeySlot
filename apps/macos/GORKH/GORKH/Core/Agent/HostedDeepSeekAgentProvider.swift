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
                    authStatus: client.configuration.apiKeyStatus,
                    responseStatus: "ready",
                    message: "Hosted AI configured.",
                    backendContractVersion: AgentHostedAPIContract.version
            )
    }

    func respond(to request: AgentLLMChatRequest, redactionStatus: AgentRedactionStatus) async -> AgentLLMProviderResult {
        guard let endpointHost = client.configuration.endpointHost else {
            return await LocalDeterministicFallbackProvider(reason: "Hosted AI endpoint is not configured.")
                .respond(to: request, redactionStatus: redactionStatus)
        }

        do {
            let validated = try await client.sendValidated(request)
            let response = validated.response
            let boundary = validated.toolBoundaryDecision
            let state: AgentLLMProviderState = boundary.hasBlockedTools || validated.ignoredProposalSuggestion ? .degraded : .available
            return AgentLLMProviderResult(
                response: response,
                status: .hosted(
                    state: state,
                    redactionStatus: redactionStatus,
                    endpointHost: endpointHost,
                    authStatus: client.configuration.apiKeyStatus,
                    responseStatus: "received",
                    message: boundary.hasBlockedTools || validated.ignoredProposalSuggestion ? "Hosted AI response received with blocked advisory content." : "Hosted AI response received.",
                    backendContractVersion: response.modelInfo?.contractVersion ?? AgentHostedAPIContract.version,
                    backendModelLabel: modelLabel(response.modelInfo),
                    lastRequestID: response.requestID
                ),
                toolBoundaryDecision: boundary
            )
        } catch {
            let normalized = AgentHostedErrorNormalizer.normalize(error)
            return AgentLLMProviderResult(
                response: AgentLLMChatResponse(
                    assistantMessage: "Hosted AI unavailable; using local safe mode. \(request.deterministicIntent.summary)",
                    suggestedIntent: request.deterministicIntent.intentType.rawValue,
                    missingFields: request.deterministicIntent.missingFields,
                    safetyWarnings: ["Hosted response failed: \(normalized.message)"]
                ),
                status: .localSafeMode(
                    reason: "Hosted AI unavailable; using local safe mode. \(normalized.category.safeMessage)",
                    endpointConfigured: client.configuration.endpointHost != nil,
                    authStatus: client.configuration.apiKeyStatus
                ),
                toolBoundaryDecision: .init(allowed: [], blocked: [])
            )
        }
    }

    private func modelLabel(_ modelInfo: AgentHostedModelInfo?) -> String? {
        guard let modelInfo else {
            return nil
        }
        return [modelInfo.provider, modelInfo.model]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " / ")
    }
}
