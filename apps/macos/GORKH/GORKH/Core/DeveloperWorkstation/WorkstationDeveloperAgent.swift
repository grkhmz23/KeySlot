import Foundation

enum DeveloperAgentToolCallStatus: String, Codable, Equatable, CaseIterable, Identifiable {
    case succeeded
    case blocked
    case approvalRequired = "approval_required"
    case unavailable
    case delegated

    var id: String { rawValue }

    var title: String {
        switch self {
        case .succeeded:
            return "Succeeded"
        case .blocked:
            return "Blocked"
        case .approvalRequired:
            return "Approval required"
        case .unavailable:
            return "Unavailable"
        case .delegated:
            return "Delegated"
        }
    }
}

struct DeveloperAgentToolInput: Codable, Equatable {
    var prompt: String?
    var signature: String?
    var programID: String?
    var expectedAddress: String?
    var accountAddress: String?
    var accountDataBase64: String?
    var idlAccountName: String?
    var seedInputs: [WorkstationPDASeedInput]
    var logs: [String]
    var rpcMethod: String?
    var encodedTransaction: String?
    var operation: WorkstationProgramOperation?
    var artifactPath: String?
    var newAuthority: String?
    var testFramework: WorkstationTestFrameworkKind?
    var instructionName: String?
    var frontendDraftKind: FrontendGeneratedFileKind?
    var approvalPhrase: String?

    static let empty = DeveloperAgentToolInput(
        prompt: nil,
        signature: nil,
        programID: nil,
        expectedAddress: nil,
        accountAddress: nil,
        accountDataBase64: nil,
        idlAccountName: nil,
        seedInputs: [],
        logs: [],
        rpcMethod: nil,
        encodedTransaction: nil,
        operation: nil,
        artifactPath: nil,
        newAuthority: nil,
        testFramework: nil,
        instructionName: nil,
        frontendDraftKind: nil,
        approvalPhrase: nil
    )

    var safeSummary: String {
        let pieces = [
            prompt.map { "prompt=\(Self.short($0))" },
            signature.map { "signature=\(Self.short($0))" },
            programID.map { "program=\(Self.short($0))" },
            accountAddress.map { "account=\(Self.short($0))" },
            rpcMethod.map { "rpc=\(Self.short($0))" },
            operation.map { "operation=\($0.title)" },
            testFramework.map { "test=\($0.title)" },
            instructionName.map { "instruction=\(Self.short($0))" },
            frontendDraftKind.map { "draft=\($0.title)" },
            seedInputs.isEmpty ? nil : "seeds=\(seedInputs.count)",
            logs.isEmpty ? nil : "logs=\(logs.count)"
        ].compactMap { $0 }
        return WorkstationCommandRunner.safeSummary(pieces.isEmpty ? "empty input" : pieces.joined(separator: ", "))
    }

    private static func short(_ value: String) -> String {
        let clean = WorkstationCommandRunner.safeSummary(value)
        return clean.count > 80 ? String(clean.prefix(80)) + "..." : clean
    }
}

struct DeveloperAgentToolOutput: Codable, Equatable {
    let summary: String
    let details: [String: String]
    let safeJSONPreview: String?
    let requiresApproval: Bool
    let evidenceID: String?

    init(
        summary: String,
        details: [String: String] = [:],
        safeJSONPreview: String? = nil,
        requiresApproval: Bool = false,
        evidenceID: String? = nil
    ) {
        self.summary = WorkstationCommandRunner.safeSummary(summary)
        self.details = Dictionary(uniqueKeysWithValues: details.map {
            (WorkstationCommandRunner.safeSummary($0.key), WorkstationCommandRunner.safeSummary($0.value))
        })
        self.safeJSONPreview = safeJSONPreview.map(WorkstationCommandRunner.safeSummary)
        self.requiresApproval = requiresApproval
        self.evidenceID = evidenceID.map(WorkstationCommandRunner.safeSummary)
    }
}

