import Foundation

enum AgentHostedBackendErrorCategory: String, Codable, Equatable {
    case missingEndpoint = "missing_endpoint"
    case unauthorized
    case forbidden
    case rateLimited = "rate_limited"
    case serverError = "server_error"
    case timeout
    case malformedResponse = "malformed_response"
    case unsafeResponseBlocked = "unsafe_response_blocked"
    case validation
    case transport
    case unknown

    var safeMessage: String {
        switch self {
        case .missingEndpoint:
            return "Hosted AI endpoint is not configured."
        case .unauthorized:
            return "Hosted AI authentication failed."
        case .forbidden:
            return "Hosted AI access is forbidden."
        case .rateLimited:
            return "Hosted AI is rate limited."
        case .serverError:
            return "Hosted AI server returned an error."
        case .timeout:
            return "Hosted AI request timed out."
        case .malformedResponse:
            return "Hosted AI returned a malformed response."
        case .unsafeResponseBlocked:
            return "Hosted AI returned unsafe advisory content that was blocked."
        case .validation:
            return "Hosted AI request failed local safety validation."
        case .transport:
            return "Hosted AI transport failed."
        case .unknown:
            return "Hosted AI failed."
        }
    }
}

struct AgentHostedNormalizedError: Codable, Equatable {
    let category: AgentHostedBackendErrorCategory
    let message: String

    init(category: AgentHostedBackendErrorCategory, message: String? = nil) {
        self.category = category
        self.message = AgentSafetyRedactor.redact(message ?? category.safeMessage)
    }
}

enum AgentHostedErrorNormalizer {
    static func normalize(_ error: Error) -> AgentHostedNormalizedError {
        if let hostedError = error as? AgentHostedAPIError {
            return normalize(hostedError)
        }

        let description = AgentSafetyRedactor.redact(String(describing: error))
        let lowered = description.lowercased()
        if lowered.contains("timed out") || lowered.contains("timeout") {
            return AgentHostedNormalizedError(category: .timeout)
        }
        return AgentHostedNormalizedError(category: .transport, message: description)
    }

    static func normalize(_ error: AgentHostedAPIError) -> AgentHostedNormalizedError {
        switch error {
        case .missingEndpoint:
            return AgentHostedNormalizedError(category: .missingEndpoint)
        case .invalidResponse:
            return AgentHostedNormalizedError(category: .malformedResponse)
        case .httpStatus(let statusCode, let body):
            return AgentHostedNormalizedError(
                category: category(forHTTPStatus: statusCode),
                message: "\(category(forHTTPStatus: statusCode).safeMessage) \(AgentSafetyRedactor.redact(body))"
            )
        case .transport(let description):
            let lowered = description.lowercased()
            if lowered.contains("timed out") || lowered.contains("timeout") {
                return AgentHostedNormalizedError(category: .timeout)
            }
            if lowered.contains("decode") || lowered.contains("data") {
                return AgentHostedNormalizedError(category: .malformedResponse, message: description)
            }
            return AgentHostedNormalizedError(category: .transport, message: description)
        case .validation(let description):
            let lowered = description.lowercased()
            if lowered.contains("forbiddeninboundfield") || lowered.contains("disallowedtool") {
                return AgentHostedNormalizedError(category: .unsafeResponseBlocked, message: description)
            }
            return AgentHostedNormalizedError(category: .validation, message: description)
        }
    }

    static func category(forHTTPStatus statusCode: Int) -> AgentHostedBackendErrorCategory {
        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 429:
            return .rateLimited
        case 500...599:
            return .serverError
        default:
            return .transport
        }
    }
}
