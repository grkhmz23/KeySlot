import Foundation

enum AgentLLMProviderState: String, Codable, Equatable, CaseIterable, Identifiable {
    case available
    case unavailable
    case degraded
    case disabled
    case error

    var id: String { rawValue }

    var title: String {
        switch self {
        case .available:
            return "Available"
        case .unavailable:
            return "Unavailable"
        case .degraded:
            return "Degraded"
        case .disabled:
            return "Disabled"
        case .error:
            return "Error"
        }
    }
}

enum AgentAIMode: String, Codable, Equatable {
    case hostedDeepSeek = "hosted_deepseek"
    case localSafeMode = "local_safe_mode"

    var title: String {
        switch self {
        case .hostedDeepSeek:
            return "Hosted DeepSeek"
        case .localSafeMode:
            return "Local Safe Mode"
        }
    }
}

enum AgentRedactionStatus: String, Codable, Equatable {
    case clean
    case redacted
    case blocked

    var title: String {
        switch self {
        case .clean:
            return "Clean"
        case .redacted:
            return "Redacted"
        case .blocked:
            return "Blocked"
        }
    }
}

enum AgentHostedAPIKeyStatus: String, Codable, Equatable {
    case presentRedacted = "present_redacted"
    case missing

    var title: String {
        switch self {
        case .presentRedacted:
            return "Present"
        case .missing:
            return "Missing"
        }
    }
}

struct AgentAIStatus: Codable, Equatable {
    let mode: AgentAIMode
    let providerState: AgentLLMProviderState
    let redactionStatus: AgentRedactionStatus
    let lastResponseStatus: String
    let endpointHost: String?
    let noSecretsSent: Bool
    let updatedAt: Date
    let message: String

    static func localSafeMode(reason: String, updatedAt: Date = Date()) -> AgentAIStatus {
        AgentAIStatus(
            mode: .localSafeMode,
            providerState: .unavailable,
            redactionStatus: .clean,
            lastResponseStatus: "fallback",
            endpointHost: nil,
            noSecretsSent: true,
            updatedAt: updatedAt,
            message: AgentSafetyRedactor.redact(reason)
        )
    }

    static func hosted(
        state: AgentLLMProviderState,
        redactionStatus: AgentRedactionStatus,
        endpointHost: String?,
        responseStatus: String,
        message: String,
        updatedAt: Date = Date()
    ) -> AgentAIStatus {
        AgentAIStatus(
            mode: .hostedDeepSeek,
            providerState: state,
            redactionStatus: redactionStatus,
            lastResponseStatus: responseStatus,
            endpointHost: endpointHost,
            noSecretsSent: redactionStatus != .blocked,
            updatedAt: updatedAt,
            message: AgentSafetyRedactor.redact(message)
        )
    }
}

