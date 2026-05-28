import Foundation

enum TransactionDebugStatus: String, Codable, Equatable, CaseIterable {
    case success
    case failed
    case notFound = "not_found"
    case unsupported

    var title: String {
        switch self {
        case .success:
            return "Success"
        case .failed:
            return "Failed"
        case .notFound:
            return "Not found"
        case .unsupported:
            return "Unsupported"
        }
    }
}

enum TransactionDebugPane: String, CaseIterable, Identifiable {
    case summary
    case instructionTree = "instruction_tree"
    case logs
    case accounts
    case compute
    case errorMapping = "error_mapping"
    case pdaChecks = "pda_checks"
    case evidence

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary:
            return "Summary"
        case .instructionTree:
            return "Instruction Tree"
        case .logs:
            return "Logs"
        case .accounts:
            return "Accounts"
        case .compute:
            return "Compute"
        case .errorMapping:
            return "Error Mapping"
        case .pdaChecks:
            return "PDA Checks"
        case .evidence:
            return "Evidence"
        }
    }
}

struct TransactionLogSummary: Codable, Equatable {
    let totalLines: Int
    let errorLineCount: Int
    let computeLineCount: Int
    let failedProgramID: String?
    let failedProgramLine: String?
}

struct TransactionAnchorError: Codable, Equatable, Identifiable {
    var id: String { "\(errorCode ?? "anchor"):\(errorNumber.map(String.init) ?? "unknown")" }

    let errorCode: String?
    let errorNumber: Int?
    let errorMessage: String?
    let sourceLine: String?
}

struct TransactionCustomProgramError: Codable, Equatable, Identifiable {
    var id: String { "\(programID ?? "unknown"):\(hexCode):\(decimalCode)" }

    let programID: String?
    let hexCode: String
    let decimalCode: Int
    let sourceLine: String
}

struct TransactionIDLErrorMatch: Codable, Equatable, Identifiable {
    var id: String { "\(code):\(name)" }

    let code: Int
    let name: String
    let message: String?
    let source: String
}

struct TransactionComputeEvent: Codable, Equatable, Identifiable {
    var id: String { "\(programID):\(consumed):\(limit ?? 0)" }

    let programID: String
    let programName: String
    let consumed: UInt64
    let limit: UInt64?
    let line: String
}

struct TransactionDebugAccountEntry: Codable, Equatable, Identifiable {
    var id: String { "\(index):\(pubkey)" }

    let index: Int
    let pubkey: String
    let isSigner: Bool
    let isWritable: Bool
    let idlAccountName: String?
    let ownerProgram: String?
    let ownerLabel: String?
    let lamports: UInt64?
    let executable: Bool?
    let dataLength: Int?
    let tokenMint: String?
    let tokenOwner: String?
    let tokenAmountRaw: String?
    let detailFetchedAt: Date?

    init(
        index: Int,
        pubkey: String,
        isSigner: Bool,
        isWritable: Bool,
        idlAccountName: String? = nil,
        ownerProgram: String? = nil,
        ownerLabel: String? = nil,
        lamports: UInt64? = nil,
        executable: Bool? = nil,
        dataLength: Int? = nil,
        tokenMint: String? = nil,
        tokenOwner: String? = nil,
        tokenAmountRaw: String? = nil,
        detailFetchedAt: Date? = nil
    ) {
        self.index = index
        self.pubkey = pubkey
        self.isSigner = isSigner
        self.isWritable = isWritable
        self.idlAccountName = idlAccountName
        self.ownerProgram = ownerProgram
        self.ownerLabel = ownerLabel
        self.lamports = lamports
        self.executable = executable
        self.dataLength = dataLength
        self.tokenMint = tokenMint
        self.tokenOwner = tokenOwner
        self.tokenAmountRaw = tokenAmountRaw
        self.detailFetchedAt = detailFetchedAt
    }

    func withDetail(_ detail: TransactionDebugAccountDetail) -> TransactionDebugAccountEntry {
        TransactionDebugAccountEntry(
            index: index,
            pubkey: pubkey,
            isSigner: isSigner,
            isWritable: isWritable,
            idlAccountName: idlAccountName,
            ownerProgram: detail.ownerProgram,
            ownerLabel: detail.ownerLabel,
            lamports: detail.lamports,
            executable: detail.executable,
            dataLength: detail.dataLength,
            tokenMint: detail.tokenMint,
            tokenOwner: detail.tokenOwner,
            tokenAmountRaw: detail.tokenAmountRaw,
            detailFetchedAt: detail.fetchedAt
        )
    }
}

