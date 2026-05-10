import Foundation

enum AgentHostedAPIContract {
    static let version = "2026-05-10.a5"
    static let chatPath = "/v1/agent/chat"
    static let maxRedactedContextBytes = 32 * 1024
}

struct AgentHostedChatRequest: Codable, Equatable {
    let conversationID: UUID
    let messageID: UUID
    let userMessage: String
    let redactedContext: AgentRedactedContext
    let deterministicIntent: AgentIntentClassification
    let policyState: AgentHostedPolicyState
    let allowedTools: [AgentToolSuggestion]
    let safetyMode: String
    let clientVersion: String

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversationId"
        case messageID = "messageId"
        case userMessage
        case redactedContext
        case deterministicIntent
        case policyState
        case allowedTools
        case safetyMode
        case clientVersion
    }

    init(
        conversationID: UUID,
        messageID: UUID = UUID(),
        userMessage: String,
        redactedContext: AgentRedactedContext,
        deterministicIntent: AgentIntentClassification,
        policyState: AgentHostedPolicyState,
        allowedTools: [AgentToolSuggestion],
        safetyMode: String,
        clientVersion: String = AgentHostedAPIContract.version
    ) {
        self.conversationID = conversationID
        self.messageID = messageID
        self.userMessage = AgentSafetyRedactor.redact(userMessage)
        self.redactedContext = redactedContext
        self.deterministicIntent = deterministicIntent
        self.policyState = policyState
        self.allowedTools = allowedTools
        self.safetyMode = AgentSafetyRedactor.redact(safetyMode)
        self.clientVersion = AgentSafetyRedactor.redact(clientVersion)
    }

    init(llmRequest: AgentLLMChatRequest, messageID: UUID = UUID(), clientVersion: String = AgentHostedAPIContract.version) {
        self.init(
            conversationID: llmRequest.conversationID,
            messageID: messageID,
            userMessage: llmRequest.userMessage,
            redactedContext: llmRequest.redactedContext,
            deterministicIntent: llmRequest.deterministicIntent,
            policyState: llmRequest.policyState,
            allowedTools: llmRequest.enabledLocalTools,
            safetyMode: llmRequest.safetyMode,
            clientVersion: clientVersion
        )
    }
}

struct AgentHostedChatResponse: Codable, Equatable {
    let assistantMessage: String
    let suggestedIntent: String?
    let missingFields: [String]
    let proposalSuggestion: AgentHostedProposalSuggestion?
    let toolSuggestions: [AgentHostedToolSuggestion]
    let safetyWarnings: [AgentHostedSafetyWarning]
    let modelInfo: AgentHostedModelInfo?
    let requestID: String?

    enum CodingKeys: String, CodingKey {
        case assistantMessage
        case suggestedIntent
        case missingFields
        case proposalSuggestion
        case toolSuggestions
        case safetyWarnings
        case modelInfo
        case requestID = "requestId"
    }

    init(
        assistantMessage: String,
        suggestedIntent: String? = nil,
        missingFields: [String] = [],
        proposalSuggestion: AgentHostedProposalSuggestion? = nil,
        toolSuggestions: [AgentHostedToolSuggestion] = [],
        safetyWarnings: [AgentHostedSafetyWarning] = [],
        modelInfo: AgentHostedModelInfo? = nil,
        requestID: String? = nil
    ) {
        self.assistantMessage = AgentSafetyRedactor.redact(assistantMessage)
        self.suggestedIntent = suggestedIntent.map(AgentSafetyRedactor.redact)
        self.missingFields = missingFields.map(AgentSafetyRedactor.redact)
        self.proposalSuggestion = proposalSuggestion
        self.toolSuggestions = toolSuggestions
        self.safetyWarnings = safetyWarnings
        self.modelInfo = modelInfo
        self.requestID = requestID.map(AgentSafetyRedactor.redact)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            assistantMessage: try container.decode(String.self, forKey: .assistantMessage),
            suggestedIntent: try container.decodeIfPresent(String.self, forKey: .suggestedIntent),
            missingFields: try container.decodeIfPresent([String].self, forKey: .missingFields) ?? [],
            proposalSuggestion: try container.decodeIfPresent(AgentHostedProposalSuggestion.self, forKey: .proposalSuggestion),
            toolSuggestions: try container.decodeIfPresent([AgentHostedToolSuggestion].self, forKey: .toolSuggestions) ?? [],
            safetyWarnings: try container.decodeIfPresent([AgentHostedSafetyWarning].self, forKey: .safetyWarnings) ?? [],
            modelInfo: try container.decodeIfPresent(AgentHostedModelInfo.self, forKey: .modelInfo),
            requestID: try container.decodeIfPresent(String.self, forKey: .requestID)
        )
    }
}

