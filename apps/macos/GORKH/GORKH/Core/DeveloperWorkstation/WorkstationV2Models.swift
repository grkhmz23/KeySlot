import Foundation

enum DeveloperWorkstationV2Capability: String, CaseIterable, Identifiable, Codable {
    case projectBrain
    case transactionDebugger
    case pdaExplorer
    case idlDrift
    case enhancedAccountDecoder
    case fixtureStudio
    case testWorkbench
    case computeRegression
    case releaseManager
    case securityScanner
    case frontendAssistant
    case constrainedAgent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projectBrain:
            return "Solana Project Brain"
        case .transactionDebugger:
            return "Transaction Debugger"
        case .pdaExplorer:
            return "PDA Explorer"
        case .idlDrift:
            return "IDL Drift Detector"
        case .enhancedAccountDecoder:
            return "Enhanced Account Decoder"
        case .fixtureStudio:
            return "Fixture & Snapshot Studio"
        case .testWorkbench:
            return "Test Workbench"
        case .computeRegression:
            return "Compute Regression"
        case .releaseManager:
            return "Deployment Release Manager"
        case .securityScanner:
            return "Solana Security Scanner"
        case .frontendAssistant:
            return "Frontend Integration Assistant"
        case .constrainedAgent:
            return "Workstation Agent"
        }
    }

    var readWriteMode: String {
        switch self {
        case .projectBrain, .transactionDebugger, .pdaExplorer, .idlDrift, .enhancedAccountDecoder,
             .fixtureStudio, .computeRegression, .releaseManager, .securityScanner, .frontendAssistant,
             .constrainedAgent:
            return "Read-only analysis"
        case .testWorkbench:
            return "Preview-only until a fixed test command is approved"
        }
    }
}

enum WorkstationV2ReportStatus: String, Codable, Equatable {
    case ready
    case warning
    case blocked
    case unavailable

    var title: String {
        switch self {
        case .ready:
            return "Ready"
        case .warning:
            return "Needs review"
        case .blocked:
            return "Blocked"
        case .unavailable:
            return "Unavailable"
        }
    }
}

enum WorkstationV2FindingSeverity: String, Codable, Equatable {
    case info
    case low
    case medium
    case high

    var title: String {
        rawValue.capitalized
    }
}

struct WorkstationV2Finding: Codable, Equatable, Identifiable {
    let id: String
    let severity: WorkstationV2FindingSeverity
    let title: String
    let detail: String
    let evidence: String?

    init(
        id: String,
        severity: WorkstationV2FindingSeverity,
        title: String,
        detail: String,
        evidence: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.title = AgentSafetyRedactor.redact(title)
        self.detail = AgentSafetyRedactor.redact(detail)
        self.evidence = evidence.map(AgentSafetyRedactor.redact)
    }
}

struct WorkstationV2Report: Codable, Equatable, Identifiable {
    let id: String
    let capability: DeveloperWorkstationV2Capability
    let status: WorkstationV2ReportStatus
    let summary: String
    let findings: [WorkstationV2Finding]
    let nextActions: [String]
    let evidence: [String]

    init(
        capability: DeveloperWorkstationV2Capability,
        status: WorkstationV2ReportStatus,
        summary: String,
        findings: [WorkstationV2Finding] = [],
        nextActions: [String] = [],
        evidence: [String] = []
    ) {
        self.id = capability.rawValue
        self.capability = capability
        self.status = status
        self.summary = AgentSafetyRedactor.redact(summary)
        self.findings = findings
        self.nextActions = nextActions.map(AgentSafetyRedactor.redact)
        self.evidence = evidence.map(AgentSafetyRedactor.redact)
    }
}

enum WorkstationPDADerivationStatus: String, Codable, Equatable {
    case derived
    case mismatch
    case missingProgramID
    case dynamicSeedsUnavailable
    case noPDAMetadata
    case invalidInput
}

struct WorkstationPDAFinding: Codable, Equatable, Identifiable {
    var id: String { "\(instructionName):\(accountName)" }

    let instructionName: String
    let accountName: String
    let seedSummary: String
    let derivedAddress: String?
    let bump: UInt8?
    let expectedAddress: String?
    let status: WorkstationPDADerivationStatus
    let message: String
}

