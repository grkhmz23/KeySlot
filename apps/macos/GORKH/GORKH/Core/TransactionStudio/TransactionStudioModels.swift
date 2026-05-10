import Foundation

enum TransactionStudioInputKind: String, Codable, CaseIterable, Identifiable {
    case signature
    case rawTransaction
    case address
    case importHandoff
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signature:
            return "Signature"
        case .rawTransaction:
            return "Raw transaction"
        case .address:
            return "Address"
        case .importHandoff:
            return "Import handoff"
        case .unknown:
            return "Unknown"
        }
    }
}

enum TransactionStudioEncoding: String, Codable, Equatable {
    case base58
    case base64
    case plain
    case unknown
}

struct TransactionStudioInput: Codable, Equatable, Identifiable {
    let id: UUID
    let rawValue: String
    let kind: TransactionStudioInputKind
    let encoding: TransactionStudioEncoding
    let detectedAt: Date
    let safePreview: String

    init(
        id: UUID = UUID(),
        rawValue: String,
        kind: TransactionStudioInputKind,
        encoding: TransactionStudioEncoding,
        detectedAt: Date = Date()
    ) {
        self.id = id
        self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        self.kind = kind
        self.encoding = encoding
        self.detectedAt = detectedAt
        self.safePreview = Self.preview(for: self.rawValue)
    }

    private static func preview(for value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 18 else {
            return trimmed
        }
        return "\(trimmed.prefix(8))...\(trimmed.suffix(8))"
    }
}

enum TransactionStudioStatus: String, Codable, Equatable {
    case idle
    case decoding
    case decoded
    case fetching
    case simulating
    case simulated
    case failed
    case unavailable

    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .decoding:
            return "Decoding"
        case .decoded:
            return "Decoded"
        case .fetching:
            return "Fetching"
        case .simulating:
            return "Simulating"
        case .simulated:
            return "Simulated"
        case .failed:
            return "Failed"
        case .unavailable:
            return "Unavailable"
        }
    }
}

enum TransactionStudioDecodeError: LocalizedError, Equatable {
    case emptyInput
    case unsupportedInput
    case invalidSignature
    case invalidAddress
    case invalidRawTransaction(String)
    case forbiddenField(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Paste a Solana signature, raw transaction, or address."
        case .unsupportedInput:
            return "Input is not a recognized Solana signature, address, or encoded transaction."
        case .invalidSignature:
            return "Signature must be a 64-byte base58 Solana signature."
        case .invalidAddress:
            return "Address must be a 32-byte base58 Solana public key."
        case .invalidRawTransaction(let reason):
            return reason
        case .forbiddenField(let field):
            return "Input contains forbidden private material: \(field)."
        }
    }
}

struct DecodedAccountMeta: Codable, Equatable, Identifiable {
    var id: String { "\(index):\(address)" }

    let index: Int
    let address: String
    let isSigner: Bool
    let isWritable: Bool
}

struct DecodedInstruction: Codable, Equatable, Identifiable {
    var id: String { "\(index):\(programID):\(dataLength)" }

    let index: Int
    let programID: String
    let programLabel: String
    let accounts: [DecodedAccountMeta]
    let dataLength: Int
    let decodedAction: String
    let riskHints: [String]
}

struct ProgramSummary: Codable, Equatable, Identifiable {
    var id: String { programID }

    let programID: String
    let label: String
    let instructionCount: Int
}

struct SignerSummary: Codable, Equatable, Identifiable {
    var id: String { address }

    let address: String
    let isFeePayer: Bool
}

struct WritableAccountSummary: Codable, Equatable, Identifiable {
    var id: String { address }

    let address: String
    let isSigner: Bool
}

struct AddressLookupTableSummary: Codable, Equatable, Identifiable {
    var id: String { tableAddress }

    let tableAddress: String
    let writableIndexCount: Int
    let readonlyIndexCount: Int
}

struct TransactionFeeSummary: Codable, Equatable {
    let requiredSignatureCount: Int
    let estimatedFeeLamports: UInt64?

    var displayText: String {
        guard let estimatedFeeLamports else {
            return "Fee unavailable"
        }
        return "\(estimatedFeeLamports) lamports"
    }
}

struct DecodedTransaction: Codable, Equatable, Identifiable {
    var id: String { fingerprint }

    let inputKind: TransactionStudioInputKind
    let network: WalletNetwork
    let transactionVersion: String
    let signatureCount: Int
    let signatures: [String]
    let feePayer: String?
    let recentBlockhash: String
    let accountMetas: [DecodedAccountMeta]
    let instructions: [DecodedInstruction]
    let programSummaries: [ProgramSummary]
    let signerSummaries: [SignerSummary]
    let writableAccounts: [WritableAccountSummary]
    let addressLookupTables: [AddressLookupTableSummary]
    let feeSummary: TransactionFeeSummary
    let messageBase64: String
    let simulationTransactionBase64: String?
    let fetchedSignature: String?
    let slot: UInt64?
    let blockTime: Date?
    let fingerprint: String
    let decodedAt: Date
}

