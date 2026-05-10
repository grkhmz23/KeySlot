import Foundation

enum AgentMessageRole: String, Codable, Equatable {
    case user
    case assistant
    case system
}

struct AgentChatMessage: Codable, Equatable, Identifiable {
    let id: UUID
    let role: AgentMessageRole
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), role: AgentMessageRole, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = AgentSafetyRedactor.redact(text)
        self.createdAt = createdAt
    }
}

enum AgentIntentType: String, Codable, CaseIterable, Identifiable, Equatable {
    case portfolioSummary
    case riskSummary
    case tokenBuyRequest
    case tokenSwapRequest
    case tokenSendRequest
    case pusdPaymentRequest
    case cloakPrivatePaymentRequest
    case yieldSearch
    case lpPositionReview
    case pnlSummary
    case recentActivitySummary
    case zerionTinySwapRequest
    case unsupported
    case unsafe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portfolioSummary:
            return "Portfolio summary"
        case .riskSummary:
            return "Risk summary"
        case .tokenBuyRequest:
            return "Token buy request"
        case .tokenSwapRequest:
            return "Token swap request"
        case .tokenSendRequest:
            return "Token send request"
        case .pusdPaymentRequest:
            return "PUSD payment request"
        case .cloakPrivatePaymentRequest:
            return "Private payment request"
        case .yieldSearch:
            return "Yield search"
        case .lpPositionReview:
            return "LP review"
        case .pnlSummary:
            return "Performance summary"
        case .recentActivitySummary:
            return "Recent activity"
        case .zerionTinySwapRequest:
            return "Zerion tiny swap"
        case .unsupported:
            return "Unsupported"
        case .unsafe:
            return "Unsafe"
        }
    }

    var isExecutableIntent: Bool {
        switch self {
        case .tokenBuyRequest, .tokenSwapRequest, .tokenSendRequest, .pusdPaymentRequest, .cloakPrivatePaymentRequest, .zerionTinySwapRequest:
            return true
        case .portfolioSummary, .riskSummary, .yieldSearch, .lpPositionReview, .pnlSummary, .recentActivitySummary, .unsupported, .unsafe:
            return false
        }
    }
}

enum AgentRiskFlag: String, Codable, CaseIterable, Identifiable, Equatable {
    case missingAmount
    case missingToken
    case missingRecipient
    case unknownToken
    case highAmount
    case watchOnlyCannotExecute
    case mainWalletApprovalRequired
    case zerionPolicyRequired
    case unsupportedAction
    case unsafeSecretRequest
    case readOnlyOnly
    case dataUnavailable

    var id: String { rawValue }

    var label: String {
        switch self {
        case .missingAmount:
            return "Missing amount"
        case .missingToken:
            return "Missing token"
        case .missingRecipient:
            return "Missing recipient"
        case .unknownToken:
            return "Unknown token"
        case .highAmount:
            return "High amount"
        case .watchOnlyCannotExecute:
            return "Watch-only cannot execute"
        case .mainWalletApprovalRequired:
            return "Wallet approval required"
        case .zerionPolicyRequired:
            return "Zerion policy required"
        case .unsupportedAction:
            return "Unsupported action"
        case .unsafeSecretRequest:
            return "Unsafe secret request"
        case .readOnlyOnly:
            return "Read-only only"
        case .dataUnavailable:
            return "Data unavailable"
        }
    }
}

struct AgentIntentClassification: Codable, Equatable, Identifiable {
    let id: UUID
    let input: String
    let intentType: AgentIntentType
    let amount: Decimal?
    let sourceAsset: String?
    let targetAsset: String?
    let chain: String?
    let recipient: String?
    let confidence: Double
    let missingFields: [String]
    let riskFlags: [AgentRiskFlag]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        input: String,
        intentType: AgentIntentType,
        amount: Decimal? = nil,
        sourceAsset: String? = nil,
        targetAsset: String? = nil,
        chain: String? = nil,
        recipient: String? = nil,
        confidence: Double,
        missingFields: [String] = [],
        riskFlags: [AgentRiskFlag] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.input = AgentSafetyRedactor.redact(input)
        self.intentType = intentType
        self.amount = amount
        self.sourceAsset = sourceAsset.map(AgentSafetyRedactor.redact)
        self.targetAsset = targetAsset.map(AgentSafetyRedactor.redact)
        self.chain = chain.map { $0.lowercased() }
        self.recipient = recipient.map(AgentSafetyRedactor.redact)
        self.confidence = confidence
        self.missingFields = missingFields
        self.riskFlags = riskFlags
        self.createdAt = createdAt
    }

    var summary: String {
        if missingFields.isEmpty {
            return "\(intentType.title) classified with \(Int(confidence * 100))% confidence."
        }
        return "\(intentType.title) needs: \(missingFields.joined(separator: ", "))."
    }
}

struct AgentToolResult: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let status: AgentProposalStatus
    let summary: String
    let bullets: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        status: AgentProposalStatus,
        summary: String,
        bullets: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = AgentSafetyRedactor.redact(title)
        self.status = status
        self.summary = AgentSafetyRedactor.redact(summary)
        self.bullets = bullets.map(AgentSafetyRedactor.redact)
        self.createdAt = createdAt
    }
}

enum AgentSafetyRedactor {
    nonisolated static func redact(_ text: String) -> String {
        let patterns: [(pattern: String, replacement: String)] = [
            (#"(?i)(private\s*key\s*[:=]\s*)[^\s,}"]+"#, "$1[redacted]"),
            (#"(?i)(seed\s*phrase\s*[:=]\s*)[^\n,}"]+"#, "$1[redacted]"),
            (#"(?i)(mnemonic\s*[:=]\s*)[^\n,}"]+"#, "$1[redacted]"),
            (#"(?i)(wallet\s*json\s*[:=]\s*)[^\n,}"]+"#, "$1[redacted]"),
            (#"(?i)(signing\s*seed\s*[:=]\s*)[^\s,}"]+"#, "$1[redacted]"),
            (#"(?i)(agent\s*token\s*[:=]\s*)[^\s,}"]+"#, "$1[redacted]"),
            (#"(?i)(ZERION_API_KEY\s*[:=]\s*)[^\s,}"]+"#, "$1[redacted]"),
            (#"zk_[A-Za-z0-9_\-]{6,}"#, "[redacted]")
        ]
        return patterns.reduce(text) { result, entry in
            result.replacingOccurrences(of: entry.pattern, with: entry.replacement, options: .regularExpression)
        }
    }
}
