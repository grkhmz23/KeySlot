import Foundation

typealias FixedCommandPreview = WorkstationCommandPlan

enum WorkstationTestFrameworkKind: String, Codable, CaseIterable, Identifiable {
    case anchor
    case cargo
    case nativeSolana
    case liteSVM
    case mollusk
    case trident

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anchor:
            return "Anchor tests"
        case .cargo:
            return "Cargo tests"
        case .nativeSolana:
            return "Native Solana"
        case .liteSVM:
            return "LiteSVM"
        case .mollusk:
            return "Mollusk"
        case .trident:
            return "Trident"
        }
    }
}

enum WorkstationTestRunSupport: String, Codable, Equatable {
    case supported
    case unsupported
    case blocked

    var title: String { rawValue.capitalized }
}

struct WorkstationDetectedTestFramework: Codable, Equatable, Identifiable {
    var id: WorkstationTestFrameworkKind { kind }

    let kind: WorkstationTestFrameworkKind
    let support: WorkstationTestRunSupport
    let commandDescription: String?
    let reason: String
    let evidence: [String]

    var canPrepareCommand: Bool {
        support == .supported
    }
}

struct WorkstationTestFile: Codable, Equatable, Identifiable {
    var id: String { relativePath }

    let relativePath: String
    let kind: String
    let modifiedAt: Date?
}

struct WorkstationMissingTestSuggestion: Codable, Equatable, Identifiable {
    let id: String
    let severity: ProjectBrainWarningSeverity
    let title: String
    let detail: String
    let suggestedDraftName: String?

    init(id: String, severity: ProjectBrainWarningSeverity, title: String, detail: String, suggestedDraftName: String?) {
        self.id = id
        self.severity = severity
        self.title = AgentSafetyRedactor.redact(title)
        self.detail = AgentSafetyRedactor.redact(detail)
        self.suggestedDraftName = suggestedDraftName.map(AgentSafetyRedactor.redact)
    }
}

enum WorkstationTestDraftMode: String, Codable, Equatable {
    case frameworkDraft = "framework_draft"
    case copyOnlyDraft = "copy_only_draft"

    var title: String {
        switch self {
        case .frameworkDraft:
            return "Framework draft"
        case .copyOnlyDraft:
            return "Copy-only draft"
        }
    }
}

struct WorkstationGeneratedTestDraft: Codable, Equatable, Identifiable {
    let id: UUID
    let projectID: UUID?
    let projectName: String
    let suggestionID: String
    let framework: WorkstationTestFrameworkKind?
    let mode: WorkstationTestDraftMode
    let fileName: String
    let safeRelativePath: String
    let contentPreview: String
    let createdAt: Date
    let isDraft: Bool

    init(
        id: UUID = UUID(),
        projectID: UUID?,
        projectName: String,
        suggestionID: String,
        framework: WorkstationTestFrameworkKind?,
        mode: WorkstationTestDraftMode,
        fileName: String,
        safeRelativePath: String,
        contentPreview: String,
        createdAt: Date = Date(),
        isDraft: Bool = true
    ) {
        self.id = id
        self.projectID = projectID
        self.projectName = WorkstationCommandRunner.safeSummary(projectName)
        self.suggestionID = WorkstationCommandRunner.safeSummary(suggestionID)
        self.framework = framework
        self.mode = mode
        self.fileName = WorkstationCommandRunner.safeSummary(fileName)
        self.safeRelativePath = WorkstationCommandRunner.safeSummary(safeRelativePath)
        self.contentPreview = WorkstationCommandRunner.safeSummary(contentPreview)
        self.createdAt = createdAt
        self.isDraft = isDraft
    }
}

struct TestFrameworkDetection: Codable, Equatable {
    let projectID: UUID?
    let projectName: String
    let detectedAt: Date
    let frameworks: [WorkstationDetectedTestFramework]
    let testFiles: [WorkstationTestFile]
    let unsupported: [UnsupportedFinding]
    let warnings: [ProjectBrainWarning]