struct WorkstationIDLDriftSummary: Codable, Equatable {
    let status: WorkstationV2ReportStatus
    let idlProgramName: String?
    let idlAddress: String?
    let selectedProgramID: String?
    let latestEvidenceProgramID: String?
    let message: String
}

enum WorkstationTransactionDebugInputStatus: String, Codable, Equatable {
    case empty
    case signature
    case rawDecoded
    case unsupported
    case forbidden
}

struct WorkstationTransactionDebugSummary: Codable, Equatable {
    let status: WorkstationTransactionDebugInputStatus
    let message: String
    let transactionVersion: String?
    let signatureCount: Int?
    let instructionCount: Int?
    let programLabels: [String]
    let signerCount: Int?
    let writableCount: Int?
    let addressLookupTableCount: Int?
    let fingerprint: String?
}

enum WorkstationAgentToolAccess: String, Codable, Equatable {
    case readOnly = "read_only"
    case gatedPreview = "gated_preview"
    case blocked

    var title: String {
        switch self {
        case .readOnly:
            return "Read-only"
        case .gatedPreview:
            return "Gated preview"
        case .blocked:
            return "Blocked"
        }
    }
}

enum DeveloperAgentMode: String, Codable, CaseIterable, Identifiable, Comparable {
    case readOnly = "read_only"
    case suggest
    case patch
    case execute
    case chainWrite = "chain_write"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readOnly:
            return "Read-only"
        case .suggest:
            return "Suggest"
        case .patch:
            return "Patch"
        case .execute:
            return "Execute"
        case .chainWrite:
            return "Chain-write"
        }
    }

    var rank: Int {
        switch self {
        case .readOnly: return 0
        case .suggest: return 1
        case .patch: return 2
        case .execute: return 3
        case .chainWrite: return 4
        }
    }

    static func < (lhs: DeveloperAgentMode, rhs: DeveloperAgentMode) -> Bool {
        lhs.rank < rhs.rank
    }
}

enum DeveloperAgentEvidencePolicy: String, Codable, CaseIterable, Identifiable {
    case none
    case redactedSummary = "redacted_summary"
    case redactedJSON = "redacted_json"
    case existingEvidenceOnly = "existing_evidence_only"

    var id: String { rawValue }

    var title: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct WorkstationAgentTool: Codable, Equatable, Identifiable {
    let id: String
    let displayName: String
    let modeRequired: DeveloperAgentMode
    let readOnly: Bool
    let requiresTrustedProject: Bool
    let allowedClusters: [WorkstationCluster]
    let approvalRequired: Bool
    let evidencePolicy: DeveloperAgentEvidencePolicy
    let inputSchema: String
    let outputSchema: String
    let reason: String

    var title: String { displayName }

    var access: WorkstationAgentToolAccess {
        if DeveloperAgentToolRegistry.unsafeToolIDs.contains(id) {
            return .blocked
        }
        if readOnly && !approvalRequired {
            return .readOnly
        }
        return .gatedPreview
    }

    init(
        id: String,
        displayName: String,
        modeRequired: DeveloperAgentMode,
        readOnly: Bool,
        requiresTrustedProject: Bool,
        allowedClusters: [WorkstationCluster] = WorkstationCluster.allCases,
        approvalRequired: Bool,
        evidencePolicy: DeveloperAgentEvidencePolicy,
        inputSchema: String,
        outputSchema: String,
        reason: String
    ) {
        self.id = id
        self.displayName = displayName
        self.modeRequired = modeRequired
        self.readOnly = readOnly
        self.requiresTrustedProject = requiresTrustedProject
        self.allowedClusters = allowedClusters
        self.approvalRequired = approvalRequired
        self.evidencePolicy = evidencePolicy
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.reason = AgentSafetyRedactor.redact(reason)
    }

    init(id: String, title: String, access: WorkstationAgentToolAccess, reason: String) {
        self.init(
            id: id,
            displayName: title,
            modeRequired: access == .readOnly ? .readOnly : .execute,
            readOnly: access == .readOnly,
            requiresTrustedProject: access == .gatedPreview,
            allowedClusters: access == .blocked ? [] : WorkstationCluster.allCases,
            approvalRequired: access == .gatedPreview,
            evidencePolicy: .redactedSummary,
            inputSchema: "legacy",
            outputSchema: "legacy",
            reason: reason
        )
    }
}

struct DeveloperAgentAuthorization: Codable, Equatable {
    let allowed: Bool
    let approvalRequired: Bool
    let reasons: [String]

