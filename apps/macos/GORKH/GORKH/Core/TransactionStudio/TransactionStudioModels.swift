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
    let parseStatus: TransactionInstructionParseStatus
    let parsedSummary: TransactionParsedInstruction
}

enum TransactionInstructionParseStatus: String, Codable, Equatable, CaseIterable {
    case recognized
    case partial
    case unknown

    var title: String {
        switch self {
        case .recognized:
            return "Recognized"
        case .partial:
            return "Partial"
        case .unknown:
            return "Unknown"
        }
    }
}

struct TransactionInstructionDetail: Codable, Equatable, Identifiable {
    var id: String { "\(label):\(value)" }

    let label: String
    let value: String
}

struct TransactionParsedInstruction: Codable, Equatable {
    let status: TransactionInstructionParseStatus
    let action: String
    let details: [TransactionInstructionDetail]
    let riskHints: [String]
    let explanationFragment: String?

    static let unknown = TransactionParsedInstruction(
        status: .unknown,
        action: "Unknown instruction data",
        details: [],
        riskHints: ["Unknown instruction data"],
        explanationFragment: "Some instructions are unknown and require caution."
    )
}

struct ProgramSummary: Codable, Equatable, Identifiable {
    var id: String { programID }

    let programID: String
    let label: String
    let category: TransactionProgramCategory
    let instructionCount: Int

    init(programID: String, label: String, category: TransactionProgramCategory? = nil, instructionCount: Int) {
        self.programID = programID
        self.label = label
        self.category = category ?? TransactionProgramCatalog.entry(for: programID).category
        self.instructionCount = instructionCount
    }

    private enum CodingKeys: String, CodingKey {
        case programID
        case label
        case category
        case instructionCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        programID = try container.decode(String.self, forKey: .programID)
        label = try container.decode(String.self, forKey: .label)
        category = try container.decodeIfPresent(TransactionProgramCategory.self, forKey: .category)
            ?? TransactionProgramCatalog.entry(for: programID).category
        instructionCount = try container.decode(Int.self, forKey: .instructionCount)
    }
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
    let writableIndexes: [Int]
    let readonlyIndexes: [Int]
    let loadedWritableAddresses: [String]
    let loadedReadonlyAddresses: [String]
    let resolutionStatus: TransactionAddressLookupResolutionStatus
    let resolutionReason: String?

    init(
        tableAddress: String,
        writableIndexCount: Int,
        readonlyIndexCount: Int,
        writableIndexes: [Int] = [],
        readonlyIndexes: [Int] = [],
        loadedWritableAddresses: [String] = [],
        loadedReadonlyAddresses: [String] = [],
        resolutionStatus: TransactionAddressLookupResolutionStatus = .unresolved,
        resolutionReason: String? = nil
    ) {
        self.tableAddress = tableAddress
        self.writableIndexCount = writableIndexCount
        self.readonlyIndexCount = readonlyIndexCount
        self.writableIndexes = writableIndexes
        self.readonlyIndexes = readonlyIndexes
        self.loadedWritableAddresses = loadedWritableAddresses
        self.loadedReadonlyAddresses = loadedReadonlyAddresses
        self.resolutionStatus = resolutionStatus
        self.resolutionReason = resolutionReason
    }

    private enum CodingKeys: String, CodingKey {
        case tableAddress
        case writableIndexCount
        case readonlyIndexCount
        case writableIndexes
        case readonlyIndexes
        case loadedWritableAddresses
        case loadedReadonlyAddresses
        case resolutionStatus
        case resolutionReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tableAddress = try container.decode(String.self, forKey: .tableAddress)
        writableIndexCount = try container.decode(Int.self, forKey: .writableIndexCount)
        readonlyIndexCount = try container.decode(Int.self, forKey: .readonlyIndexCount)
        writableIndexes = try container.decodeIfPresent([Int].self, forKey: .writableIndexes) ?? []
        readonlyIndexes = try container.decodeIfPresent([Int].self, forKey: .readonlyIndexes) ?? []
        loadedWritableAddresses = try container.decodeIfPresent([String].self, forKey: .loadedWritableAddresses) ?? []
        loadedReadonlyAddresses = try container.decodeIfPresent([String].self, forKey: .loadedReadonlyAddresses) ?? []
        resolutionStatus = try container.decodeIfPresent(TransactionAddressLookupResolutionStatus.self, forKey: .resolutionStatus)
            ?? ((loadedWritableAddresses.isEmpty && loadedReadonlyAddresses.isEmpty) ? .unresolved : .loaded)
        resolutionReason = try container.decodeIfPresent(String.self, forKey: .resolutionReason)
    }
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
    let staticAccountCount: Int
    let accountMetas: [DecodedAccountMeta]
    let instructions: [DecodedInstruction]
    let programSummaries: [ProgramSummary]
    let signerSummaries: [SignerSummary]
    let writableAccounts: [WritableAccountSummary]
    let addressLookupTables: [AddressLookupTableSummary]
    let addressLookupOverview: TransactionAddressLookupOverview
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
    let watchList: TransactionAccountWatchList
    let accountDiff: TransactionSimulationDiffSummary
    let simulatedAt: Date