    static let empty = TestFrameworkDetection(
        projectID: nil,
        projectName: "No project",
        detectedAt: Date(timeIntervalSince1970: 0),
        frameworks: [],
        testFiles: [],
        unsupported: [UnsupportedFinding(id: "no-project", title: "No project selected", reason: "Import a project before test detection.")],
        warnings: []
    )
}

enum WorkstationTestRunStatus: String, Codable, Equatable {
    case succeeded
    case failed
    case blocked
    case timedOut = "timed_out"

    var title: String {
        switch self {
        case .succeeded:
            return "Succeeded"
        case .failed:
            return "Failed"
        case .blocked:
            return "Blocked"
        case .timedOut:
            return "Timed out"
        }
    }
}

struct TestRunEvidence: Codable, Equatable, Identifiable {
    let id: UUID
    let projectID: UUID?
    let projectName: String
    let framework: WorkstationTestFrameworkKind
    let commandSummary: String
    let status: WorkstationTestRunStatus
    let exitCode: Int32?
    let stdoutSummary: String
    let stderrSummary: String
    let startedAt: Date
    let completedAt: Date
    let computeMeasurements: [WorkstationComputeMeasurement]

    init(
        id: UUID = UUID(),
        projectID: UUID?,
        projectName: String,
        framework: WorkstationTestFrameworkKind,
        commandSummary: String,
        status: WorkstationTestRunStatus,
        exitCode: Int32?,
        stdoutSummary: String,
        stderrSummary: String,
        startedAt: Date = Date(),
        completedAt: Date = Date(),
        computeMeasurements: [WorkstationComputeMeasurement] = []
    ) {
        self.id = id
        self.projectID = projectID
        self.projectName = WorkstationCommandRunner.safeSummary(projectName)
        self.framework = framework
        self.commandSummary = WorkstationCommandRunner.safeSummary(commandSummary)
        self.status = status
        self.exitCode = exitCode
        self.stdoutSummary = WorkstationCommandRunner.safeSummary(stdoutSummary)
        self.stderrSummary = WorkstationCommandRunner.safeSummary(stderrSummary)
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.computeMeasurements = computeMeasurements
    }
}

enum WorkstationTestWorkbenchError: LocalizedError, Equatable {
    case missingProject
    case untrustedProject
    case missingTool(String)
    case unsupportedFramework(String)
    case unknownCommand
    case draftWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingProject:
            return "Import a project before preparing a test command."
        case .untrustedProject:
            return "Tests execute project code. Trust the project before preparing or running tests."
        case .missingTool(let tool):
            return "\(tool) is required for this fixed test command."
        case .unsupportedFramework(let reason):
            return reason
        case .unknownCommand:
            return "Prepared test command expired or was not found."
        case .draftWriteFailed(let reason):
            return "Test draft could not be written: \(reason)"
        }
    }
}

final class TestWorkbenchService {
    static let approvalPhrase = "Run approved Developer Workstation test"
    static let executionRiskWarning = "Tests execute trusted local project code. Build scripts, test files, and project dependencies may run local code. Only continue if you trust this project and understand the command preview."

    private let fileManager: FileManager
    private let toolchainResolver: WorkstationToolchainResolver
    private let runner: WorkstationCommandRunner
    private var preparedCommands: [UUID: (framework: WorkstationTestFrameworkKind, project: WorkstationProject, plan: WorkstationCommandPlan)] = [:]

    init(
        fileManager: FileManager = .default,
        toolchainResolver: WorkstationToolchainResolver = WorkstationToolchainResolver(),
        runner: WorkstationCommandRunner = WorkstationCommandRunner(timeoutSeconds: 120)
    ) {
        self.fileManager = fileManager
        self.toolchainResolver = toolchainResolver
        self.runner = runner
    }