    static let allowedReadOnly = DeveloperAgentAuthorization(allowed: true, approvalRequired: false, reasons: [])
}

enum DeveloperAgentToolRegistry {
    static let toolDefinitions: [WorkstationAgentTool] = [
        WorkstationAgentTool(
            id: "project.scanBrain",
            displayName: "Scan Project Brain",
            modeRequired: .readOnly,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedJSON,
            inputSchema: "DeveloperAgentToolInput(projectId)",
            outputSchema: "DeveloperAgentToolOutput(summary, safeJSONPreview)",
            reason: "Runs the existing bounded read-only Project Brain scanner. No project code is executed."
        ),
        WorkstationAgentTool(
            id: "project.getBrain",
            displayName: "Get Project Brain",
            modeRequired: .readOnly,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .existingEvidenceOnly,
            inputSchema: "DeveloperAgentToolInput(projectId)",
            outputSchema: "DeveloperAgentToolOutput(summary, safeJSONPreview)",
            reason: "Reads the current in-memory or stored Project Brain report."
        ),
        WorkstationAgentTool(
            id: "idl.list",
            displayName: "List IDL",
            modeRequired: .readOnly,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedSummary,
            inputSchema: "DeveloperAgentToolInput(idlId)",
            outputSchema: "DeveloperAgentToolOutput(summary, safeJSONPreview)",
            reason: "Reads the loaded Anchor IDL instruction, account, type, error, and event summary."
        ),
        WorkstationAgentTool(
            id: "idl.diff",
            displayName: "Check IDL Drift",
            modeRequired: .readOnly,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedSummary,
            inputSchema: "DeveloperAgentToolInput(programId)",
            outputSchema: "DeveloperAgentToolOutput(summary, findings)",
            reason: "Delegates to the existing IDL drift summary without fetching unreviewed on-chain IDLs."
        ),
        WorkstationAgentTool(
            id: "account.decode",
            displayName: "Decode Account Fixture",
            modeRequired: .readOnly,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedSummary,
            inputSchema: "DeveloperAgentToolInput(address, accountDataBase64, idlAccountName)",
            outputSchema: "DeveloperAgentToolOutput(summary, decodedFieldCount)",
            reason: "Uses the existing bounded Account Decoder on supplied account data or returns an honest unavailable state."
        ),
        WorkstationAgentTool(
            id: "pda.derive",
            displayName: "Derive PDA",
            modeRequired: .readOnly,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedSummary,
            inputSchema: "DeveloperAgentToolInput(programId, seedInputs, expectedAddress)",
            outputSchema: "DeveloperAgentToolOutput(summary, derivedAddress, bump)",
            reason: "Uses the existing real PDA derivation service with seed length and off-curve checks."
        ),
        WorkstationAgentTool(
            id: "transaction.debug",
            displayName: "Debug Transaction",
            modeRequired: .readOnly,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedJSON,
            inputSchema: "DeveloperAgentToolInput(signature)",
            outputSchema: "DeveloperAgentToolOutput(summary, status, evidenceId)",
            reason: "Uses the read-only Transaction Debugger getTransaction flow. It cannot sign or broadcast."
        ),
        WorkstationAgentTool(
            id: "logs.parse",
            displayName: "Parse Logs",
            modeRequired: .readOnly,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedSummary,
            inputSchema: "DeveloperAgentToolInput(logs)",
            outputSchema: "DeveloperAgentToolOutput(summary, computeUnits, errorMatch)",
            reason: "Parses provided logs locally for Anchor/custom errors and compute lines."
        ),
        WorkstationAgentTool(
            id: "rpc.safeRead",
            displayName: "Validate Safe RPC Read",
            modeRequired: .readOnly,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedSummary,
            inputSchema: "DeveloperAgentToolInput(rpcMethod, address, signature, encodedTransaction)",
            outputSchema: "DeveloperAgentToolOutput(summary, permission)",
            reason: "Uses RPC Playground validation for allowlisted read-only methods only."
        ),
        WorkstationAgentTool(
            id: "localnet.status",
            displayName: "Localnet Status",
            modeRequired: .readOnly,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedSummary,
            inputSchema: "DeveloperAgentToolInput()",
            outputSchema: "DeveloperAgentToolOutput(summary)",
            reason: "Reads the current local validator status snapshot."
        ),
        WorkstationAgentTool(
            id: "localnet.startExistingSafeFlow",
            displayName: "Start Localnet Safe Flow",
            modeRequired: .execute,
            readOnly: false,
            requiresTrustedProject: false,
            allowedClusters: [.localnet],
            approvalRequired: true,
            evidencePolicy: .redactedSummary,
            inputSchema: "DeveloperAgentToolInput(approvalPhrase)",
            outputSchema: "DeveloperAgentToolOutput(approvalCard)",
            reason: "Can only hand off to the existing Localnet fixed-command start flow after explicit approval."
        ),
        WorkstationAgentTool(
            id: "test.detect",
            displayName: "Detect Tests",
            modeRequired: .readOnly,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedSummary,
            inputSchema: "DeveloperAgentToolInput(projectId)",
            outputSchema: "DeveloperAgentToolOutput(summary, frameworks)",
            reason: "Reads project files to detect supported test frameworks. It does not run tests."
        ),
        WorkstationAgentTool(
            id: "test.runExistingSafeFlow",
            displayName: "Run Tests Existing Safe Flow",
            modeRequired: .execute,
            readOnly: false,
            requiresTrustedProject: true,
            allowedClusters: [.localnet, .devnet],
            approvalRequired: true,
            evidencePolicy: .redactedJSON,
            inputSchema: "DeveloperAgentToolInput(testFramework, approvalPhrase)",
            outputSchema: "DeveloperAgentToolOutput(approvalCard)",
            reason: "Can only use the existing Test Workbench fixed-command flow with trust and explicit approval."
        ),
        WorkstationAgentTool(
            id: "compute.record",
            displayName: "Record Compute Measurement",
            modeRequired: .suggest,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedSummary,
            inputSchema: "DeveloperAgentToolInput(logs, instructionName)",
            outputSchema: "DeveloperAgentToolOutput(summary, measurementCount)",
            reason: "Extracts compute-unit measurements from real logs. No baseline is fabricated."
        ),
        WorkstationAgentTool(
            id: "program.preflight",
            displayName: "Program Preflight",
            modeRequired: .suggest,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedSummary,
            inputSchema: "DeveloperAgentToolInput(operation, programId, artifactPath)",
            outputSchema: "DeveloperAgentToolOutput(summary, allowed, blockers)",
            reason: "Uses existing Program Manager policy checks and does not run commands."
        ),
        WorkstationAgentTool(
            id: "program.deployExistingSafeFlow",
            displayName: "Deploy Existing Safe Flow",
            modeRequired: .chainWrite,
            readOnly: false,
            requiresTrustedProject: true,
            allowedClusters: [.localnet, .devnet],
            approvalRequired: true,
            evidencePolicy: .redactedJSON,
            inputSchema: "DeveloperAgentToolInput(operation, artifactPath, approvalPhrase)",
            outputSchema: "DeveloperAgentToolOutput(approvalCard)",
            reason: "Can only hand off to existing localnet/devnet Program Manager gates. Mainnet remains locked."
        ),
        WorkstationAgentTool(
            id: "security.scan",
            displayName: "Run Security Scanner",
            modeRequired: .readOnly,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedJSON,
            inputSchema: "DeveloperAgentToolInput(projectId)",
            outputSchema: "DeveloperAgentToolOutput(summary, findingCount)",
            reason: "Runs the deterministic read-only Security Scanner. It does not execute project code."
        ),
        WorkstationAgentTool(
            id: "frontend.inspect",
            displayName: "Inspect Frontend",
            modeRequired: .readOnly,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedSummary,
            inputSchema: "DeveloperAgentToolInput(projectId)",
            outputSchema: "DeveloperAgentToolOutput(summary, findingCount)",
            reason: "Reads bounded frontend files and compares them to loaded IDL/Project Brain metadata."
        ),
        WorkstationAgentTool(
            id: "frontend.generateDraft",
            displayName: "Generate Frontend Draft Preview",
            modeRequired: .suggest,
            readOnly: true,
            requiresTrustedProject: false,
            approvalRequired: false,
            evidencePolicy: .redactedSummary,
            inputSchema: "DeveloperAgentToolInput(draftKind, instructionName)",
            outputSchema: "DeveloperAgentToolOutput(summary, draftPreviews)",
            reason: "Produces preview-only draft files. File writes remain in Frontend Assistant behind explicit approval."
        )
    ]

