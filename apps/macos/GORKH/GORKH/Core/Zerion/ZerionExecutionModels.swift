import Foundation

enum ZerionExecutionChain: String, Codable, CaseIterable, Identifiable {
    case solana
    case base

    var id: String { rawValue }

    var label: String {
        switch self {
        case .solana:
            return "Solana"
        case .base:
            return "Base"
        }
    }
}
enum ZerionExecutionStatus: String, Codable, Equatable {
    case draft
    case blocked
    case readyForReview = "ready_for_review"
    case approved
    case executing
    case executed
    case failed

    var label: String {
        switch self {
        case .draft:
            return "Draft"
        case .blocked:
            return "Blocked"
        case .readyForReview:
            return "Ready for review"
        case .approved:
            return "Approved"
        case .executing:
            return "Executing"
        case .executed:
            return "Executed"
        case .failed:
            return "Failed"
        }
    }
}

struct ZerionTinySwapProposal: Codable, Equatable, Identifiable {
    static let requiredConfirmationPhrase = "I understand this uses a separate Zerion wallet and executes a real onchain transaction."

    let id: UUID
    let zerionWalletName: String
    let chain: ZerionExecutionChain
    let fromToken: String
    let toToken: String
    let amount: Decimal
    let estimatedNotionalUSD: Decimal?
    let policyID: String
    let policyName: String?
    let expiresAt: Date?
    let status: ZerionExecutionStatus
    let riskNotes: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        zerionWalletName: String,
        chain: ZerionExecutionChain,
        fromToken: String,
        toToken: String,
        amount: Decimal,
        estimatedNotionalUSD: Decimal?,
        policyID: String,
        policyName: String?,
        expiresAt: Date?,
        status: ZerionExecutionStatus = .draft,
        riskNotes: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.zerionWalletName = ZerionRedaction.redact(zerionWalletName)
        self.chain = chain
        self.fromToken = fromToken.uppercased()
        self.toToken = toToken.uppercased()
        self.amount = amount
        self.estimatedNotionalUSD = estimatedNotionalUSD
        self.policyID = ZerionRedaction.redact(policyID)
        self.policyName = policyName.map(ZerionRedaction.redact)
        self.expiresAt = expiresAt
        self.status = status
        self.riskNotes = riskNotes.map(ZerionRedaction.redact)
        self.createdAt = createdAt
    }

    var fingerprint: String {
        [
            zerionWalletName,
            chain.rawValue,
            fromToken,
            toToken,
            NSDecimalNumber(decimal: amount).stringValue,
            policyID,
            "\(Int(createdAt.timeIntervalSince1970))"
        ].joined(separator: "|")
    }

    static let sampleSolanaTinySwap = ZerionTinySwapProposal(
        zerionWalletName: "manual-zerion-wallet",
        chain: .solana,
        fromToken: "SOL",
        toToken: "USDC",
        amount: Decimal(string: "0.001") ?? 0,
        estimatedNotionalUSD: nil,
        policyID: "manual-policy",
        policyName: "manual-policy",
        expiresAt: nil,
        riskNotes: [
            "Separate Zerion wallet required.",
            "Execution stays blocked until CLI swap help, API key, agent token, and policy are validated."
        ]
    )

    static let sampleBaseTinySwap = ZerionTinySwapProposal(
        zerionWalletName: "manual-zerion-wallet",
        chain: .base,
        fromToken: "USDC",
        toToken: "ETH",
        amount: Decimal(string: "1") ?? 0,
        estimatedNotionalUSD: Decimal(string: "1"),
        policyID: "manual-policy",
        policyName: "manual-policy",
        expiresAt: nil,
        riskNotes: [
            "Separate Zerion wallet required.",
            "Execution stays blocked until policy and agent token status are loaded."
        ]
    )
}

struct ZerionExecutionApproval: Codable, Equatable {
    let proposalID: UUID
    let proposalFingerprint: String
    let confirmationPhrase: String
    let unknownValueAcknowledged: Bool
    let approvedAt: Date

    var hasExactConfirmation: Bool {
        confirmationPhrase == ZerionTinySwapProposal.requiredConfirmationPhrase
    }
}

struct ZerionSwapCommandPlan: Codable, Equatable {
    let commandName: String
    let arguments: [String]
    let redactedPreview: String
    let shape: ZerionSwapCommandShape
    let requiresAPIKey: Bool

    static func unavailable(reason: String) -> ZerionSwapCommandPlan {
        ZerionSwapCommandPlan(
            commandName: "zerion_tiny_swap",
            arguments: [],
            redactedPreview: ZerionRedaction.redact(reason),
            shape: .unavailable,
            requiresAPIKey: true
        )
    }
}

struct ZerionExecutionResult: Codable, Equatable {
    let status: ZerionExecutionStatus
    let chain: String?
    let transactionHash: String?
    let explorerURL: URL?
    let message: String
    let rawStatus: String?
    let completedAt: Date

    static func failed(_ message: String) -> ZerionExecutionResult {
        ZerionExecutionResult(
            status: .failed,
            chain: nil,
            transactionHash: nil,
            explorerURL: nil,
            message: ZerionRedaction.redact(message),
            rawStatus: nil,
            completedAt: Date()
        )
    }
}
