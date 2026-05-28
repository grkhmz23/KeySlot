import Foundation

enum DeveloperProjectBrainScanError: LocalizedError, Equatable {
    case unsupportedSource(String)
    case missingProjectRoot
    case unsafeProjectRoot

    var errorDescription: String? {
        switch self {
        case .unsupportedSource(let source):
            return "Project Brain requires a local folder. \(source) imports expose metadata only until extracted safely."
        case .missingProjectRoot:
            return "Project root does not exist."
        case .unsafeProjectRoot:
            return "Project root failed path safety validation."
        }
    }
}

extension DeveloperProjectBrainService {
    static func scan(project: WorkstationProject) async throws -> DeveloperProjectBrain {
        try DeveloperProjectBrainScanner(project: project).scan()
    }
}

final class DeveloperProjectBrainStore {
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

    func load() -> [DeveloperProjectBrain] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        return (try? decoder.decode([DeveloperProjectBrain].self, from: data)) ?? []
    }

    func append(_ report: DeveloperProjectBrain) throws -> [DeveloperProjectBrain] {
        var reports = load()
        reports.removeAll { $0.projectId == report.projectId }
        reports.insert(report, at: 0)
        reports = Array(reports.prefix(25))
        try save(reports)
        return reports
    }

    func save(_ reports: [DeveloperProjectBrain]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(reports).write(to: fileURL, options: [.atomic])
    }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("KeySlot", isDirectory: true)
            .appendingPathComponent("DeveloperWorkstation", isDirectory: true)
            .appendingPathComponent("project-brain-evidence.json")
    }
}

private struct DeveloperProjectBrainScanner {
    private struct FileRecord {
        let url: URL
        let relativePath: String
        let kind: String
        let byteCount: Int
        let modifiedAt: Date?
    }

    private let project: WorkstationProject
    private let fileManager: FileManager
    private let maxFiles = 800
    private let maxFileBytes = 512 * 1024

    init(project: WorkstationProject, fileManager: FileManager = .default) {
        self.project = project
        self.fileManager = fileManager
    }