struct TransactionDebugAccountDetail: Codable, Equatable {
    let address: String
    let ownerProgram: String?
    let ownerLabel: String?
    let lamports: UInt64?
    let executable: Bool?
    let dataLength: Int?
    let tokenMint: String?
    let tokenOwner: String?
    let tokenAmountRaw: String?
    let fetchedAt: Date
}

struct InstructionDebugNode: Codable, Equatable, Identifiable {
    let id: String
    let index: Int
    let programID: String
    let programName: String
    let instructionName: String
    let accounts: [String]
    let signerWritableHints: [String]
    let innerInstructions: [InstructionDebugNode]
    let logs: [String]
    let computeUnitsConsumed: UInt64?
    let errorAtThisInstruction: Bool
}

struct TransactionPDAMismatchCandidate: Codable, Equatable, Identifiable {
    var id: String { "\(instructionName ?? "unknown"):\(accountName ?? "unknown"):\(actualAddress ?? "none")" }

    let severity: ProjectBrainWarningSeverity
    let instructionName: String?
    let accountName: String?
    let expectedAddress: String?
    let actualAddress: String?
    let reason: String
    let deterministic: Bool
}

struct TransactionDebugReport: Codable, Equatable, Identifiable {
    let id: UUID
    let signature: String
    let cluster: WorkstationCluster
    let fetchedAt: Date
    let status: TransactionDebugStatus
    let slot: UInt64?
    let blockTime: Date?
    let fee: UInt64?
    let err: String?
    let programIds: [String]
    let topLevelInstructions: [InstructionDebugNode]
    let innerInstructions: [InstructionDebugNode]
    let logs: [String]
    let logSummary: TransactionLogSummary
    let anchorError: TransactionAnchorError?
    let customProgramError: TransactionCustomProgramError?
    let idlErrorMatch: TransactionIDLErrorMatch?
    let computeUnits: UInt64?
    let computeTimeline: [TransactionComputeEvent]
    let accountTable: [TransactionDebugAccountEntry]
    let pdaMismatchCandidates: [TransactionPDAMismatchCandidate]
    let likelyRootCause: String
    let suggestedNextSteps: [String]
    let replaySupportStatus: String
    let evidenceId: UUID

    init(
        id: UUID = UUID(),
        signature: String,
        cluster: WorkstationCluster,
        fetchedAt: Date = Date(),
        status: TransactionDebugStatus,
        slot: UInt64?,
        blockTime: Date?,
        fee: UInt64?,
        err: String?,
        programIds: [String],
        topLevelInstructions: [InstructionDebugNode],
        innerInstructions: [InstructionDebugNode],
        logs: [String],
        logSummary: TransactionLogSummary,
        anchorError: TransactionAnchorError?,
        customProgramError: TransactionCustomProgramError?,
        idlErrorMatch: TransactionIDLErrorMatch?,
        computeUnits: UInt64?,
        computeTimeline: [TransactionComputeEvent],
        accountTable: [TransactionDebugAccountEntry],
        pdaMismatchCandidates: [TransactionPDAMismatchCandidate],
        likelyRootCause: String,
        suggestedNextSteps: [String],
        replaySupportStatus: String,
        evidenceId: UUID? = nil
    ) {
        self.id = id
        self.signature = Self.safePublicIdentifier(signature)
        self.cluster = cluster
        self.fetchedAt = fetchedAt
        self.status = status
        self.slot = slot
        self.blockTime = blockTime
        self.fee = fee
        self.err = err.map(Self.safeText)
        self.programIds = programIds.map(Self.safePublicIdentifier)
        self.topLevelInstructions = topLevelInstructions
        self.innerInstructions = innerInstructions
        self.logs = Self.boundedLogs(logs)
        self.logSummary = logSummary
        self.anchorError = anchorError
        self.customProgramError = customProgramError
        self.idlErrorMatch = idlErrorMatch
        self.computeUnits = computeUnits
        self.computeTimeline = computeTimeline
        self.accountTable = accountTable
        self.pdaMismatchCandidates = pdaMismatchCandidates
        self.likelyRootCause = Self.safeText(likelyRootCause)
        self.suggestedNextSteps = suggestedNextSteps.map(Self.safeText)
        self.replaySupportStatus = Self.safeText(replaySupportStatus)
        self.evidenceId = evidenceId ?? id
    }

    var shortSignature: String {
        guard signature.count > 18 else {
            return signature
        }
        return "\(signature.prefix(8))...\(signature.suffix(8))"
    }