struct DeveloperAgentToolContext {
    let project: WorkstationProject?
    let cluster: WorkstationCluster
    let idl: WorkstationIDL?
    let projectBrain: DeveloperProjectBrain?
    let transactionDebugReport: TransactionDebugReport?
    let localValidatorStatus: WorkstationLocalValidatorStatus
    let toolchain: WorkstationToolchainSnapshot
    let programEvidence: [WorkstationProgramOperationEvidence]
    let releaseRecords: [WorkstationDeploymentReleaseRecord]
    let securityReport: SecurityScanReport?
    let frontendReport: FrontendAssistantReport?
    let developerWallet: DeveloperWalletMetadata?
}

struct DeveloperAgentToolCallRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let toolID: String
    let toolName: String
    let mode: DeveloperAgentMode
    let status: DeveloperAgentToolCallStatus
    let inputSummary: String
    let outputSummary: String
    let blockReason: String?
    let approvalRequired: Bool
    let evidencePolicy: DeveloperAgentEvidencePolicy
    let createdAt: Date

    init(
        id: UUID = UUID(),
        tool: WorkstationAgentTool,
        mode: DeveloperAgentMode,
        status: DeveloperAgentToolCallStatus,
        inputSummary: String,
        output: DeveloperAgentToolOutput,
        blockReason: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.toolID = WorkstationCommandRunner.safeSummary(tool.id)
        self.toolName = WorkstationCommandRunner.safeSummary(tool.displayName)
        self.mode = mode
        self.status = status
        self.inputSummary = WorkstationCommandRunner.safeSummary(inputSummary)
        self.outputSummary = WorkstationCommandRunner.safeSummary(output.summary)
        self.blockReason = blockReason.map(WorkstationCommandRunner.safeSummary)
        self.approvalRequired = output.requiresApproval
        self.evidencePolicy = tool.evidencePolicy
        self.createdAt = createdAt
    }
}

final class DeveloperAgentToolHistoryStore {
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

    func load() -> [DeveloperAgentToolCallRecord] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        return (try? decoder.decode([DeveloperAgentToolCallRecord].self, from: data)) ?? []
    }

    func append(_ record: DeveloperAgentToolCallRecord) throws -> [DeveloperAgentToolCallRecord] {
        var records = load()
        records.insert(record, at: 0)
        records = Array(records.prefix(120))
        try save(records)
        return records
    }

    func save(_ records: [DeveloperAgentToolCallRecord]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(records).write(to: fileURL, options: [.atomic])
    }

    func exportJSON(_ records: [DeveloperAgentToolCallRecord]) throws -> String {
        let data = try encoder.encode(records)
        return WorkstationCommandRunner.safeSummary(String(data: data, encoding: .utf8) ?? "[]")
    }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("KeySlot", isDirectory: true)
            .appendingPathComponent("DeveloperWorkstation", isDirectory: true)
            .appendingPathComponent("developer-agent-tool-history.json")
    }
}

enum DeveloperWorkstationAgentService {
    static let approvalPhrase = "Approve Developer Agent tool call"

    static func execute(
        toolID: String,
        mode: DeveloperAgentMode,
        input: DeveloperAgentToolInput,
        context: DeveloperAgentToolContext
    ) async -> DeveloperAgentToolCallRecord {
        guard let tool = DeveloperAgentToolRegistry.tool(id: toolID) else {
            let fallback = WorkstationAgentTool(id: "unknown", title: "Unknown tool", access: .blocked, reason: "Unknown Developer Agent tool.")
            return record(
                tool: fallback,
                mode: mode,
                status: .blocked,
                input: input,
                output: DeveloperAgentToolOutput(summary: "Unknown Developer Agent tool."),
                blockReason: "Unknown Developer Agent tool."
            )
        }

        let authorization = DeveloperAgentToolRegistry.authorize(
            toolID: toolID,
            mode: mode,
            project: context.project,
            cluster: context.cluster
        )
        guard authorization.allowed else {
            let reason = authorization.reasons.joined(separator: " ")
            return record(
                tool: tool,
                mode: mode,
                status: .blocked,
                input: input,
                output: DeveloperAgentToolOutput(summary: reason.isEmpty ? "Tool call blocked." : reason),
                blockReason: reason
            )
        }

        if authorization.approvalRequired && input.approvalPhrase != approvalPhrase {
            return record(
                tool: tool,
                mode: mode,
                status: .approvalRequired,
                input: input,
                output: DeveloperAgentToolOutput(
                    summary: "\(tool.displayName) requires explicit approval before using the existing safe flow.",
                    details: ["requiredApproval": approvalPhrase],
                    requiresApproval: true
                )
            )
        }

        do {
            let output = try await executeAuthorized(tool: tool, input: input, context: context)
            let status: DeveloperAgentToolCallStatus = authorization.approvalRequired ? .delegated : .succeeded
            return record(tool: tool, mode: mode, status: status, input: input, output: output)
        } catch {
            return record(
                tool: tool,
                mode: mode,
                status: .unavailable,
                input: input,
                output: DeveloperAgentToolOutput(summary: error.localizedDescription),
                blockReason: error.localizedDescription
            )
        }
    }