    func detectFrameworks(project: WorkstationProject?) async -> TestFrameworkDetection {
        guard let project else {
            return .empty
        }
        let root = URL(fileURLWithPath: project.localPath, isDirectory: true)
        let files = scanTestFiles(root: root)
        let cargoText = readBoundedText(root.appendingPathComponent("Cargo.toml"))
        let packageText = readBoundedText(root.appendingPathComponent("package.json"))
        let anchorTomlExists = fileManager.fileExists(atPath: root.appendingPathComponent("Anchor.toml").path)
        let cargoTomlExists = cargoText != nil
        var frameworks: [WorkstationDetectedTestFramework] = []

        if anchorTomlExists {
            let hasJSTests = files.contains { $0.relativePath.hasPrefix("tests/") && ["ts", "js"].contains(URL(fileURLWithPath: $0.relativePath).pathExtension.lowercased()) }
            frameworks.append(WorkstationDetectedTestFramework(
                kind: .anchor,
                support: hasJSTests ? .supported : .blocked,
                commandDescription: hasJSTests ? "anchor test --provider.cluster \(WorkstationCluster.localnet.rpcURL.absoluteString)" : nil,
                reason: hasJSTests ? "Anchor.toml and JavaScript/TypeScript tests detected." : "Anchor.toml detected, but no tests/*.ts or tests/*.js files were found.",
                evidence: ["Anchor.toml"] + files.filter { $0.relativePath.hasPrefix("tests/") }.map(\.relativePath)
            ))
        }

        if cargoTomlExists {
            frameworks.append(WorkstationDetectedTestFramework(
                kind: .cargo,
                support: .supported,
                commandDescription: "cargo test",
                reason: "Cargo.toml detected. Cargo tests can run through the fixed cargo test builder after trust and approval.",
                evidence: ["Cargo.toml"] + Array(files.filter { $0.relativePath.hasSuffix(".rs") }.map(\.relativePath).prefix(8))
            ))
        }

        if cargoText?.localizedCaseInsensitiveContains("solana-program") == true {
            frameworks.append(WorkstationDetectedTestFramework(
                kind: .nativeSolana,
                support: .supported,
                commandDescription: "cargo test",
                reason: "solana-program dependency detected. Native Solana test support maps to cargo test; build-sbf remains unsupported until a fixed reviewed builder is added.",
                evidence: ["Cargo.toml"]
            ))
        }

        frameworks.append(contentsOf: unsupportedFrameworks(cargoText: cargoText, packageText: packageText))

        let warnings: [ProjectBrainWarning] = files.isEmpty ? [
            ProjectBrainWarning(
                id: "no-test-files",
                severity: .warning,
                category: "Tests",
                title: "No test files detected",
                detail: "The project scan did not find tests, Rust test modules, or framework-specific test files.",
                suggestedAction: "Add tests before relying on localnet/devnet program evidence."
            )
        ] : []

        return TestFrameworkDetection(
            projectID: project.id,
            projectName: project.displayName,
            detectedAt: Date(),
            frameworks: frameworks,
            testFiles: files,
            unsupported: frameworks.filter { $0.support == .unsupported }.map {
                UnsupportedFinding(id: "unsupported-\($0.kind.rawValue)", title: "\($0.kind.title) detected", reason: $0.reason)
            },
            warnings: warnings
        )
    }

    func prepareTestCommand(framework: WorkstationTestFrameworkKind, project: WorkstationProject?) throws -> FixedCommandPreview {
        guard let project else {
            throw WorkstationTestWorkbenchError.missingProject
        }
        guard project.trustStatus == .trusted else {
            throw WorkstationTestWorkbenchError.untrustedProject
        }
        let plan: WorkstationCommandPlan
        switch framework {
        case .anchor:
            guard let anchorPath = toolchainResolver.resolve(.anchor).executablePath else {
                throw WorkstationTestWorkbenchError.missingTool("Anchor CLI")
            }
            plan = WorkstationCommandBuilders.anchorTest(anchorPath: anchorPath, projectPath: project.localPath)
        case .cargo, .nativeSolana:
            guard let cargoPath = toolchainResolver.resolve(.cargo).executablePath else {
                throw WorkstationTestWorkbenchError.missingTool("Cargo")
            }
            plan = WorkstationCommandBuilders.cargoTest(cargoPath: cargoPath, projectPath: project.localPath)
        case .liteSVM, .mollusk, .trident:
            throw WorkstationTestWorkbenchError.unsupportedFramework("\(framework.title) was detected, but no reviewed fixed command builder is available yet.")
        }
        try runner.validate(plan)
        preparedCommands[plan.id] = (framework, project, plan)
        return plan
    }