enum TransactionStudioSimulationStatus: String, Codable, Equatable {
    case notRun
    case success
    case failed
    case unavailable

    var title: String {
        switch self {
        case .notRun:
            return "Not run"
        case .success:
            return "Passed"
        case .failed:
            return "Failed"
        case .unavailable:
            return "Unavailable"
        }
    }
}

struct TransactionStudioSimulationSummary: Codable, Equatable {
    let status: TransactionStudioSimulationStatus
    let logs: [String]
    let unitsConsumed: UInt64?
    let errorMessage: String?
    let replacementBlockhashUsed: Bool
    let simulatedAt: Date

    static let notRun = TransactionStudioSimulationSummary(
        status: .notRun,
        logs: [],
        unitsConsumed: nil,
        errorMessage: nil,
        replacementBlockhashUsed: false,
        simulatedAt: Date()
    )

    static func unavailable(_ reason: String) -> TransactionStudioSimulationSummary {
        TransactionStudioSimulationSummary(
            status: .unavailable,
            logs: [],
            unitsConsumed: nil,
            errorMessage: reason,
            replacementBlockhashUsed: false,
            simulatedAt: Date()
        )
    }
}

enum TransactionRiskLevel: String, Codable, Equatable, CaseIterable {
    case low
    case medium
    case high
    case unknown

    var title: String {
        rawValue.capitalized
    }
}

enum TransactionRiskFlagKind: String, Codable, Equatable, CaseIterable {
    case unknownProgram
    case manyWritableAccounts
    case unexpectedSigner
    case tokenTransfer
    case nativeSOLTransfer
    case authorityChange
    case closeAccount
    case approveDelegate
    case token2022TransferHook
    case token2022TransferFee
    case upgradeableProgramInteraction
    case addressLookupTableUse
    case highComputeUsage
    case simulationFailed
    case missingSimulation
    case mainnetTransaction
    case privateCloakProgramInteraction
    case defiProtocolInteraction
    case accountOwnerMismatch
}

struct TransactionRiskFlag: Codable, Equatable, Identifiable {
    var id: String { "\(kind.rawValue):\(message)" }

    let kind: TransactionRiskFlagKind
    let level: TransactionRiskLevel
    let message: String
}

struct TransactionRiskReview: Codable, Equatable {
    let level: TransactionRiskLevel
    let flags: [TransactionRiskFlag]
    let generatedAt: Date

    static let empty = TransactionRiskReview(level: .unknown, flags: [], generatedAt: Date())
}

struct TransactionExplanation: Codable, Equatable {
    let summary: String
    let reviewChecklist: [String]
    let source: String
    let generatedAt: Date
}

struct TransactionStudioAddressSummary: Codable, Equatable {
    let address: String
    let ownerProgram: String?
    let ownerLabel: String?
    let lamports: UInt64?
    let executable: Bool?
    let dataLength: Int?
    let tokenAccountSummary: String?
    let warning: String?
    let fetchedAt: Date
}

struct TransactionStudioFetchedTransaction: Codable, Equatable {
    let signature: String
    let transactionBase64: String
    let slot: UInt64?
    let blockTime: Date?
}

struct TransactionStudioHistoryEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let inputKind: TransactionStudioInputKind
    let publicReference: String
    let summary: String
    let riskLevel: TransactionRiskLevel
    let simulationStatus: TransactionStudioSimulationStatus
    let createdAt: Date

    init(
        id: UUID = UUID(),
        inputKind: TransactionStudioInputKind,
        publicReference: String,
        summary: String,
        riskLevel: TransactionRiskLevel,
        simulationStatus: TransactionStudioSimulationStatus,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.inputKind = inputKind
        self.publicReference = publicReference
        self.summary = summary
        self.riskLevel = riskLevel
        self.simulationStatus = simulationStatus
        self.createdAt = createdAt
    }
}

enum TransactionStudioAuditEventKind: String, Codable, CaseIterable {
    case studioOpened = "transaction_studio_opened"
    case decodeAttempted = "transaction_studio_decode_attempted"
    case decodeSucceeded = "transaction_studio_decode_succeeded"
    case decodeFailed = "transaction_studio_decode_failed"
    case simulationAttempted = "transaction_studio_simulation_attempted"
    case simulationSucceeded = "transaction_studio_simulation_succeeded"
    case simulationFailed = "transaction_studio_simulation_failed"
    case riskReviewGenerated = "transaction_studio_risk_review_generated"
    case explanationGenerated = "transaction_studio_explanation_generated"
    case handoffCreated = "transaction_studio_handoff_created"
}
