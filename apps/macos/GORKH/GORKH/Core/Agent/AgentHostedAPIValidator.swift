import Foundation

enum AgentHostedAPIValidationError: Error, Equatable {
    case forbiddenOutboundField(String)
    case forbiddenInboundField(String)
    case redactedContextTooLarge(Int)
    case disallowedTool(String)
    case encodingFailed
}

enum AgentHostedAPIValidator {
    static func validateOutbound(_ request: AgentHostedChatRequest) throws {
        for tool in request.allowedTools where AgentToolBoundary.enabledLocalTools.contains(tool) == false {
            throw AgentHostedAPIValidationError.disallowedTool(tool.rawValue)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let contextData = try? encoder.encode(request.redactedContext),
              let requestData = try? encoder.encode(request),
              let payload = String(data: requestData, encoding: .utf8) else {
            throw AgentHostedAPIValidationError.encodingFailed
        }

        guard contextData.count <= AgentHostedAPIContract.maxRedactedContextBytes else {
            throw AgentHostedAPIValidationError.redactedContextTooLarge(contextData.count)
        }

        if let forbidden = forbiddenMatch(in: payload) {
            throw AgentHostedAPIValidationError.forbiddenOutboundField(forbidden)
        }
    }

    static func validateInbound(_ response: AgentHostedChatResponse) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(response),
              let payload = String(data: data, encoding: .utf8) else {
            throw AgentHostedAPIValidationError.encodingFailed
        }

        if let forbidden = forbiddenMatch(in: payload) {
            throw AgentHostedAPIValidationError.forbiddenInboundField(forbidden)
        }
    }

    static func forbiddenMatch(in text: String) -> String? {
        if let match = AgentRedactedContextBuilder.firstForbiddenMatch(in: text) {
            return match
        }

        let lowered = text.lowercased()
        let blockedFragments = [
            "deepseek_api_key",
            "keyslot_agent_api_key",
            "gorkh_agent_api_key",
            "api_key",
            "secret_key",
            "agenttoken",
            "raw audit",
            "xcode scheme",
            "file://",
            "/users/",
            "local filesystem path"
        ]
        if let fragment = blockedFragments.first(where: { lowered.contains($0) }) {
            return fragment
        }

        if lowered.range(of: #"zk_[a-z0-9_\-]{8,}"#, options: .regularExpression) != nil {
            return "zk_"
        }
        return nil
    }
}