    func replacingAccountTable(_ accountTable: [TransactionDebugAccountEntry]) -> TransactionDebugReport {
        TransactionDebugReport(
            id: id,
            signature: signature,
            cluster: cluster,
            fetchedAt: fetchedAt,
            status: status,
            slot: slot,
            blockTime: blockTime,
            fee: fee,
            err: err,
            programIds: programIds,
            topLevelInstructions: topLevelInstructions,
            innerInstructions: innerInstructions,
            logs: logs,
            logSummary: logSummary,
            anchorError: anchorError,
            customProgramError: customProgramError,
            idlErrorMatch: idlErrorMatch,
            computeUnits: computeUnits,
            computeTimeline: computeTimeline,
            accountTable: accountTable,
            pdaMismatchCandidates: pdaMismatchCandidates,
            likelyRootCause: likelyRootCause,
            suggestedNextSteps: suggestedNextSteps,
            replaySupportStatus: replaySupportStatus,
            evidenceId: evidenceId
        )
    }

    static func notFound(signature: String, cluster: WorkstationCluster) -> TransactionDebugReport {
        let summary = TransactionLogSummary(
            totalLines: 0,
            errorLineCount: 0,
            computeLineCount: 0,
            failedProgramID: nil,
            failedProgramLine: nil
        )
        return TransactionDebugReport(
            signature: signature,
            cluster: cluster,
            status: .notFound,
            slot: nil,
            blockTime: nil,
            fee: nil,
            err: nil,
            programIds: [],
            topLevelInstructions: [],
            innerInstructions: [],
            logs: [],
            logSummary: summary,
            anchorError: nil,
            customProgramError: nil,
            idlErrorMatch: nil,
            computeUnits: nil,
            computeTimeline: [],
            accountTable: [],
            pdaMismatchCandidates: [],
            likelyRootCause: "RPC returned no transaction for this signature.",
            suggestedNextSteps: ["Confirm the signature and selected cluster.", "If the transaction is recent, wait for confirmation and retry."],
            replaySupportStatus: "No transaction data was available to replay or decode."
        )
    }

    static func unsupported(signature: String, cluster: WorkstationCluster, reason: String) -> TransactionDebugReport {
        let summary = TransactionLogSummary(
            totalLines: 0,
            errorLineCount: 0,
            computeLineCount: 0,
            failedProgramID: nil,
            failedProgramLine: nil
        )
        return TransactionDebugReport(
            signature: signature,
            cluster: cluster,
            status: .unsupported,
            slot: nil,
            blockTime: nil,
            fee: nil,
            err: reason,
            programIds: [],
            topLevelInstructions: [],
            innerInstructions: [],
            logs: [],
            logSummary: summary,
            anchorError: nil,
            customProgramError: nil,
            idlErrorMatch: nil,
            computeUnits: nil,
            computeTimeline: [],
            accountTable: [],
            pdaMismatchCandidates: [],
            likelyRootCause: reason,
            suggestedNextSteps: ["Use a confirmed Solana transaction signature.", "Transaction Debugger remains read-only and cannot submit or modify transactions."],
            replaySupportStatus: "Unsupported response could not be decoded."
        )
    }

    nonisolated private static func boundedLogs(_ logs: [String]) -> [String] {
        logs.prefix(240).map { safeText(String($0.prefix(900))) }
    }

    nonisolated private static func safePublicIdentifier(_ value: String) -> String {
        AgentSafetyRedactor.redact(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    nonisolated private static func safeText(_ value: String) -> String {
        removeSecretLabels(AgentSafetyRedactor.redact(value.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    nonisolated private static func removeSecretLabels(_ value: String) -> String {
        [
            "privateKey",
            "private key",
            "secretKey",
            "secret key",
            "seed phrase",
            "mnemonic",
            "wallet JSON",
            "signingSeed",
            "signing seed",
            "RPC secret",
            "api key"
        ].reduce(value) { text, term in
            text.replacingOccurrences(of: term, with: "[redacted]", options: [.caseInsensitive])
        }
    }
}

final class TransactionDebugEvidenceStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [TransactionDebugReport] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        return (try? decoder.decode([TransactionDebugReport].self, from: data)) ?? []
    }

    func append(_ report: TransactionDebugReport) throws -> [TransactionDebugReport] {
        var entries = load()
        entries.insert(report, at: 0)
        entries = Array(entries.prefix(80))
        try save(entries)
        return entries
    }

    func save(_ reports: [TransactionDebugReport]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(reports)
        try data.write(to: fileURL, options: [.atomic])
    }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("KeySlot", isDirectory: true)
            .appendingPathComponent("DeveloperWorkstation", isDirectory: true)
            .appendingPathComponent("transaction-debug-evidence.json")
    }
}