    static let unsafeToolIDs: Set<String> = [
        "runShell",
        "sendTransaction",
        "deployMainnetProgram",
        "exportDeveloperWalletSecret",
        "requestAirdropMainnet",
        "rawTerminal",
        "arbitraryRPC",
        "signTransaction"
    ]

    static let blockedTools: [WorkstationAgentTool] = [
        WorkstationAgentTool(id: "runShell", title: "Run shell", access: .blocked, reason: "Raw shell execution is never available."),
        WorkstationAgentTool(id: "sendTransaction", title: "Send transaction", access: .blocked, reason: "Developer Workstation Agent cannot broadcast transactions."),
        WorkstationAgentTool(id: "deployMainnetProgram", title: "Deploy mainnet program", access: .blocked, reason: "Mainnet program writes remain locked."),
        WorkstationAgentTool(id: "exportDeveloperWalletSecret", title: "Export developer wallet secret", access: .blocked, reason: "Developer wallet secret material stays in secure storage."),
        WorkstationAgentTool(id: "arbitraryRPC", title: "Arbitrary RPC", access: .blocked, reason: "Only allowlisted RPC Playground methods are available."),
        WorkstationAgentTool(id: "rawTerminal", title: "Raw terminal", access: .blocked, reason: "There is no raw terminal input in Developer Workstation.")
    ]