    func runApprovedTest(commandId: UUID) async throws -> TestRunEvidence {
        guard let prepared = preparedCommands[commandId] else {
            throw WorkstationTestWorkbenchError.unknownCommand
        }
        let startedAt = Date()
        let result = runner.run(prepared.plan)
        let combinedLogs = [result.stdoutSummary, result.stderrSummary]
        let compute = ComputeRegressionService.measurements(
            fromLogs: combinedLogs,
            projectID: prepared.project.id.uuidString,
            instructionName: "test-output",
            source: .testOutput,
            evidenceId: result.planName
        )
        return TestRunEvidence(
            projectID: prepared.project.id,
            projectName: prepared.project.displayName,
            framework: prepared.framework,
            commandSummary: prepared.plan.redactedPreview,
            status: Self.status(from: result.status),
            exitCode: result.exitCode,
            stdoutSummary: result.stdoutSummary,
            stderrSummary: result.stderrSummary,
            startedAt: startedAt,
            completedAt: result.completedAt,
            computeMeasurements: compute
        )
    }

    func generateDraft(
        for suggestion: WorkstationMissingTestSuggestion,
        project: WorkstationProject?,
        framework: WorkstationTestFrameworkKind?,
        draftsRoot: URL? = nil
    ) throws -> WorkstationGeneratedTestDraft {
        guard let project else {
            throw WorkstationTestWorkbenchError.missingProject
        }
        let root = draftsRoot ?? Self.defaultDraftRoot()
        let projectDirectory = root
            .appendingPathComponent(project.id.uuidString, isDirectory: true)
            .standardizedFileURL
        try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        let mode: WorkstationTestDraftMode
        let fileExtension: String
        switch framework {
        case .anchor:
            mode = .frameworkDraft
            fileExtension = "ts"
        case .cargo, .nativeSolana:
            mode = .frameworkDraft
            fileExtension = "rs"
        default:
            mode = .copyOnlyDraft
            fileExtension = "md"
        }

        let fileName = "\(safeSlug(suggestion.suggestedDraftName ?? suggestion.title))-\(UUID().uuidString.prefix(8)).\(fileExtension)"
        let fileURL = projectDirectory.appendingPathComponent(fileName, isDirectory: false)
        guard !fileManager.fileExists(atPath: fileURL.path) else {
            throw WorkstationTestWorkbenchError.draftWriteFailed("draft path already exists; no overwrite was attempted.")
        }

        let content = draftContent(for: suggestion, project: project, framework: framework, mode: mode)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return WorkstationGeneratedTestDraft(
            projectID: project.id,
            projectName: project.displayName,
            suggestionID: suggestion.id,
            framework: framework,
            mode: mode,
            fileName: fileName,
            safeRelativePath: "test-drafts/\(project.id.uuidString)/\(fileName)",
            contentPreview: String(content.prefix(600))
        )
    }