struct AgentHostedProposalSuggestion: Codable, Equatable {
    let actionType: String?
    let title: String?
    let explanation: String?
    let riskNotes: [String]
    let missingFields: [String]
    let status: String?
    let approvalState: String?
    let executionApproved: Bool?

    init(
        actionType: String? = nil,
        title: String? = nil,
        explanation: String? = nil,
        riskNotes: [String] = [],
        missingFields: [String] = [],
        status: String? = nil,
        approvalState: String? = nil,
        executionApproved: Bool? = nil
    ) {
        self.actionType = actionType.map(AgentSafetyRedactor.redact)
        self.title = title.map(AgentSafetyRedactor.redact)
        self.explanation = explanation.map(AgentSafetyRedactor.redact)
        self.riskNotes = riskNotes.map(AgentSafetyRedactor.redact)
        self.missingFields = missingFields.map(AgentSafetyRedactor.redact)
        self.status = status.map(AgentSafetyRedactor.redact)
        self.approvalState = approvalState.map(AgentSafetyRedactor.redact)
        self.executionApproved = executionApproved
    }

    var claimsExecutionAuthority: Bool {
        executionApproved == true ||
            status?.lowercased().contains("approved") == true ||
            status?.lowercased().contains("executed") == true ||
            approvalState?.lowercased().contains("approved") == true ||
            approvalState?.lowercased().contains("executed") == true
    }

    var advisoryDraft: AgentAIProposalDraft {
        AgentAIProposalDraft(
            title: title,
            explanation: explanation,
            riskNotes: riskNotes,
            missingFields: missingFields
        )
    }
}

struct AgentHostedToolSuggestion: Codable, Equatable {
    let name: String
    let reason: String?
    let confidence: Double?

    init(name: String, reason: String? = nil, confidence: Double? = nil) {
        self.name = AgentSafetyRedactor.redact(name)
        self.reason = reason.map(AgentSafetyRedactor.redact)
        self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let name = try? single.decode(String.self) {
            self.init(name: name)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            reason: try container.decodeIfPresent(String.self, forKey: .reason),
            confidence: try container.decodeIfPresent(Double.self, forKey: .confidence)
        )
    }
}

struct AgentHostedSafetyWarning: Codable, Equatable {
    let message: String
    let severity: String?

    init(message: String, severity: String? = nil) {
        self.message = AgentSafetyRedactor.redact(message)
        self.severity = severity.map(AgentSafetyRedactor.redact)
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let message = try? single.decode(String.self) {
            self.init(message: message)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            message: try container.decode(String.self, forKey: .message),
            severity: try container.decodeIfPresent(String.self, forKey: .severity)
        )
    }
}

struct AgentHostedModelInfo: Codable, Equatable {
    let provider: String?
    let model: String?
    let contractVersion: String?

    init(provider: String? = nil, model: String? = nil, contractVersion: String? = nil) {
        self.provider = provider.map(AgentSafetyRedactor.redact)
        self.model = model.map(AgentSafetyRedactor.redact)
        self.contractVersion = contractVersion.map(AgentSafetyRedactor.redact)
    }
}

struct AgentHostedError: Codable, Equatable {
    let code: String
    let message: String
    let requestID: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case requestID = "requestId"
    }
}