    func scan() throws -> DeveloperProjectBrain {
        guard project.sourceType == .folder || project.sourceType == .gitHTTPS else {
            throw DeveloperProjectBrainScanError.unsupportedSource(project.sourceType.rawValue)
        }

        let root = URL(fileURLWithPath: project.localPath, isDirectory: true).standardizedFileURL
        guard isSafeRoot(root.path) else {
            throw DeveloperProjectBrainScanError.unsafeProjectRoot
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw DeveloperProjectBrainScanError.missingProjectRoot
        }

        let files = collectFiles(root: root)
        var warnings: [ProjectBrainWarning] = []
        var unsupported: [UnsupportedFinding] = []
        var toolchainHints: [ToolchainHint] = []
        var anchorToml = AnchorTomlSummary()
        var cargoSummaries: [(path: String, summary: CargoTomlSummary)] = []
        var packageSummaries: [(path: String, summary: PackageJsonSummary)] = []
        var rustSummaries: [AnchorRustSourceSummary] = []
        var parsedIDLs: [(idl: WorkstationIDL, brain: IDLBrain)] = []
        var deployArtifacts: [String] = []
        var clientCandidates: [ClientCandidate] = []
        var testCandidates: [TestCandidate] = []
        var frontendCandidates: [FrontendCandidate] = []

        for file in files {
            guard file.byteCount <= maxFileBytes else {
                unsupported.append(UnsupportedFinding(
                    id: "file-too-large-\(file.relativePath)",
                    title: "File skipped because it exceeds Project Brain scan limits.",
                    reason: "The file is \(file.byteCount) bytes. Project Brain reads files up to \(maxFileBytes) bytes.",
                    sourceRelativePath: file.relativePath
                ))
                continue
            }

            switch file.kind {
            case "Anchor.toml":
                if let text = readText(file.url) {
                    anchorToml = AnchorTomlScanner.parse(text)
                    toolchainHints.append(ToolchainHint(
                        component: "Anchor",
                        source: file.relativePath,
                        versionOrRequirement: anchorToml.providerCluster,
                        detail: "Anchor workspace metadata detected. Scripts are recorded as text only and never executed."
                    ))
                }
            case "Cargo.toml":
                if let text = readText(file.url) {
                    let summary = CargoTomlScanner.parse(text)
                    cargoSummaries.append((file.relativePath, summary))
                    for dependency in summary.relevantDependencies {
                        toolchainHints.append(ToolchainHint(
                            component: dependency,
                            source: file.relativePath,
                            versionOrRequirement: nil,
                            detail: "Relevant Solana Rust dependency detected."
                        ))
                    }
                }
            case "package.json":
                if let data = try? Data(contentsOf: file.url) {
                    let summary = PackageJsonScanner.parse(data)
                    packageSummaries.append((file.relativePath, summary))
                    for hint in summary.frameworkHints {
                        toolchainHints.append(ToolchainHint(
                            component: hint,
                            source: file.relativePath,
                            versionOrRequirement: nil,
                            detail: "Dependency metadata detected. Scripts are recorded as names only and never executed."
                        ))
                    }
                }
            case "Rust source":
                if let text = readText(file.url) {
                    rustSummaries.append(AnchorRustSourceScanner.scan(relativePath: file.relativePath, text: text))
                }
            case "Anchor IDL":
                do {
                    let data = try Data(contentsOf: file.url)
                    parsedIDLs.append(try AnchorIDLParser.parseBrain(relativePath: file.relativePath, data: data, modifiedAt: file.modifiedAt))
                } catch {
                    warnings.append(ProjectBrainWarning(
                        id: "idl-parse-\(file.relativePath)",
                        severity: .warning,
                        category: "IDL",
                        title: "IDL could not be parsed",
                        detail: error.localizedDescription,
                        sourceRelativePath: file.relativePath,
                        suggestedAction: "Open the file in IDL Browser and validate that it is an Anchor IDL JSON file."
                    ))
                }
            case "Deploy artifact":
                deployArtifacts.append(file.relativePath)
            case "Client source":
                clientCandidates.append(ClientCandidate(
                    id: file.relativePath,
                    relativePath: file.relativePath,
                    framework: clientFrameworkHint(file.relativePath),
                    modifiedAt: file.modifiedAt,
                    staleComparedToIDL: staleComparedToIDL(file: file, idls: parsedIDLs.map(\.brain))
                ))
                if let text = readText(file.url),
                   let frontend = frontendCandidate(for: file, text: text, idls: parsedIDLs.map(\.idl)) {
                    frontendCandidates.append(frontend)
                }
            case "Test source":
                testCandidates.append(TestCandidate(
                    id: file.relativePath,
                    relativePath: file.relativePath,
                    kind: testKind(file.relativePath),
                    modifiedAt: file.modifiedAt
                ))
            default:
                break
            }
        }

        let rustDeclareIDs = rustSummaries.flatMap(\.declareIDs)
        let sourceInstructions = enrichedInstructions(from: rustSummaries)
        let idlInstructions = idlInstructionBrains(from: parsedIDLs)
            .filter { idlInstruction in !sourceInstructions.contains(where: { $0.name == idlInstruction.name }) }
        let instructions = sourceInstructions + idlInstructions
        let sourceAccounts = rustSummaries.flatMap(\.accountTypes)
        let idlAccounts = idlAccountBrains(from: parsedIDLs)
            .filter { idlAccount in !sourceAccounts.contains(where: { $0.name == idlAccount.name }) }
        let accounts = sourceAccounts + idlAccounts
        let pdaCandidates = rustSummaries.flatMap(\.pdaCandidates) + idlPDACandidates(from: parsedIDLs)
        warnings.append(contentsOf: globalWarnings(
            project: project,
            anchorToml: anchorToml,
            rustSummaries: rustSummaries,
            idls: parsedIDLs.map(\.brain),
            clients: clientCandidates,
            tests: testCandidates
        ))

        let programs = programBrains(
            anchorToml: anchorToml,
            rustSummaries: rustSummaries,
            idls: parsedIDLs.map(\.brain),
            instructions: instructions,
            accounts: accounts,
            deployArtifacts: deployArtifacts,
            warnings: &warnings
        )

        let detectedFiles = files.map {
            DetectedProjectFile(
                relativePath: $0.relativePath,
                kind: $0.kind,
                byteCount: $0.byteCount,
                modifiedAt: $0.modifiedAt
            )
        }

        let projectType = inferProjectType(
            anchorToml: anchorToml,
            cargoSummaries: cargoSummaries.map(\.summary),
            packageSummaries: packageSummaries.map(\.summary),
            rustDeclareIDs: rustDeclareIDs,
            idls: parsedIDLs.map(\.brain)
        )

        return DeveloperProjectBrain(
            id: UUID(),
            projectId: project.id.uuidString,
            projectName: AgentSafetyRedactor.redact(project.displayName),
            projectRootDisplay: DeveloperProjectBrainPath.display(path: project.localPath),
            generatedAt: Date(),
            projectType: projectType,
            trustStatus: project.trustStatus,
            detectedFiles: detectedFiles,
            toolchainHints: toolchainHints.deduplicatedByID(),
            programs: programs,
            idls: parsedIDLs.map(\.brain),
            instructions: instructions,
            accounts: accounts,
            pdaCandidates: pdaCandidates,
            clientCandidates: clientCandidates,
            testCandidates: testCandidates,
            frontendCandidates: frontendCandidates,
            warnings: warnings.deduplicatedByID(),
            unsupportedFindings: unsupported,
            confidence: confidence(projectType: projectType, programs: programs, idls: parsedIDLs.map(\.brain), unsupported: unsupported)
        )
    }