    static func suggestedMissingTests(from brain: DeveloperProjectBrain?) -> [WorkstationMissingTestSuggestion] {
        guard let brain else {
            return []
        }
        let testNames = Set(brain.testCandidates.map { normalized($0.relativePath) })
        var suggestions: [WorkstationMissingTestSuggestion] = []
        for instruction in brain.instructions {
            let normalizedInstruction = normalized(instruction.name)
            if !testNames.contains(where: { $0.contains(normalizedInstruction) }) {
                suggestions.append(WorkstationMissingTestSuggestion(
                    id: "missing-\(instruction.id)",
                    severity: .info,
                    title: "No obvious test for \(instruction.name)",
                    detail: "Project Brain did not find a test file name that clearly matches this instruction.",
                    suggestedDraftName: "\(instruction.name)_happy_path_test"
                ))
            }
            if !instruction.pdaHints.isEmpty && !testNames.contains(where: { $0.contains("invalidpda") || $0.contains("wrongpda") }) {
                suggestions.append(WorkstationMissingTestSuggestion(
                    id: "pda-\(instruction.id)",
                    severity: .warning,
                    title: "Missing invalid PDA negative test",
                    detail: "\(instruction.name) has PDA hints or constraints, but no obvious invalid PDA test was found.",
                    suggestedDraftName: "\(instruction.name)_invalid_pda_test"
                ))
            }
            if !instruction.signerAccounts.isEmpty && !testNames.contains(where: { $0.contains("invalidsigner") || $0.contains("missingsigner") }) {
                suggestions.append(WorkstationMissingTestSuggestion(
                    id: "signer-\(instruction.id)",
                    severity: .warning,
                    title: "Missing signer negative test",
                    detail: "\(instruction.name) expects signer accounts, but no obvious invalid signer test was found.",
                    suggestedDraftName: "\(instruction.name)_invalid_signer_test"
                ))
            }
            let tokenish = (instruction.accounts + instruction.anchorConstraints).joined(separator: " ").lowercased()
            if tokenish.contains("mint") || tokenish.contains("token") {
                if !testNames.contains(where: { $0.contains("wrongmint") || $0.contains("wrongowner") }) {
                    suggestions.append(WorkstationMissingTestSuggestion(
                        id: "token-\(instruction.id)",
                        severity: .warning,
                        title: "Missing token constraint negative test",
                        detail: "\(instruction.name) appears to touch token or mint constraints, but no wrong mint/owner test was found.",
                        suggestedDraftName: "\(instruction.name)_wrong_mint_or_owner_test"
                    ))
                }
            }
            let authorityish = normalizedInstruction
            if authorityish.contains("close") || authorityish.contains("revoke") || authorityish.contains("authority") {
                if !testNames.contains(where: { $0.contains("unauthorized") || $0.contains("negative") }) {
                    suggestions.append(WorkstationMissingTestSuggestion(
                        id: "authority-\(instruction.id)",
                        severity: .high,
                        title: "Missing destructive authority negative test",
                        detail: "\(instruction.name) looks authority-related. Add explicit unauthorized/negative coverage before release.",
                        suggestedDraftName: "\(instruction.name)_unauthorized_negative_test"
                    ))
                }
            }
        }
        var seen = Set<String>()
        return suggestions.filter { seen.insert($0.id).inserted }.prefix(40).map { $0 }
    }

    private static func status(from commandStatus: WorkstationCommandStatus) -> WorkstationTestRunStatus {
        switch commandStatus {
        case .succeeded:
            return .succeeded
        case .timedOut:
            return .timedOut
        case .blocked:
            return .blocked
        case .pending, .running, .failed:
            return .failed
        }
    }

    private func unsupportedFrameworks(cargoText: String?, packageText: String?) -> [WorkstationDetectedTestFramework] {
        var result: [WorkstationDetectedTestFramework] = []
        let combined = "\(cargoText ?? "")\n\(packageText ?? "")".lowercased()
        let candidates: [(WorkstationTestFrameworkKind, String)] = [
            (.liteSVM, "litesvm"),
            (.mollusk, "mollusk"),
            (.trident, "trident")
        ]
        for (kind, needle) in candidates where combined.contains(needle) {
            result.append(WorkstationDetectedTestFramework(
                kind: kind,
                support: .unsupported,
                commandDescription: nil,
                reason: "Detected only. Execution requires reviewed fixed command builders.",
                evidence: [needle]
            ))
        }
        return result
    }