    private static func executeAuthorized(
        tool: WorkstationAgentTool,
        input: DeveloperAgentToolInput,
        context: DeveloperAgentToolContext
    ) async throws -> DeveloperAgentToolOutput {
        switch tool.id {
        case "project.scanBrain":
            guard let project = context.project else {
                return unavailable("Import a project before scanning Project Brain.")
            }
            let brain = try await DeveloperProjectBrainService.scan(project: project)
            return output(
                "Project Brain scanned \(brain.programs.count) program(s), \(brain.instructions.count) instruction(s), and \(brain.pdaCandidates.count) PDA candidate(s).",
                details: [
                    "project": brain.projectName,
                    "type": brain.projectType.title,
                    "warnings": "\(brain.warnings.count)"
                ],
                preview: brain
            )

        case "project.getBrain":
            guard let brain = context.projectBrain else {
                return unavailable("No Project Brain report is loaded.")
            }
            return output(
                "Loaded Project Brain for \(brain.projectName): \(brain.programs.count) program(s), \(brain.idls.count) IDL(s), \(brain.warnings.count) warning(s).",
                details: [
                    "projectType": brain.projectType.title,
                    "trust": brain.trustStatus.title,
                    "confidence": brain.confidence.title
                ],
                preview: ProjectBrainAgentPreview(brain)
            )

        case "idl.list":
            guard let idl = context.idl else {
                return unavailable("No IDL is loaded.")
            }
            return output(
                "Loaded IDL \(idl.name): \(idl.summary), \(idl.errors.count) error(s), \(idl.events.count) event(s).",
                details: [
                    "program": idl.name,
                    "address": idl.address ?? "Unavailable",
                    "instructions": idl.instructions.map(\.name).prefix(12).joined(separator: ", ")
                ],
                preview: IDLAgentPreview(idl)
            )

        case "idl.diff":
            let summary = WorkstationIDLDriftService.summarize(
                idl: context.idl,
                selectedProgramID: clean(input.programID),
                evidence: context.programEvidence
            )
            return output(
                summary.message,
                details: [
                    "status": summary.status.title,
                    "idlAddress": summary.idlAddress ?? "Unavailable",
                    "selectedProgram": summary.selectedProgramID ?? "Unavailable"
                ],
                preview: summary
            )

        case "account.decode":
            let idlAccount = clean(input.idlAccountName).flatMap { name in
                context.idl?.accounts.first { $0.name == name }
            }
            let result = WorkstationAccountDecoder.decode(
                WorkstationAccountDecodeRequest(
                    address: clean(input.accountAddress) ?? "manual-fixture",
                    ownerProgram: nil,
                    lamports: nil,
                    dataBase64: clean(input.accountDataBase64),
                    idlAccount: idlAccount,
                    idl: context.idl
                )
            )
            return output(
                result.message,
                details: [
                    "status": result.status.title,
                    "dataLength": "\(result.dataLength)",
                    "fields": "\(result.fields.count)"
                ]
            )

        case "pda.derive":
            let programID = clean(input.programID) ?? context.idl?.address ?? ""
            guard !programID.isEmpty else {
                return unavailable("Enter a program id or load an IDL with an address before deriving a PDA.")
            }
            guard !input.seedInputs.isEmpty else {
                return unavailable("Enter at least one PDA seed before deriving.")
            }
            let result = PDAService().derive(
                WorkstationPDADerivationRequest(
                    programID: programID,
                    seeds: input.seedInputs,
                    expectedAddress: clean(input.expectedAddress)
                )
            )
            return output(
                result.message,
                details: [
                    "status": result.status.rawValue,
                    "address": result.derivedAddress ?? "Unavailable",
                    "bump": result.bump.map(String.init) ?? "Unavailable",
                    "seeds": result.seedSummary
                ],
                preview: result
            )

        case "transaction.debug":
            guard let signature = clean(input.signature), !signature.isEmpty else {
                return unavailable("Enter a transaction signature before debugging.")
            }
            let report = try await TransactionDebugService().debugTransaction(
                signature: signature,
                cluster: context.cluster,
                projectId: context.project?.id.uuidString,
                idlId: context.idl?.id,
                projectBrain: context.projectBrain,
                idl: context.idl
            )
            return output(
                "Transaction Debugger returned \(report.status.title): \(report.likelyRootCause)",
                details: [
                    "cluster": report.cluster.title,
                    "programs": "\(report.programIds.count)",
                    "logs": "\(report.logs.count)",
                    "computeUnits": report.computeUnits.map(String.init) ?? "Unavailable"
                ],
                preview: TransactionDebugAgentPreview(report),
                evidenceID: report.evidenceId.uuidString
            )

        case "logs.parse":
            let logs = input.logs.isEmpty ? input.prompt.map { [$0] } ?? [] : input.logs
            guard !logs.isEmpty else {
                return unavailable("Provide logs or paste log text in the prompt field.")
            }
            let analysis = TransactionLogParser.parse(logs: logs, idlErrors: context.idl?.errors ?? [])
            return output(
                analysis.likelyRootCause,
                details: [
                    "totalLines": "\(analysis.summary.totalLines)",
                    "errorLines": "\(analysis.summary.errorLineCount)",
                    "computeLines": "\(analysis.summary.computeLineCount)",
                    "computeUnits": analysis.computeUnits.map(String.init) ?? "Unavailable"
                ]
            )

        case "rpc.safeRead":
            guard let methodName = clean(input.rpcMethod),
                  let method = WorkstationRPCMethod.allCases.first(where: { $0.title == methodName || $0.rawValue == methodName }) else {
                return unavailable("Select an allowlisted RPC method before validation.")
            }
            let request = WorkstationRPCPlaygroundRequest(
                method: method,
                cluster: context.cluster,
                address: clean(input.accountAddress),
                signature: clean(input.signature),
                encodedTransaction: clean(input.encodedTransaction),
                amountSOL: nil
            )
            let permission = WorkstationRPCPlaygroundService.validate(request)
            return output(
                permission.message,
                details: [
                    "method": method.title,
                    "cluster": context.cluster.title,
                    "allowed": permission.isAllowed ? "Yes" : "No"
                ]
            )

        case "localnet.status":
            return output(
                context.localValidatorStatus.message,
                details: [
                    "state": context.localValidatorStatus.state.title,
                    "health": context.localValidatorStatus.health ?? "Unavailable",
                    "slot": context.localValidatorStatus.slot.map(String.init) ?? "Unavailable",
                    "startedByKeySlot": context.localValidatorStatus.startedByKeySlot ? "Yes" : "No"
                ],
                preview: context.localValidatorStatus
            )

        case "localnet.startExistingSafeFlow":
            return delegated("Approval accepted. Open Localnet to run the existing fixed local-validator start flow. Developer Agent did not start a process.")

        case "test.detect":
            let detection = await TestWorkbenchService().detectFrameworks(project: context.project)
            return output(
                "Detected \(detection.frameworks.count) test framework candidate(s) and \(detection.testFiles.count) test file(s).",
                details: [
                    "project": detection.projectName,
                    "frameworks": detection.frameworks.map { $0.kind.title }.joined(separator: ", ")
                ],
                preview: TestDetectionAgentPreview(detection)
            )

        case "test.runExistingSafeFlow":
            return delegated("Approval accepted. Open Test Workbench to review the fixed command preview and run the approved test flow. Developer Agent did not execute project code.")

        case "compute.record":
            let logs = input.logs.isEmpty ? input.prompt.map { [$0] } ?? [] : input.logs
            guard !logs.isEmpty else {
                return unavailable("Provide real logs before recording compute measurements.")
            }
            let measurements = ComputeRegressionService.measurements(
                fromLogs: logs,
                projectID: context.project?.id.uuidString,
                instructionName: clean(input.instructionName) ?? "agent-log",
                source: .transactionDebugger,
                signature: clean(input.signature)
            )
            return output(
                "Parsed \(measurements.count) compute measurement(s) from provided logs.",
                details: [
                    "instruction": clean(input.instructionName) ?? "agent-log",
                    "measurements": "\(measurements.count)"
                ],
                preview: measurements
            )

        case "program.preflight":
            let decision = WorkstationProgramManager.evaluate(programOperationRequest(input: input, context: context))
            return output(
                decision.isAllowed ? "Program operation preflight passed." : "Program operation preflight is blocked.",
                details: [
                    "operation": (input.operation ?? .solanaProgramShow).title,
                    "cluster": context.cluster.title,
                    "reasons": decision.reasons.joined(separator: " ")
                ]
            )

        case "program.deployExistingSafeFlow":
            return delegated("Approval accepted. Open Program Manager to use the existing localnet/devnet command preview and approval gates. Developer Agent did not deploy.")

        case "security.scan":
            let report = try SecurityScannerService.scan(
                project: context.project,
                projectBrain: context.projectBrain,
                idl: context.idl,
                releaseRecords: context.releaseRecords
            )
            return output(
                report.summary,
                details: [
                    "findings": "\(report.findings.count)",
                    "files": "\(report.scannedFileCount)",
                    "readOnly": report.readOnly ? "Yes" : "No"
                ],
                preview: SecurityAgentPreview(report)
            )

        case "frontend.inspect":
            let report = try FrontendIntegrationService.inspect(
                project: context.project,
                projectBrain: context.projectBrain,
                idl: context.idl
            )
            return output(
                report.summary,
                details: [
                    "status": report.status.title,
                    "findings": "\(report.findings.count)",
                    "draftableInstructions": "\(report.draftableInstructions.count)"
                ],
                preview: FrontendAgentPreview(report)
            )

        case "frontend.generateDraft":
            let drafts = try FrontendIntegrationService.prepareDrafts(
                kind: input.frontendDraftKind ?? .programConstants,
                instructionName: clean(input.instructionName),
                project: context.project,
                projectBrain: context.projectBrain,
                idl: context.idl,
                report: context.frontendReport
            )
            return output(
                "Generated \(drafts.count) frontend draft preview(s). No files were written.",
                details: [
                    "kind": (input.frontendDraftKind ?? .programConstants).title,
                    "instruction": clean(input.instructionName) ?? "Not instruction-specific"
                ],
                preview: drafts.map { DraftAgentPreview($0) }
            )

        default:
            return unavailable("This Developer Agent tool is registered but not implemented yet.")
        }
    }