    private func collectFiles(root: URL) -> [FileRecord] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var records: [FileRecord] = []
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"

        for case let url as URL in enumerator {
            guard records.count < maxFiles else { break }
            let standardized = url.standardizedFileURL
            guard standardized.path.hasPrefix(rootPath) else { continue }
            let relativePath = DeveloperProjectBrainPath.cleanRelativePath(String(standardized.path.dropFirst(rootPath.count)))
            guard !relativePath.isEmpty else { continue }
            guard let values = try? standardized.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true {
                if values.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }
            if values.isDirectory == true {
                if shouldSkipDirectory(relativePath) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values.isRegularFile == true,
                  let kind = fileKind(relativePath),
                  let byteCount = values.fileSize else {
                continue
            }
            records.append(FileRecord(
                url: standardized,
                relativePath: relativePath,
                kind: kind,
                byteCount: byteCount,
                modifiedAt: values.contentModificationDate
            ))
        }

        return records.sorted { $0.relativePath < $1.relativePath }
    }

    private func isSafeRoot(_ path: String) -> Bool {
        path.hasPrefix("/")
            && !path.contains("..")
            && !path.contains(";")
            && !path.contains("|")
            && !path.contains("&")
            && !path.contains("`")
    }

    private func shouldSkipDirectory(_ relativePath: String) -> Bool {
        let components = relativePath.split(separator: "/").map(String.init)
        guard let name = components.last else { return false }
        if [".git", ".anchor", "node_modules", ".next", ".turbo", "dist", "build", "coverage"].contains(name) {
            return true
        }
        if relativePath == "target" {
            return false
        }
        if relativePath.hasPrefix("target/idl") || relativePath.hasPrefix("target/deploy") || relativePath.hasPrefix("target/types") {
            return false
        }
        if relativePath.hasPrefix("target/") {
            return true
        }
        return false
    }

    private func fileKind(_ relativePath: String) -> String? {
        let url = URL(fileURLWithPath: relativePath)
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        if name == "Anchor.toml" { return "Anchor.toml" }
        if name == "Cargo.toml" { return "Cargo.toml" }
        if name == "package.json" { return "package.json" }
        if ext == "rs" { return "Rust source" }
        if ext == "json", relativePath.hasPrefix("idl/") || relativePath.hasPrefix("target/idl/") { return "Anchor IDL" }
        if ext == "so", relativePath.hasPrefix("target/deploy/") { return "Deploy artifact" }
        if ["ts", "tsx", "js", "jsx"].contains(ext) {
            if isTestPath(relativePath) { return "Test source" }
            if isClientOrFrontendPath(relativePath) { return "Client source" }
        }
        return nil
    }