    private func scanTestFiles(root: URL) -> [WorkstationTestFile] {
        guard root.path.hasPrefix("/"),
              let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
              ) else {
            return []
        }
        var files: [WorkstationTestFile] = []
        for case let url as URL in enumerator {
            if files.count >= 300 {
                break
            }
            let relative = DeveloperProjectBrainPath.cleanRelativePath(url.path.replacingOccurrences(of: root.path, with: ""))
            if shouldSkip(relative) {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey]),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true else {
                continue
            }
            let lower = relative.lowercased()
            let isTest = lower.hasPrefix("tests/")
                || lower.contains("/tests/")
                || lower.contains("_test.")
                || lower.contains(".test.")
                || lower.contains(".spec.")
                || lower.contains("#[cfg(test)]")
            if isTest || ["ts", "js", "rs"].contains(url.pathExtension.lowercased()) && lower.contains("test") {
                let fileKind = url.pathExtension.lowercased()
                files.append(WorkstationTestFile(relativePath: relative, kind: fileKind.isEmpty ? "file" : fileKind, modifiedAt: values.contentModificationDate))
            }
        }
        return files.sorted { $0.relativePath < $1.relativePath }
    }

    private func shouldSkip(_ relative: String) -> Bool {
        let lower = relative.lowercased()
        return lower.hasPrefix("target/")
            || lower.hasPrefix("node_modules/")
            || lower.hasPrefix(".git/")
            || lower.contains("/target/")
            || lower.contains("/node_modules/")
    }

    private func readBoundedText(_ url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true,
              (values.fileSize ?? 0) <= 512_000,
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func defaultDraftRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("KeySlot", isDirectory: true)
            .appendingPathComponent("DeveloperWorkstation", isDirectory: true)
            .appendingPathComponent("test-drafts", isDirectory: true)
    }

    private func draftContent(
        for suggestion: WorkstationMissingTestSuggestion,
        project: WorkstationProject,
        framework: WorkstationTestFrameworkKind?,
        mode: WorkstationTestDraftMode
    ) -> String {
        let title = WorkstationCommandRunner.safeSummary(suggestion.title)
        let detail = WorkstationCommandRunner.safeSummary(suggestion.detail)
        let projectName = WorkstationCommandRunner.safeSummary(project.displayName)
        switch (mode, framework) {
        case (.frameworkDraft, .anchor):
            return """
            // DRAFT generated by KeySlot Developer Workstation.
            // Stored outside the project. Not executed automatically.
            // Project: \(projectName)
            // Suggested coverage: \(title)
            // Reason: \(detail)

            describe("\(safeStringLiteral(title))", () => {
              it("covers the missing behavior", async () => {
                // TODO: copy into a reviewed test suite and replace with real Anchor test setup.
              });
            });

            """
        case (.frameworkDraft, .cargo), (.frameworkDraft, .nativeSolana):
            return """
            // DRAFT generated by KeySlot Developer Workstation.
            // Stored outside the project. Not executed automatically.
            // Project: \(projectName)
            // Suggested coverage: \(title)
            // Reason: \(detail)

            #[test]
            fn \(safeRustIdentifier(title))() {
                // TODO: copy into a reviewed Rust test module and replace with real assertions.
            }

            """
        default:
            return """
            # KeySlot Developer Workstation Test Draft

            Draft only. Stored outside the project and not executed automatically.

            Project: \(projectName)
            Suggested coverage: \(title)
            Reason: \(detail)

            Use this as a copy-only checklist because no reviewed fixed command builder is available for the selected framework.

            """
        }
    }

    private func safeSlug(_ value: String) -> String {
        let lower = WorkstationCommandRunner.safeSummary(value).lowercased()
        let allowed = lower.map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        let collapsed = String(allowed).split(separator: "-").joined(separator: "-")
        return collapsed.isEmpty ? "test-draft" : String(collapsed.prefix(48))
    }

    private func safeRustIdentifier(_ value: String) -> String {
        let slug = safeSlug(value).replacingOccurrences(of: "-", with: "_")
        guard let first = slug.first, first.isLetter || first == "_" else {
            return "draft_\(slug)"
        }
        return slug
    }

    private func safeStringLiteral(_ value: String) -> String {
        WorkstationCommandRunner.safeSummary(value)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

final class TestRunEvidenceStore {
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

    func load() -> [TestRunEvidence] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        return (try? decoder.decode([TestRunEvidence].self, from: data)) ?? []
    }

    func append(_ evidence: TestRunEvidence) throws -> [TestRunEvidence] {
        var entries = load()
        entries.insert(evidence, at: 0)
        entries = Array(entries.prefix(100))
        try save(entries)
        return entries
    }

    func save(_ entries: [TestRunEvidence]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(entries).write(to: fileURL, options: [.atomic])
    }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("KeySlot", isDirectory: true)
            .appendingPathComponent("DeveloperWorkstation", isDirectory: true)
            .appendingPathComponent("test-run-evidence.json")
    }
}