    private static func programOperationRequest(
        input: DeveloperAgentToolInput,
        context: DeveloperAgentToolContext
    ) -> WorkstationProgramOperationRequest {
        WorkstationProgramOperationRequest(
            operation: input.operation ?? .solanaProgramShow,
            cluster: context.cluster,
            project: context.project,
            toolchain: context.toolchain,
            developerWallet: context.developerWallet,
            artifactPath: clean(input.artifactPath),
            programID: clean(input.programID),
            newAuthority: clean(input.newAuthority),
            exactPhrase: clean(input.approvalPhrase)
        )
    }

    private static func unavailable(_ summary: String) -> DeveloperAgentToolOutput {
        DeveloperAgentToolOutput(summary: summary)
    }

    private static func delegated(_ summary: String) -> DeveloperAgentToolOutput {
        DeveloperAgentToolOutput(summary: summary, requiresApproval: false)
    }

    private static func output<T: Encodable>(
        _ summary: String,
        details: [String: String] = [:],
        preview: T,
        evidenceID: String? = nil
    ) -> DeveloperAgentToolOutput {
        DeveloperAgentToolOutput(
            summary: summary,
            details: details,
            safeJSONPreview: safePreview(preview),
            evidenceID: evidenceID
        )
    }

    private static func output(
        _ summary: String,
        details: [String: String] = [:],
        evidenceID: String? = nil
    ) -> DeveloperAgentToolOutput {
        DeveloperAgentToolOutput(summary: summary, details: details, evidenceID: evidenceID)
    }