    static let allowedTools: [WorkstationAgentTool] = toolDefinitions

    static func tool(id: String) -> WorkstationAgentTool? {
        let normalized = legacyAlias(for: id)
        return (toolDefinitions + blockedTools).first { $0.id == normalized }
    }

    static func canUseTool(id: String) -> Bool {
        guard let tool = tool(id: id) else { return false }
        return tool.access != .blocked
    }

    static func authorize(
        toolID: String,
        mode: DeveloperAgentMode,
        project: WorkstationProject?,
        cluster: WorkstationCluster
    ) -> DeveloperAgentAuthorization {
        guard let tool = tool(id: toolID) else {
            return DeveloperAgentAuthorization(allowed: false, approvalRequired: false, reasons: ["Unknown Developer Agent tool."])
        }
        if tool.access == .blocked {
            return DeveloperAgentAuthorization(allowed: false, approvalRequired: false, reasons: [tool.reason])
        }
        var reasons: [String] = []
        if mode < tool.modeRequired {
            reasons.append("\(tool.displayName) requires \(tool.modeRequired.title) mode.")
        }
        if tool.requiresTrustedProject && project?.trustStatus != .trusted {
            reasons.append("Project trust is required before this tool can run.")
        }
        if !tool.allowedClusters.isEmpty && !tool.allowedClusters.contains(cluster) {
            reasons.append("\(tool.displayName) is not allowed on \(cluster.title).")
        }
        if cluster == .mainnetBeta && !tool.readOnly {
            reasons.append("Mainnet write operations remain locked.")
        }
        return DeveloperAgentAuthorization(
            allowed: reasons.isEmpty,
            approvalRequired: tool.approvalRequired,
            reasons: reasons
        )
    }

    private static func legacyAlias(for id: String) -> String {
        switch id {
        case "summarizeProject":
            return "project.getBrain"
        case "inspectIDL":
            return "idl.list"
        case "reviewPDAHints":
            return "pda.derive"
        case "explainProgramEvidence":
            return "program.preflight"
        case "prepareProgramCommandPreview":
            return "program.preflight"
        default:
            return id
        }
    }
}
