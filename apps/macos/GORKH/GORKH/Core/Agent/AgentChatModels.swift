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
    case walletOverview
    case receiveAddress
    case prepareSend
    case prepareSwap
    case explainSwap
    case securityStatus
    case activitySummary
    case rpcStatus
    case portfolioSummary
    case assetBreakdown
    case walletBreakdown
    case pusdTreasurySummary
    case stakeLstSummary
    case lendingSummary
    case liquiditySummary
    case yieldSummary
    case costBasisHelp
    case portfolioHistorySummary
    case riskSummary
    case tokenBuyRequest
    case tokenSwapRequest
    case tokenSendRequest
    case pusdPaymentRequest
    case yieldSearch
    case lpPositionReview
    case pnlSummary
    case recentActivitySummary
    case help
    case whatCanYouDo
    case missingFields
    case unsupported
    case unsafe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walletOverview:
            return "Wallet overview"
        case .receiveAddress:
            return "Receive address"
        case .prepareSend:
            return "Prepare send"
        case .prepareSwap:
            return "Prepare swap"
        case .explainSwap:
            return "Swap explanation"
        case .securityStatus:
            return "Security status"
        case .activitySummary:
            return "Activity summary"
        case .rpcStatus:
            return "RPC status"
        case .portfolioSummary:
            return "Portfolio summary"
        case .assetBreakdown:
            return "Asset breakdown"
        case .walletBreakdown:
            return "Wallet breakdown"
        case .pusdTreasurySummary:
            return "PUSD Treasury"
        case .stakeLstSummary:
            return "Stake / LST summary"
        case .lendingSummary:
            return "Lending summary"
        case .liquiditySummary:
            return "Liquidity summary"
        case .yieldSummary:
            return "Yield summary"
        case .costBasisHelp:
            return "Cost basis help"
        case .portfolioHistorySummary:
            return "Portfolio history"
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
        case .yieldSearch:
            return "Yield search"
        case .lpPositionReview:
            return "LP review"
        case .pnlSummary:
            return "Performance summary"
        case .recentActivitySummary:
            return "Recent activity"
        case .help:
            return "Help"
        case .whatCanYouDo:
            return "What Agent can do"
        case .missingFields:
            return "Missing fields"
        case .unsupported:
            return "Unsupported"
        case .unsafe:
            return "Unsafe"
        }
    }

    var isExecutableIntent: Bool {
        switch self {
        case .prepareSend,
             .prepareSwap,
             .tokenBuyRequest,
             .tokenSwapRequest,
             .tokenSendRequest,
             .pusdPaymentRequest,
            return true
        case .walletOverview,
             .receiveAddress,
             .explainSwap,
             .securityStatus,
             .activitySummary,
             .rpcStatus,
             .portfolioSummary,
             .assetBreakdown,
             .walletBreakdown,
             .pusdTreasurySummary,
             .stakeLstSummary,
             .lendingSummary,
             .liquiditySummary,
             .yieldSummary,
             .costBasisHelp,
             .portfolioHistorySummary,
             .riskSummary,
             .yieldSearch,
             .lpPositionReview,
             .pnlSummary,
             .recentActivitySummary,
             .help,
             .whatCanYouDo,
             .missingFields,
             .unsupported,
             .unsafe:
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
            (#"(?i)(Authorization\s*:\s*Bearer\s+)[A-Za-z0-9._~+/\-=]+"#, "$1[redacted]"),
            (#"(?i)(private\s*key\s*[:=]\s*)[^\s,}"]+"#, "$1[redacted]"),
            (#"(?i)(seed\s*phrase\s*[:=]\s*)[^\n,}"]+"#, "$1[redacted]"),
            (#"(?i)(mnemonic\s*[:=]\s*)[^\n,}"]+"#, "$1[redacted]"),
            (#"(?i)(wallet\s*json\s*[:=]\s*)[^\n,}"]+"#, "$1[redacted]"),
            (#"(?i)(signing\s*seed\s*[:=]\s*)[^\s,}"]+"#, "$1[redacted]"),
            (#"(?i)(agent\s*token\s*[:=]\s*)[^\s,}"]+"#, "$1[redacted]"),
            (#"(?i)(vault\s*export\s*code\s*[:=]\s*)[^\s,}"]+"#, "$1[redacted]"),
            (#"(?i)(export\s*code\s*[:=]\s*)[^\s,}"]+"#, "$1[redacted]"),
            (#"(?i)\b((?:password|passwd|secret|token|api[_-]?key|apikey|private[_-]?key|access[_-]?key|refresh[_-]?token)\s*[:=]\s*)["']?[^"'\s,}]+"#, "$1[redacted]"),
            (#"(?i)([?&](?:token|api_key|apikey|key|access_key|rpc_key)=)[^&\s]+"#, "$1[redacted]"),
            (#"\b[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\b"#, "[redacted]"),
            (#"(?i)\b(?:sk|pk|rk|gsk|zk)_[A-Za-z0-9_\-]{12,}\b"#, "[redacted]"),
            (#"(/Users/)[^/\s]+(/[^\s,)"']*)"#, "$1[redacted]$2"),
            (#"zk_[A-Za-z0-9_\-]{6,}"#, "[redacted]"),
            // Vault Export Code format: XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX
            (#"\b[a-f0-9]{4}(?:-[a-f0-9]{4}){7}\b"#, "[redacted-export-code]"),
            // Base58 Solana key-like strings (64+ chars typical for keypair)
            (#"\b[1-9A-HJ-NP-Za-km-z]{64,}\b"#, "[redacted-base58-key]")
        ]
        let redacted = patterns.reduce(text) { result, entry in
            result.replacingOccurrences(of: entry.pattern, with: entry.replacement, options: .regularExpression)
        }
        return redactSolanaKeypairArrays(redacted)
    }

    nonisolated private static func redactSolanaKeypairArrays(_ text: String) -> String {
        let pattern = #"\[(?:\s*\d{1,3}\s*,){50,}\s*\d{1,3}\s*\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        var redacted = text
        let matches = regex.matches(in: redacted, range: NSRange(redacted.startIndex..., in: redacted))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: redacted) else { continue }
            let candidate = String(redacted[range])
            let values = candidate
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .compactMap(Int.init)
            guard values.count >= 64, values.allSatisfy({ (0...255).contains($0) }) else {
                continue
            }
            redacted.replaceSubrange(range, with: "[redacted-solana-keypair-array]")
        }
        return redacted
    }
}