    private static func record(
        tool: WorkstationAgentTool,
        mode: DeveloperAgentMode,
        status: DeveloperAgentToolCallStatus,
        input: DeveloperAgentToolInput,
        output: DeveloperAgentToolOutput,
        blockReason: String? = nil
    ) -> DeveloperAgentToolCallRecord {
        DeveloperAgentToolCallRecord(
            tool: tool,
            mode: mode,
            status: status,
            inputSummary: input.safeSummary,
            output: output,
            blockReason: blockReason
        )
    }

    private static func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return WorkstationCommandRunner.safeSummary(trimmed)
    }

    private static func safePreview<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return WorkstationCommandRunner.safeSummary(String(text.prefix(4_000)))
    }
}

private struct ProjectBrainAgentPreview: Codable {
    let project: String
    let projectType: String
    let programs: Int
    let idls: Int
    let instructions: Int
    let accounts: Int
    let pdaCandidates: Int
    let warnings: Int

    init(_ brain: DeveloperProjectBrain) {
        project = brain.projectName
        projectType = brain.projectType.title
        programs = brain.programs.count
        idls = brain.idls.count
        instructions = brain.instructions.count
        accounts = brain.accounts.count
        pdaCandidates = brain.pdaCandidates.count
        warnings = brain.warnings.count
    }
}