    init(
        status: TransactionStudioSimulationStatus,
        logs: [String],
        unitsConsumed: UInt64?,
        errorMessage: String?,
        replacementBlockhashUsed: Bool,
        watchList: TransactionAccountWatchList = .empty,
        accountDiff: TransactionSimulationDiffSummary = .notRequested,
        simulatedAt: Date
    ) {
        self.status = status
        self.logs = logs
        self.unitsConsumed = unitsConsumed
        self.errorMessage = errorMessage
        self.replacementBlockhashUsed = replacementBlockhashUsed
        self.watchList = watchList
        self.accountDiff = accountDiff
        self.simulatedAt = simulatedAt
    }

    static let notRun = TransactionStudioSimulationSummary(
        status: .notRun,
        logs: [],
        unitsConsumed: nil,
        errorMessage: nil,
        replacementBlockhashUsed: false,
        watchList: .empty,
        accountDiff: .notRequested,
        simulatedAt: Date()
    )

    static func unavailable(_ reason: String) -> TransactionStudioSimulationSummary {
        TransactionStudioSimulationSummary(
            status: .unavailable,
            logs: [],
            unitsConsumed: nil,
            errorMessage: reason,
            replacementBlockhashUsed: false,
            watchList: .empty,
            accountDiff: .unavailable(reason),
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
    case addressLookupTableUnavailable
    case manyLoadedWritableAccounts
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
    let loadedWritableAddresses: [String]
    let loadedReadonlyAddresses: [String]

    init(
        signature: String,
        transactionBase64: String,
        slot: UInt64?,
        blockTime: Date?,
        loadedWritableAddresses: [String] = [],
        loadedReadonlyAddresses: [String] = []
    ) {
        self.signature = signature
        self.transactionBase64 = transactionBase64
        self.slot = slot
        self.blockTime = blockTime
        self.loadedWritableAddresses = loadedWritableAddresses
        self.loadedReadonlyAddresses = loadedReadonlyAddresses
    }
}

struct TransactionStudioHistoryEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let inputKind: TransactionStudioInputKind
    let publicReference: String
    let summary: String
    let riskLevel: TransactionRiskLevel
    let simulationStatus: TransactionStudioSimulationStatus
    let recognizedInstructionCount: Int
    let unknownInstructionCount: Int
    let transactionVersion: String?
    let altUsed: Bool
    let accountDiffAvailable: Bool
    let loadedAccountCount: Int
    let topProgramCategories: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        inputKind: TransactionStudioInputKind,
        publicReference: String,
        summary: String,
        riskLevel: TransactionRiskLevel,
        simulationStatus: TransactionStudioSimulationStatus,
        recognizedInstructionCount: Int = 0,
        unknownInstructionCount: Int = 0,
        transactionVersion: String? = nil,
        altUsed: Bool = false,
        accountDiffAvailable: Bool = false,
        loadedAccountCount: Int = 0,
        topProgramCategories: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.inputKind = inputKind
        self.publicReference = publicReference
        self.summary = summary
        self.riskLevel = riskLevel
        self.simulationStatus = simulationStatus
        self.recognizedInstructionCount = recognizedInstructionCount
        self.unknownInstructionCount = unknownInstructionCount
        self.transactionVersion = transactionVersion
        self.altUsed = altUsed
        self.accountDiffAvailable = accountDiffAvailable
        self.loadedAccountCount = loadedAccountCount
        self.topProgramCategories = topProgramCategories
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case inputKind
        case publicReference
        case summary
        case riskLevel
        case simulationStatus
        case recognizedInstructionCount
        case unknownInstructionCount
        case transactionVersion
        case altUsed
        case accountDiffAvailable
        case loadedAccountCount
        case topProgramCategories
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        inputKind = try container.decode(TransactionStudioInputKind.self, forKey: .inputKind)
        publicReference = try container.decode(String.self, forKey: .publicReference)
        summary = try container.decode(String.self, forKey: .summary)
        riskLevel = try container.decode(TransactionRiskLevel.self, forKey: .riskLevel)
        simulationStatus = try container.decode(TransactionStudioSimulationStatus.self, forKey: .simulationStatus)
        recognizedInstructionCount = try container.decodeIfPresent(Int.self, forKey: .recognizedInstructionCount) ?? 0
        unknownInstructionCount = try container.decodeIfPresent(Int.self, forKey: .unknownInstructionCount) ?? 0
        transactionVersion = try container.decodeIfPresent(String.self, forKey: .transactionVersion)
        altUsed = try container.decodeIfPresent(Bool.self, forKey: .altUsed) ?? false
        accountDiffAvailable = try container.decodeIfPresent(Bool.self, forKey: .accountDiffAvailable) ?? false
        loadedAccountCount = try container.decodeIfPresent(Int.self, forKey: .loadedAccountCount) ?? 0
        topProgramCategories = try container.decodeIfPresent([String].self, forKey: .topProgramCategories) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
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