    private func readText(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func enrichedInstructions(from summaries: [AnchorRustSourceSummary]) -> [InstructionBrain] {
        let structsByName = Dictionary(uniqueKeysWithValues: summaries.flatMap(\.accountStructs).map { ($0.name, $0) })
        return summaries.flatMap(\.instructions).map { instruction in
            guard let contextName = instruction.accounts.first,
                  let accountsStruct = structsByName[contextName] else {
                return instruction
            }
            return InstructionBrain(
                id: instruction.id,
                name: instruction.name,
                sourceRelativePath: instruction.sourceRelativePath,
                sourceLineStart: instruction.sourceLineStart,
                args: instruction.args,
                accounts: accountsStruct.accounts,
                signerAccounts: accountsStruct.signers,
                writableAccounts: accountsStruct.writable,
                anchorConstraints: accountsStruct.constraints,
                cpiHints: instruction.cpiHints,
                pdaHints: accountsStruct.pdaHints,
                confidence: instruction.confidence
            )
        }
    }

    private func idlInstructionBrains(from idls: [(idl: WorkstationIDL, brain: IDLBrain)]) -> [InstructionBrain] {
        idls.flatMap { pair in
            pair.idl.instructions.map { instruction in
                InstructionBrain(
                    id: "\(pair.brain.relativePath):idl:\(instruction.name)",
                    name: instruction.name,
                    sourceRelativePath: pair.brain.relativePath,
                    sourceLineStart: nil,
                    args: instruction.args.map { "\($0.name): \($0.type)" },
                    accounts: instruction.accounts.map(\.name),
                    signerAccounts: instruction.accounts.filter(\.isSigner).map(\.name),
                    writableAccounts: instruction.accounts.filter(\.isMut).map(\.name),
                    anchorConstraints: [],
                    cpiHints: [],
                    pdaHints: instruction.accounts.compactMap { $0.pda?.summary },
                    confidence: .high
                )
            }
        }
    }

    private func idlAccountBrains(from idls: [(idl: WorkstationIDL, brain: IDLBrain)]) -> [AccountBrain] {
        idls.flatMap { pair in
            pair.idl.accounts.map { account in
                AccountBrain(
                    id: "\(pair.brain.relativePath):idl-account:\(account.name)",
                    name: account.name,
                    sourceRelativePath: pair.brain.relativePath,
                    sourceLineStart: nil,
                    fields: account.fields.map { "\($0.name): \($0.type)" },
                    discriminator: account.discriminatorHex,
                    idlTypeRef: account.name,
                    confidence: .high
                )
            }
        }
    }

    private func idlPDACandidates(from idls: [(idl: WorkstationIDL, brain: IDLBrain)]) -> [PDACandidate] {
        idls.flatMap { pair in
            pair.idl.instructions.flatMap { instruction in
                instruction.accounts.compactMap { account in
                    guard let pda = account.pda else { return nil }
                    return PDACandidate(
                        id: "\(pair.brain.relativePath):idl-pda:\(instruction.name):\(account.name)",
                        label: account.name,
                        sourceRelativePath: pair.brain.relativePath,
                        sourceLineStart: nil,
                        programIdSource: pda.program ?? pair.idl.address,
                        seeds: pda.seeds.map(\.summary),
                        bumpUsage: "IDL PDA metadata",
                        accountType: account.name,
                        instructionName: instruction.name,
                        confidence: .medium,
                        unsupportedReason: nil
                    )
                }
            }
        }
    }

    private func programBrains(
        anchorToml: AnchorTomlSummary,
        rustSummaries: [AnchorRustSourceSummary],
        idls: [IDLBrain],
        instructions: [InstructionBrain],
        accounts: [AccountBrain],
        deployArtifacts: [String],
        warnings: inout [ProjectBrainWarning]
    ) -> [ProgramBrain] {
        var names = Set<String>()
        anchorToml.allProgramIDsByName.keys.forEach { names.insert(normalizedName($0)) }
        rustSummaries.flatMap(\.programModules).forEach { names.insert(normalizedName($0.name)) }
        idls.forEach { names.insert(normalizedName($0.programName)) }
        for path in deployArtifacts {
            names.insert(normalizedName(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent))
        }

        if names.isEmpty, !rustSummaries.isEmpty {
            names.insert("rust-program")
        }

        return names.sorted().map { normalized in
            let anchorEntry = anchorToml.allProgramIDsByName.first { normalizedName($0.key) == normalized }
            let idl = idls.first { normalizedName($0.programName) == normalized }
            let modules = rustSummaries.flatMap(\.programModules).filter { normalizedName($0.name) == normalized }
            let sourceFiles = Array(Set((modules.map(\.relativePath) + rustSummaries.flatMap(\.declareIDs).map(\.relativePath)).filter { path in
                normalized == "rust-program" || path.contains(normalized.replacingOccurrences(of: "_", with: "-")) || modules.contains { $0.relativePath == path }
            })).sorted()
            let declareID = rustSummaries.flatMap(\.declareIDs).first { declaration in
                sourceFiles.isEmpty || sourceFiles.contains(declaration.relativePath)
            }?.id
            let anchorID = anchorEntry?.value
            let idlID = idl?.programId
            let mismatchWarnings = mismatchWarnings(name: normalized, declareID: declareID, anchorTomlID: anchorID, idlID: idlID, sourcePath: sourceFiles.first ?? idl?.relativePath)
            warnings.append(contentsOf: mismatchWarnings)
            if idl == nil {
                warnings.append(ProjectBrainWarning(
                    id: "missing-idl-\(normalized)",
                    severity: .warning,
                    category: "IDL",
                    title: "Local IDL missing",
                    detail: "No local IDL was found for \(normalized). PDA, account, and frontend checks will be incomplete.",
                    sourceRelativePath: sourceFiles.first,
                    suggestedAction: "Build or import the program IDL before relying on interface-level analysis."
                ))
            }
            return ProgramBrain(
                id: normalized,
                name: anchorEntry?.key ?? idl?.programName ?? modules.first?.name ?? normalized,
                relativePath: sourceFiles.first?.components(separatedBy: "/src/").first ?? "Unavailable",
                language: sourceFiles.isEmpty ? "IDL" : "Rust",
                programIdFromDeclareId: declareID,
                programIdFromAnchorToml: anchorID,
                programIdFromIdl: idlID,
                programIdMismatchWarnings: mismatchWarnings,
                sourceFiles: sourceFiles,
                idlPaths: idl.map { [$0.relativePath] } ?? [],
                deployArtifacts: deployArtifacts.filter { normalizedName(URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent) == normalized },
                instructions: instructions.map(\.name).uniqued(),
                accountTypes: accounts.map(\.name).uniqued(),
                errorTypes: rustSummaries.flatMap(\.errorTypes).uniqued(),
                events: rustSummaries.flatMap(\.events).uniqued()
            )
        }
    }

    private func mismatchWarnings(name: String, declareID: String?, anchorTomlID: String?, idlID: String?, sourcePath: String?) -> [ProjectBrainWarning] {
        var warnings: [ProjectBrainWarning] = []
        func append(_ leftLabel: String, _ left: String, _ rightLabel: String, _ right: String) {
            warnings.append(ProjectBrainWarning(
                id: "program-id-mismatch-\(name)-\(leftLabel)-\(rightLabel)",
                severity: .high,
                category: "Program ID",
                title: "Program id mismatch",
                detail: "\(leftLabel) is \(left), but \(rightLabel) is \(right).",
                sourceRelativePath: sourcePath,
                suggestedAction: "Verify the intended cluster and update Anchor.toml, declare_id!, or IDL metadata before deploying or testing."
            ))
        }
        if let declareID, let anchorTomlID, declareID != anchorTomlID {
            append("declare_id", declareID, "Anchor.toml", anchorTomlID)
        }
        if let declareID, let idlID, declareID != idlID {
            append("declare_id", declareID, "IDL address", idlID)
        }
        if let anchorTomlID, let idlID, anchorTomlID != idlID {
            append("Anchor.toml", anchorTomlID, "IDL address", idlID)
        }
        return warnings
    }

    private func globalWarnings(
        project: WorkstationProject,
        anchorToml: AnchorTomlSummary,
        rustSummaries: [AnchorRustSourceSummary],
        idls: [IDLBrain],
        clients: [ClientCandidate],
        tests: [TestCandidate]
    ) -> [ProjectBrainWarning] {
        var warnings: [ProjectBrainWarning] = []
        let sourceProgramNames = Set(rustSummaries.flatMap(\.programModules).map { normalizedName($0.name) })
        for idl in idls where !sourceProgramNames.isEmpty && !sourceProgramNames.contains(normalizedName(idl.programName)) {
            warnings.append(ProjectBrainWarning(
                id: "orphan-idl-\(idl.relativePath)",
                severity: .warning,
                category: "IDL",
                title: "IDL has no matching source program",
                detail: "The IDL \(idl.programName) exists, but no matching #[program] module was found in scanned Rust source.",
                sourceRelativePath: idl.relativePath,
                suggestedAction: "Confirm the IDL belongs to this workspace or refresh generated artifacts."
            ))
        }
        if project.detectedFramework == .anchor, tests.isEmpty {
            warnings.append(ProjectBrainWarning(
                id: "missing-tests",
                severity: .warning,
                category: "Tests",
                title: "Anchor project has no tests detected",
                detail: "No test files were found under common tests/client paths.",
                suggestedAction: "Add localnet tests before treating deploy evidence as release-ready."
            ))
        }
        for client in clients where client.staleComparedToIDL == true {
            warnings.append(ProjectBrainWarning(
                id: "stale-client-\(client.relativePath)",
                severity: .warning,
                category: "Client",
                title: "Generated client may be stale",
                detail: "The client file is older than at least one detected IDL.",
                sourceRelativePath: client.relativePath,
                suggestedAction: "Regenerate the client from the current IDL before integrating frontend or test code."
            ))
        }
        let idlsByProgram = Dictionary(grouping: idls, by: { normalizedName($0.programName) })
        for (program, entries) in idlsByProgram where entries.count > 1 {
            let sorted = entries.sorted { $0.relativePath < $1.relativePath }
            guard let first = sorted.first else {
                continue
            }
            for other in sorted.dropFirst() {
                if first.instructions != other.instructions ||
                    first.accounts != other.accounts ||
                    first.types != other.types ||
                    first.errors != other.errors ||
                    first.events != other.events ||
                    first.discriminators != other.discriminators {
                    warnings.append(ProjectBrainWarning(
                        id: "idl-drift-\(program)-\(other.relativePath)",
                        severity: .warning,
                        category: "IDL Drift",
                        title: "Local IDL shape differs",
                        detail: "\(other.relativePath) differs from \(first.relativePath) for \(first.programName).",
                        sourceRelativePath: other.relativePath,
                        suggestedAction: "Open IDL Browser > Drift and compare the real IDL files before generating clients or decoding accounts."
                    ))
                }
            }
        }
        if !anchorToml.scripts.isEmpty {
            warnings.append(ProjectBrainWarning(
                id: "scripts-metadata-only",
                severity: .info,
                category: "Trust",
                title: "Anchor scripts detected as metadata only",
                detail: "Project Brain recorded \(anchorToml.scripts.count) script name(s), but did not execute them.",
                suggestedAction: "Scripts stay locked behind reviewed fixed command builders and project trust."
            ))
        }
        return warnings
    }

    private func frontendCandidate(for file: FileRecord, text: String, idls: [WorkstationIDL]) -> FrontendCandidate? {
        let hint = clientFrameworkHint(file.relativePath)
        var warnings: [ProjectBrainWarning] = []
        let largeIntegerArgs = idls.flatMap(\.instructions).flatMap(\.args).filter { ["u64", "u128", "i64", "i128"].contains($0.type) }
        for arg in largeIntegerArgs {
            if text.range(of: #"(\b\#(arg.name)\b\s*:\s*number|\b\#(arg.name)\b\s*=\s*\d{6,})"#, options: .regularExpression) != nil {
                warnings.append(ProjectBrainWarning(
                    id: "frontend-number-\(file.relativePath)-\(arg.name)",
                    severity: .warning,
                    category: "Frontend",
                    title: "Possible JS number for large integer",
                    detail: "The client references \(arg.name) as a number-like value for IDL type \(arg.type).",
                    sourceRelativePath: file.relativePath,
                    suggestedAction: "Use BN, bigint, or the project's established Anchor client integer type instead of lossy JavaScript number."
                ))
            }
        }
        guard !warnings.isEmpty || hint != "Client source" else {
            return nil
        }
        return FrontendCandidate(
            id: file.relativePath,
            relativePath: file.relativePath,
            frameworkHint: hint,
            warnings: warnings
        )
    }

    private func staleComparedToIDL(file: FileRecord, idls: [IDLBrain]) -> Bool? {
        guard let modifiedAt = file.modifiedAt,
              let newestIDL = idls.compactMap(\.modifiedAt).max() else {
            return nil
        }
        return modifiedAt < newestIDL
    }

    private func clientFrameworkHint(_ relativePath: String) -> String {
        if relativePath.hasPrefix("target/types/") {
            return "Generated Anchor TypeScript client"
        }
        if relativePath.contains("app/") || relativePath.contains("src/") {
            return "Frontend client"
        }
        return "Client source"
    }

    private func testKind(_ relativePath: String) -> String {
        if relativePath.hasSuffix(".rs") {
            return "Rust test"
        }
        if relativePath.hasSuffix(".ts") || relativePath.hasSuffix(".tsx") {
            return "TypeScript test"
        }
        return "JavaScript test"
    }

    private func isTestPath(_ relativePath: String) -> Bool {
        relativePath.hasPrefix("tests/")
            || relativePath.contains("/tests/")
            || relativePath.hasPrefix("test/")
            || relativePath.contains(".test.")
            || relativePath.contains(".spec.")
    }

    private func isClientOrFrontendPath(_ relativePath: String) -> Bool {
        relativePath.hasPrefix("target/types/")
            || relativePath.hasPrefix("client/")
            || relativePath.hasPrefix("clients/")
            || relativePath.hasPrefix("app/")
            || relativePath.hasPrefix("src/")
            || relativePath.contains("/src/")
    }

    private func inferProjectType(
        anchorToml: AnchorTomlSummary,
        cargoSummaries: [CargoTomlSummary],
        packageSummaries: [PackageJsonSummary],
        rustDeclareIDs: [(id: String, relativePath: String, line: Int)],
        idls: [IDLBrain]
    ) -> DeveloperProjectType {
        let hasAnchor = !anchorToml.programsByCluster.isEmpty || cargoSummaries.contains { $0.relevantDependencies.contains("anchor-lang") } || !idls.isEmpty
        let hasRust = !cargoSummaries.isEmpty || !rustDeclareIDs.isEmpty
        let hasNode = !packageSummaries.isEmpty
        if hasAnchor && hasNode { return .mixed }
        if hasAnchor { return .anchor }
        if hasRust { return .nativeSolanaRust }
        if hasNode { return .nodeTypescript }
        return .unknown
    }

    private func confidence(projectType: DeveloperProjectType, programs: [ProgramBrain], idls: [IDLBrain], unsupported: [UnsupportedFinding]) -> BrainConfidence {
        if projectType == .unknown {
            return .unknown
        }
        if !unsupported.isEmpty {
            return .medium
        }
        if !programs.isEmpty, !idls.isEmpty {
            return .high
        }
        return .medium
    }

    private func normalizedName(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

private extension Array where Element == ToolchainHint {
    func deduplicatedByID() -> [ToolchainHint] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}

private extension Array where Element == ProjectBrainWarning {
    func deduplicatedByID() -> [ProjectBrainWarning] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}