private struct IDLAgentPreview: Codable {
    let name: String
    let address: String?
    let instructions: [String]
    let accounts: [String]
    let errors: [String]

    init(_ idl: WorkstationIDL) {
        name = idl.name
        address = idl.address
        instructions = Array(idl.instructions.map(\.name).prefix(25))
        accounts = Array(idl.accounts.map(\.name).prefix(25))
        errors = Array(idl.errors.map { "\($0.code):\($0.name)" }.prefix(25))
    }
}

private struct TransactionDebugAgentPreview: Codable {
    let status: String
    let slot: UInt64?
    let fee: UInt64?
    let programCount: Int
    let logCount: Int
    let computeUnits: UInt64?
    let rootCause: String

    init(_ report: TransactionDebugReport) {
        status = report.status.title
        slot = report.slot
        fee = report.fee
        programCount = report.programIds.count
        logCount = report.logs.count
        computeUnits = report.computeUnits
        rootCause = report.likelyRootCause
    }
}

private struct TestDetectionAgentPreview: Codable {
    let projectName: String
    let frameworks: [String]
    let testFiles: Int
    let warnings: Int

    init(_ detection: TestFrameworkDetection) {
        projectName = detection.projectName
        frameworks = detection.frameworks.map { "\($0.kind.title): \($0.support.title)" }
        testFiles = detection.testFiles.count
        warnings = detection.warnings.count
    }
}

private struct SecurityAgentPreview: Codable {
    let status: String
    let findingCount: Int
    let highCount: Int
    let mediumCount: Int

    init(_ report: SecurityScanReport) {
        status = report.readOnly ? "Read-only" : "Unexpected writable report"
        findingCount = report.findings.count
        highCount = report.findings.filter { $0.severity == .high }.count
        mediumCount = report.findings.filter { $0.severity == .medium }.count
    }
}

private struct FrontendAgentPreview: Codable {
    let status: String
    let findingCount: Int
    let draftableInstructions: [String]

    init(_ report: FrontendAssistantReport) {
        status = report.status.title
        findingCount = report.findings.count
        draftableInstructions = Array(report.draftableInstructions.prefix(20))
    }
}

private struct DraftAgentPreview: Codable {
    let kind: String
    let relativePath: String
    let dependencyStyle: String
    let warning: String?

    init(_ draft: FrontendGeneratedFileDraft) {
        kind = draft.kind.title
        relativePath = draft.relativePath
        dependencyStyle = draft.dependencyStyle
        warning = draft.warning
    }
}
