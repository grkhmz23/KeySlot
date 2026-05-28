import Foundation

enum FrontendAssistantSeverity: String, Codable, CaseIterable, Identifiable {
    case info
    case low
    case medium
    case high

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum FrontendAssistantStatus: String, Codable, Equatable {
    case ready
    case warning
    case unavailable
    case blocked

    var title: String {
        switch self {
        case .ready:
            return "Ready"
        case .warning:
            return "Needs review"
        case .unavailable:
            return "Unavailable"
        case .blocked:
            return "Blocked"
        }
    }
}

enum FrontendGeneratedFileKind: String, Codable, CaseIterable, Identifiable {
    case pdaHelper
    case instructionAccountMap
    case reactHook
    case programConstants
    case idlImportWrapper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pdaHelper:
            return "TypeScript PDA helper"
        case .instructionAccountMap:
            return "Instruction account map"
        case .reactHook:
            return "React hook draft"
        case .programConstants:
            return "Program constants"
        case .idlImportWrapper:
            return "IDL import wrapper"
        }
    }
}

enum FrontendPayloadAvailability: String, Codable, Equatable {
    case draft
    case written
    case blocked

    var title: String { rawValue.capitalized }
}

struct FrontendDetectedSurface: Codable, Equatable {
    var packageJSONPaths: [String] = []
    var appDirectories: [String] = []
    var pagesDirectories: [String] = []
    var componentDirectories: [String] = []
    var hookDirectories: [String] = []
    var libDirectories: [String] = []
    var frameworkHints: [String] = []
    var dependencies: [String] = []
    var devDependencies: [String] = []
    var generatedClients: [String] = []
    var idlImports: [String] = []
    var hardcodedProgramIDs: [String] = []
    var clusterHints: [String] = []

    var hasFrontend: Bool {
        !packageJSONPaths.isEmpty
            || !appDirectories.isEmpty
            || !pagesDirectories.isEmpty
            || !componentDirectories.isEmpty
            || !hookDirectories.isEmpty
            || !libDirectories.isEmpty
            || !frameworkHints.isEmpty
    }
}

struct FrontendIntegrationFinding: Codable, Equatable, Identifiable {
    let id: String
    let severity: FrontendAssistantSeverity
    let category: String
    let title: String
    let detail: String
    let sourceRelativePath: String?
    let line: Int?
    let evidence: String
    let suggestedAction: String

    init(
        id: String,
        severity: FrontendAssistantSeverity,
        category: String,
        title: String,
        detail: String,
        sourceRelativePath: String? = nil,
        line: Int? = nil,
        evidence: String,
        suggestedAction: String
    ) {
        self.id = id
        self.severity = severity
        self.category = WorkstationCommandRunner.safeSummary(category)
        self.title = WorkstationCommandRunner.safeSummary(title)
        self.detail = WorkstationCommandRunner.safeSummary(detail)
        self.sourceRelativePath = sourceRelativePath.map(DeveloperProjectBrainPath.cleanRelativePath)
        self.line = line
        self.evidence = WorkstationCommandRunner.safeSummary(evidence)
        self.suggestedAction = WorkstationCommandRunner.safeSummary(suggestedAction)
    }
}

struct FrontendGeneratedFileDraft: Codable, Equatable, Identifiable {
    let id: String
    let kind: FrontendGeneratedFileKind
    let relativePath: String
    let content: String
    let dependencyStyle: String
    let warning: String?
    let status: FrontendPayloadAvailability

    init(
        kind: FrontendGeneratedFileKind,
        relativePath: String,
        content: String,
        dependencyStyle: String,
        warning: String? = nil,
        status: FrontendPayloadAvailability = .draft
    ) {
        self.id = "\(kind.rawValue):\(relativePath)"
        self.kind = kind
        self.relativePath = DeveloperProjectBrainPath.cleanRelativePath(relativePath)
        self.content = AgentSafetyRedactor.redact(content)
        self.dependencyStyle = WorkstationCommandRunner.safeSummary(dependencyStyle)
        self.warning = warning.map(WorkstationCommandRunner.safeSummary)
        self.status = status
    }
}

struct FrontendAssistantReport: Codable, Equatable, Identifiable {
    let id: UUID
    let projectId: String
    let projectName: String
    let generatedAt: Date
    let status: FrontendAssistantStatus
    let readOnly: Bool
    let scannedFileCount: Int
    let detectedSurface: FrontendDetectedSurface
    let findings: [FrontendIntegrationFinding]
    let draftableInstructions: [String]
    let recommendedDependencyStyle: String
    let summary: String

    init(
        id: UUID = UUID(),
        projectId: String,
        projectName: String,
        generatedAt: Date = Date(),
        status: FrontendAssistantStatus,
        readOnly: Bool = true,
        scannedFileCount: Int,
        detectedSurface: FrontendDetectedSurface,
        findings: [FrontendIntegrationFinding],
        draftableInstructions: [String],
        recommendedDependencyStyle: String,
        summary: String
    ) {
        self.id = id
        self.projectId = projectId
        self.projectName = WorkstationCommandRunner.safeSummary(projectName)
        self.generatedAt = generatedAt
        self.status = status
        self.readOnly = readOnly
        self.scannedFileCount = scannedFileCount
        self.detectedSurface = detectedSurface
        self.findings = findings
        self.draftableInstructions = draftableInstructions.map(WorkstationCommandRunner.safeSummary)
        self.recommendedDependencyStyle = WorkstationCommandRunner.safeSummary(recommendedDependencyStyle)
        self.summary = WorkstationCommandRunner.safeSummary(summary)
    }

    var warningCount: Int {
        findings.filter { [.medium, .high].contains($0.severity) }.count
    }
}

struct FrontendGeneratedFileRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let kind: FrontendGeneratedFileKind
    let relativePath: String
    let status: FrontendPayloadAvailability
    let message: String

    init(id: UUID = UUID(), kind: FrontendGeneratedFileKind, relativePath: String, status: FrontendPayloadAvailability, message: String) {
        self.id = id
        self.kind = kind
        self.relativePath = DeveloperProjectBrainPath.cleanRelativePath(relativePath)
        self.status = status
        self.message = WorkstationCommandRunner.safeSummary(message)
    }
}

struct FrontendGenerationEvidence: Codable, Equatable, Identifiable {
    let id: UUID
    let projectId: String
    let projectName: String
    let selectedInstruction: String?
    let generatedAt: Date
    let files: [FrontendGeneratedFileRecord]
    let summary: String

    init(
        id: UUID = UUID(),
        projectId: String,
        projectName: String,
        selectedInstruction: String?,
        generatedAt: Date = Date(),
        files: [FrontendGeneratedFileRecord],
        summary: String
    ) {
        self.id = id
        self.projectId = projectId
        self.projectName = WorkstationCommandRunner.safeSummary(projectName)
        self.selectedInstruction = selectedInstruction.map(WorkstationCommandRunner.safeSummary)
        self.generatedAt = generatedAt
        self.files = files
        self.summary = WorkstationCommandRunner.safeSummary(summary)
    }
}

enum FrontendAssistantError: LocalizedError, Equatable {
    case missingProject
    case unsupportedSource(String)
    case missingProjectRoot
    case unsafeProjectRoot
    case missingIDL
    case missingInstruction
    case approvalRequired
    case unsafeOutputPath(String)

    var errorDescription: String? {
        switch self {
        case .missingProject:
            return "Import a folder project before using Frontend Assistant."
        case .unsupportedSource(let source):
            return "Frontend Assistant reads folder projects only. \(source) imports remain metadata-only until extracted by a reviewed safe flow."
        case .missingProjectRoot:
            return "Project root does not exist."
        case .unsafeProjectRoot:
            return "Project root failed path safety validation."
        case .missingIDL:
            return "Load an Anchor IDL before generating frontend drafts."
        case .missingInstruction:
            return "Select an IDL instruction before generating this draft."
        case .approvalRequired:
            return "Writing generated frontend drafts requires the exact approval phrase."
        case .unsafeOutputPath(let path):
            return "Generated output path is unsafe or outside the project: \(path)"
        }
    }
}

enum FrontendIntegrationService {
    static let writeApprovalPhrase = "Write generated frontend draft"
    private static let maxFiles = 700
    private static let maxFileBytes = 512 * 1024

    static func inspect(
        project: WorkstationProject?,
        projectBrain: DeveloperProjectBrain?,
        idl: WorkstationIDL?,
        fileManager: FileManager = .default
    ) throws -> FrontendAssistantReport {
        guard let project else {
            throw FrontendAssistantError.missingProject
        }
        guard project.sourceType == .folder || project.sourceType == .gitHTTPS else {
            throw FrontendAssistantError.unsupportedSource(project.sourceType.rawValue)
        }
        let root = URL(fileURLWithPath: project.localPath, isDirectory: true).standardizedFileURL
        guard isSafeRoot(root.path) else {
            throw FrontendAssistantError.unsafeProjectRoot
        }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw FrontendAssistantError.missingProjectRoot
        }

        let files = collectFrontendFiles(root: root, fileManager: fileManager)
        var detected = FrontendDetectedSurface()
        var findings: [FrontendIntegrationFinding] = []
        var packageProviderCluster: String?
        let expectedProgramIDs = expectedProgramIDs(projectBrain: projectBrain, idl: idl)
        let expectedProgramIDSet = Set(expectedProgramIDs)

        if let anchorTomlURL = existingFile(root: root, relativePath: "Anchor.toml", fileManager: fileManager),
           let text = try? String(contentsOf: anchorTomlURL, encoding: .utf8) {
            let anchor = AnchorTomlScanner.parse(text)
            packageProviderCluster = anchor.providerCluster
        }

        for file in files {
            applyPathDetection(file.relativePath, detected: &detected)
            guard file.byteCount <= maxFileBytes else { continue }

            if file.relativePath.hasSuffix("package.json"),
               let data = try? Data(contentsOf: file.url) {
                let summary = PackageJsonScanner.parse(data)
                detected.packageJSONPaths.append(file.relativePath)
                detected.dependencies.append(contentsOf: summary.dependencies)
                detected.devDependencies.append(contentsOf: summary.devDependencies)
                detected.frameworkHints.append(contentsOf: dependencyHints(summary))
                continue
            }

            guard let text = try? String(contentsOf: file.url, encoding: .utf8) else {
                continue
            }
            scanClientText(
                file: file,
                text: text,
                idl: idl,
                projectBrain: projectBrain,
                expectedProgramIDs: expectedProgramIDSet,
                providerCluster: packageProviderCluster,
                detected: &detected,
                findings: &findings
            )
        }

        detected.generatedClients.append(contentsOf: projectBrain?.clientCandidates.map(\.relativePath) ?? [])
        detected.idlImports.append(contentsOf: projectBrain?.idls.map(\.relativePath) ?? [])

        detected.dependencies = Array(Set(detected.dependencies)).sorted()
        detected.devDependencies = Array(Set(detected.devDependencies)).sorted()
        detected.frameworkHints = Array(Set(detected.frameworkHints)).sorted()
        detected.hardcodedProgramIDs = Array(Set(detected.hardcodedProgramIDs)).sorted()
        detected.clusterHints = Array(Set(detected.clusterHints)).sorted()
        detected.idlImports = Array(Set(detected.idlImports)).sorted()
        detected.generatedClients = Array(Set(detected.generatedClients)).sorted()

        if detected.hasFrontend == false {
            findings.append(FrontendIntegrationFinding(
                id: "frontend-unavailable",
                severity: .low,
                category: "Detection",
                title: "No frontend surface detected",
                detail: "No package.json, React/Next/Vite path, generated client, or IDL import was found in bounded scan paths.",
                evidence: "Scanned \(files.count) frontend candidate file(s).",
                suggestedAction: "Add a frontend package or generated client path, then run Project Brain and Frontend Assistant again."
            ))
        }
        if idl != nil, detected.idlImports.isEmpty {
            findings.append(FrontendIntegrationFinding(
                id: "idl-import-missing",
                severity: .medium,
                category: "IDL",
                title: "IDL import was not found",
                detail: "The frontend does not appear to import a local Anchor IDL JSON file.",
                evidence: "Loaded IDL \(idl?.name ?? "unknown") was available to the assistant.",
                suggestedAction: "Generate an IDL import wrapper or wire the frontend to a reviewed local IDL JSON file."
            ))
        }

        let status: FrontendAssistantStatus
        if findings.contains(where: { $0.severity == .high }) {
            status = .blocked
        } else if findings.contains(where: { [.medium, .low].contains($0.severity) }) {
            status = .warning
        } else if detected.hasFrontend {
            status = .ready
        } else {
            status = .unavailable
        }

        let style = dependencyStyle(detected)
        return FrontendAssistantReport(
            projectId: project.id.uuidString,
            projectName: project.displayName,
            status: status,
            scannedFileCount: files.count,
            detectedSurface: detected,
            findings: findings.deduplicatedFrontendFindings(),
            draftableInstructions: idl?.instructions.map(\.name) ?? [],
            recommendedDependencyStyle: style,
            summary: summary(project: project, detected: detected, findings: findings, style: style)
        )
    }

    static func prepareDrafts(
        kind: FrontendGeneratedFileKind,
        instructionName: String?,
        project: WorkstationProject?,
        projectBrain: DeveloperProjectBrain?,
        idl: WorkstationIDL?,
        report: FrontendAssistantReport?
    ) throws -> [FrontendGeneratedFileDraft] {
        guard let project else {
            throw FrontendAssistantError.missingProject
        }
        guard let idl else {
            throw FrontendAssistantError.missingIDL
        }
        let style = report?.recommendedDependencyStyle ?? dependencyStyle(report?.detectedSurface ?? FrontendDetectedSurface())
        let safeName = safeFileToken(idl.name)
        let instruction = instructionName.flatMap { name in idl.instructions.first { $0.name == name } }
        let base = "keyslot/frontend-assistant"

        switch kind {
        case .programConstants:
            return [
                FrontendGeneratedFileDraft(
                    kind: kind,
                    relativePath: "\(base)/\(safeName)-constants.ts",
                    content: programConstants(idl: idl, projectBrain: projectBrain, projectName: project.displayName),
                    dependencyStyle: style
                )
            ]
        case .idlImportWrapper:
            return [
                FrontendGeneratedFileDraft(
                    kind: kind,
                    relativePath: "\(base)/\(safeName)-idl.ts",
                    content: idlImportWrapper(idl: idl),
                    dependencyStyle: style
                )
            ]
        case .pdaHelper:
            return [
                FrontendGeneratedFileDraft(
                    kind: kind,
                    relativePath: "\(base)/\(safeName)-pdas.ts",
                    content: pdaHelper(idl: idl, projectBrain: projectBrain),
                    dependencyStyle: style,
                    warning: projectBrain?.pdaCandidates.isEmpty == false ? nil : "No Project Brain PDA candidates were available; the helper contains only IDL PDA metadata and manual placeholders."
                )
            ]
        case .instructionAccountMap:
            guard let instruction else { throw FrontendAssistantError.missingInstruction }
            return [
                FrontendGeneratedFileDraft(
                    kind: kind,
                    relativePath: "\(base)/\(safeFileToken(instruction.name))-accounts.ts",
                    content: instructionAccountMap(idl: idl, instruction: instruction),
                    dependencyStyle: style
                )
            ]
        case .reactHook:
            guard let instruction else { throw FrontendAssistantError.missingInstruction }
            return [
                FrontendGeneratedFileDraft(
                    kind: kind,
                    relativePath: "\(base)/use-\(safeFileToken(instruction.name)).ts",
                    content: reactHookDraft(idl: idl, instruction: instruction, dependencyStyle: style),
                    dependencyStyle: style,
                    warning: style == "Unknown" ? "Project dependency style is unclear; this hook is a copyable draft until dependencies are reviewed." : nil
                )
            ]
        }
    }

    static func writeDrafts(
        _ drafts: [FrontendGeneratedFileDraft],
        project: WorkstationProject?,
        approvalPhrase: String,
        selectedInstruction: String? = nil,
        overwrite: Bool = false,
        fileManager: FileManager = .default
    ) throws -> FrontendGenerationEvidence {
        guard let project else {
            throw FrontendAssistantError.missingProject
        }
        guard approvalPhrase == writeApprovalPhrase else {
            throw FrontendAssistantError.approvalRequired
        }
        let root = URL(fileURLWithPath: project.localPath, isDirectory: true).standardizedFileURL
        guard isSafeRoot(root.path) else {
            throw FrontendAssistantError.unsafeProjectRoot
        }

        var records: [FrontendGeneratedFileRecord] = []
        for draft in drafts {
            let relative = DeveloperProjectBrainPath.cleanRelativePath(draft.relativePath)
            let destination = root.appendingPathComponent(relative).standardizedFileURL
            guard destination.path.hasPrefix(root.path + "/"),
                  relative.hasPrefix("keyslot/frontend-assistant/"),
                  relative.contains("..") == false else {
                throw FrontendAssistantError.unsafeOutputPath(relative)
            }
            if fileManager.fileExists(atPath: destination.path), overwrite == false {
                records.append(FrontendGeneratedFileRecord(
                    kind: draft.kind,
                    relativePath: relative,
                    status: .blocked,
                    message: "File already exists and overwrite approval was not provided."
                ))
                continue
            }
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try draft.content.write(to: destination, atomically: true, encoding: .utf8)
            records.append(FrontendGeneratedFileRecord(
                kind: draft.kind,
                relativePath: relative,
                status: .written,
                message: "Generated draft file written under reviewed frontend-assistant output path."
            ))
        }

        return FrontendGenerationEvidence(
            projectId: project.id.uuidString,
            projectName: project.displayName,
            selectedInstruction: selectedInstruction?.isEmpty == false ? selectedInstruction : nil,
            files: records,
            summary: "\(records.filter { $0.status == .written }.count) generated frontend draft file(s) written. Existing files were not overwritten."
        )
    }

    private static func collectFrontendFiles(root: URL, fileManager: FileManager) -> [FrontendSourceFile] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var files: [FrontendSourceFile] = []
        for case let url as URL in enumerator {
            if files.count >= maxFiles { break }
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            if values.isDirectory == true {
                let rel = relativePath(root: root, url: url)
                if shouldSkipDirectory(rel) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            let relative = relativePath(root: root, url: url)
            guard isFrontendCandidatePath(relative) else { continue }
            let standardized = url.standardizedFileURL
            guard standardized.path.hasPrefix(root.path + "/") else { continue }
            files.append(FrontendSourceFile(
                url: standardized,
                relativePath: relative,
                byteCount: values.fileSize ?? 0
            ))
        }
        return files.sorted { $0.relativePath < $1.relativePath }
    }

    private static func scanClientText(
        file: FrontendSourceFile,
        text: String,
        idl: WorkstationIDL?,
        projectBrain: DeveloperProjectBrain?,
        expectedProgramIDs: Set<String>,
        providerCluster: String?,
        detected: inout FrontendDetectedSurface,
        findings: inout [FrontendIntegrationFinding]
    ) {
        let lines = text.components(separatedBy: .newlines)
        if file.relativePath.hasPrefix("target/types/") {
            detected.generatedClients.append(file.relativePath)
        }
        if text.contains(".json") && text.localizedCaseInsensitiveContains("idl") {
            detected.idlImports.append(file.relativePath)
        }
        for cluster in ["localnet", "devnet", "testnet", "mainnet-beta", "api.devnet.solana.com", "api.mainnet-beta.solana.com"] where text.contains(cluster) {
            detected.clusterHints.append(cluster)
        }

        if let providerCluster,
           !providerCluster.isEmpty,
           !detected.clusterHints.isEmpty,
           detected.clusterHints.contains(where: { cluster in !cluster.localizedCaseInsensitiveContains(providerCluster) }) {
            findings.append(FrontendIntegrationFinding(
                id: "cluster-mismatch-\(file.relativePath)",
                severity: .medium,
                category: "Cluster",
                title: "Possible frontend cluster mismatch",
                detail: "Frontend cluster hints do not match Anchor.toml provider cluster \(providerCluster).",
                sourceRelativePath: file.relativePath,
                evidence: detected.clusterHints.joined(separator: ", "),
                suggestedAction: "Centralize cluster config and make the frontend use the same reviewed cluster as Anchor.toml."
            ))
        }

        let largeArgs = idl?.instructions.flatMap(\.args).filter { ["u64", "u128", "i64", "i128"].contains($0.type) } ?? []
        for arg in largeArgs {
            for (offset, line) in lines.enumerated() {
                let lineNumber = offset + 1
                if line.range(of: #"(\b\#(arg.name)\b\s*:\s*number|\b\#(arg.name)\b\s*=\s*\d{6,})"#, options: .regularExpression) != nil {
                    findings.append(FrontendIntegrationFinding(
                        id: "large-int-number-\(file.relativePath)-\(arg.name)-\(lineNumber)",
                        severity: .medium,
                        category: "Integer safety",
                        title: "Possible lossy JavaScript number for \(arg.type)",
                        detail: "IDL arg \(arg.name) is \(arg.type), but frontend code appears to pass or type it as number.",
                        sourceRelativePath: file.relativePath,
                        line: lineNumber,
                        evidence: line,
                        suggestedAction: "Use bigint, BN, or the project's established Anchor integer type for \(arg.type) values."
                    ))
                }
            }
        }

        for match in captureBase58Strings(text) {
            guard SolanaAddressValidator.isValidAddress(match.value) else {
                if match.context.localizedCaseInsensitiveContains("publickey") || match.context.localizedCaseInsensitiveContains("program") {
                    findings.append(FrontendIntegrationFinding(
                        id: "invalid-pubkey-\(file.relativePath)-\(match.line)",
                        severity: .medium,
                        category: "Public key",
                        title: "Invalid public key string",
                        detail: "A string near PublicKey/program configuration does not parse as a Solana public key.",
                        sourceRelativePath: file.relativePath,
                        line: match.line,
                        evidence: match.context,
                        suggestedAction: "Replace the hardcoded value with a reviewed program constant or environment-backed public key."
                    ))
                }
                continue
            }
            detected.hardcodedProgramIDs.append(match.value)
            if !expectedProgramIDs.isEmpty, !expectedProgramIDs.contains(match.value), looksLikeProgramIDContext(match.context) {
                findings.append(FrontendIntegrationFinding(
                    id: "program-id-mismatch-\(file.relativePath)-\(match.line)-\(match.value)",
                    severity: .high,
                    category: "Program ID",
                    title: "Frontend program ID differs from project IDL/Anchor metadata",
                    detail: "A frontend program ID does not match the loaded IDL or Project Brain program IDs.",
                    sourceRelativePath: file.relativePath,
                    line: match.line,
                    evidence: "\(match.value) vs \(Array(expectedProgramIDs).sorted().joined(separator: ", "))",
                    suggestedAction: "Generate a program constants file from the loaded IDL and remove stale hardcoded program IDs."
                ))
            }
        }

        for (offset, line) in lines.enumerated() {
            let lower = line.lowercased()
            if (lower.contains("new transaction") || lower.contains(".methods.") || lower.contains("transaction.add")),
               !text.localizedCaseInsensitiveContains("wallet.publickey"),
               !text.localizedCaseInsensitiveContains("wallet?.publickey"),
               !text.localizedCaseInsensitiveContains("signer"),
               !text.localizedCaseInsensitiveContains("publicKey") {
                findings.append(FrontendIntegrationFinding(
                    id: "wallet-guard-\(file.relativePath)-\(offset + 1)",
                    severity: .low,
                    category: "Wallet guard",
                    title: "Transaction builder may be missing wallet guard",
                    detail: "The file builds a transaction-like object, but no obvious wallet public key or signer guard was found.",
                    sourceRelativePath: file.relativePath,
                    line: offset + 1,
                    evidence: line,
                    suggestedAction: "Separate transaction building from signing and require wallet/signer presence before building user actions."
                ))
                break
            }
        }

        for warning in projectBrain?.frontendCandidates.first(where: { $0.relativePath == file.relativePath })?.warnings ?? [] {
            findings.append(FrontendIntegrationFinding(
                id: "brain-\(warning.id)",
                severity: warning.severity == .high ? .high : .medium,
                category: warning.category,
                title: warning.title,
                detail: warning.detail,
                sourceRelativePath: warning.sourceRelativePath,
                line: warning.line,
                evidence: "Project Brain frontend warning",
                suggestedAction: warning.suggestedAction
            ))
        }
    }

    private static func applyPathDetection(_ relativePath: String, detected: inout FrontendDetectedSurface) {
        let components = relativePath.split(separator: "/").map(String.init)
        func addDir(_ list: inout [String], _ value: String) {
            if !list.contains(value) { list.append(value) }
        }
        if relativePath.hasPrefix("app/") || relativePath.contains("/app/") { addDir(&detected.appDirectories, "app") }
        if relativePath.hasPrefix("src/app/") || relativePath.contains("/src/app/") { addDir(&detected.appDirectories, "src/app") }
        if relativePath.hasPrefix("pages/") || relativePath.contains("/pages/") { addDir(&detected.pagesDirectories, "pages") }
        if components.contains("components") { addDir(&detected.componentDirectories, "components") }
        if components.contains("hooks") { addDir(&detected.hookDirectories, "hooks") }
        if components.contains("lib") { addDir(&detected.libDirectories, "lib") }
    }

    private static func dependencyHints(_ summary: PackageJsonSummary) -> [String] {
        let all = Set(summary.dependencies + summary.devDependencies)
        return [
            all.contains("next") ? "Next.js" : nil,
            all.contains("vite") ? "Vite" : nil,
            all.contains("react") ? "React" : nil,
            all.contains("@coral-xyz/anchor") ? "@coral-xyz/anchor" : nil,
            all.contains("@solana/web3.js") ? "@solana/web3.js" : nil,
            all.contains("@solana/kit") || all.contains("gill") ? "Solana Kit" : nil,
            all.contains("@solana/wallet-adapter-react") || all.contains("@solana/wallet-adapter-base") ? "Wallet Adapter" : nil
        ].compactMap { $0 }
    }

    private static func dependencyStyle(_ detected: FrontendDetectedSurface) -> String {
        let hints = Set(detected.frameworkHints)
        if hints.contains("Solana Kit") { return "Solana Kit" }
        if hints.contains("@coral-xyz/anchor") { return "Anchor TypeScript" }
        if hints.contains("@solana/web3.js") { return "web3.js" }
        if hints.contains("React") || hints.contains("Next.js") || hints.contains("Vite") { return "React draft" }
        return "Unknown"
    }

    private static func summary(project: WorkstationProject, detected: FrontendDetectedSurface, findings: [FrontendIntegrationFinding], style: String) -> String {
        if detected.hasFrontend {
            let hints = detected.frameworkHints.joined(separator: ", ")
            return "\(project.displayName) frontend scan found \(hints.isEmpty ? "client files" : hints) using \(style). \(findings.count) review finding(s) need attention."
        }
        return "\(project.displayName) does not expose a clear frontend integration surface in bounded scan paths."
    }

    private static func programConstants(idl: WorkstationIDL, projectBrain: DeveloperProjectBrain?, projectName: String) -> String {
        let programID = idl.address
            ?? projectBrain?.programs.compactMap(\.programIdFromDeclareId).first
            ?? projectBrain?.programs.compactMap(\.programIdFromAnchorToml).first
            ?? "REPLACE_WITH_REVIEWED_PROGRAM_ID"
        return """
        import { PublicKey } from "@solana/web3.js";

        // Generated by KeySlot Frontend Assistant for \(projectName).
        // Review-only draft. It does not sign, send, or broadcast transactions.
        export const PROGRAM_ID = new PublicKey("\(programID)");
        export const PROGRAM_NAME = "\(idl.name)";
        export const KEYSLOT_BUILD_SEND_SEPARATION = true;
        """
    }

    private static func idlImportWrapper(idl: WorkstationIDL) -> String {
        let safeName = safeFileToken(idl.name)
        return """
        import idlJson from "../target/idl/\(safeName).json";
        import { PROGRAM_ID } from "./\(safeName)-constants";

        // Generated by KeySlot Frontend Assistant.
        // This wrapper only exposes IDL metadata and program constants.
        export const \(camelIdentifier(idl.name))Idl = idlJson;
        export const \(camelIdentifier(idl.name))ProgramId = PROGRAM_ID;
        export type \(pascalIdentifier(idl.name))Idl = typeof idlJson;
        """
    }

    private static func pdaHelper(idl: WorkstationIDL, projectBrain: DeveloperProjectBrain?) -> String {
        let candidates = projectBrain?.pdaCandidates.prefix(12).map { candidate -> String in
            let seeds = candidate.seeds.isEmpty ? "// Seeds are dynamic or unsupported; fill reviewed seed bytes here." : candidate.seeds.map { "// - \($0)" }.joined(separator: "\n")
            return """

            /**
             \(candidate.label)
             Source: \(candidate.sourceRelativePath ?? "unknown")
             \(seeds)
             */
            export function derive\(pascalIdentifier(candidate.label))Pda(reviewedSeeds: Buffer[], programId: PublicKey = PROGRAM_ID): [PublicKey, number] {
              return PublicKey.findProgramAddressSync(reviewedSeeds, programId);
            }
            """
        }.joined(separator: "\n") ?? ""
        let idlPdas = idl.instructions.flatMap { instruction in
            instruction.accounts.compactMap { account -> String? in
                guard let pda = account.pda else { return nil }
                return """

                // \(instruction.name).\(account.name): \(pda.summary)
                """
            }
        }.joined(separator: "\n")
        return """
        import { PublicKey } from "@solana/web3.js";
        import { PROGRAM_ID } from "./\(safeFileToken(idl.name))-constants";

        // Generated by KeySlot Frontend Assistant.
        // PDA helpers require reviewed seed bytes. No network calls or signing happen here.
        \(idlPdas)
        \(candidates.isEmpty ? "// No concrete Project Brain PDA candidates were available." : candidates)
        """
    }

    private static func instructionAccountMap(idl: WorkstationIDL, instruction: WorkstationIDLInstruction) -> String {
        let typeName = "\(pascalIdentifier(instruction.name))Accounts"
        let fields = instruction.accounts.map { account in
            "  \(camelIdentifier(account.name)): PublicKey; // signer: \(account.isSigner), writable: \(account.isMut)"
        }.joined(separator: "\n")
        let object = instruction.accounts.map { account in
            "    \(camelIdentifier(account.name)): accounts.\(camelIdentifier(account.name)),"
        }.joined(separator: "\n")
        return """
        import { PublicKey } from "@solana/web3.js";

        // Generated by KeySlot Frontend Assistant for \(idl.name).\(instruction.name).
        // Account maps are build-only. Signing and sending must happen in a reviewed wallet flow.
        export type \(typeName) = {
        \(fields)
        };

        export function build\(typeName)(accounts: \(typeName)) {
          return {
        \(object)
          };
        }
        """
    }

    private static func reactHookDraft(idl: WorkstationIDL, instruction: WorkstationIDLInstruction, dependencyStyle: String) -> String {
        let argsType = "\(pascalIdentifier(instruction.name))Args"
        let accountsType = "\(pascalIdentifier(instruction.name))Accounts"
        let mappedArgs = instruction.args.map { "  \(camelIdentifier($0.name)): \(typescriptType(for: $0.type));" }.joined(separator: "\n")
        let args = mappedArgs.isEmpty ? "  // No IDL args detected." : mappedArgs
        return """
        import { useMemo } from "react";
        import { PublicKey, TransactionInstruction } from "@solana/web3.js";
        import { PROGRAM_ID } from "./\(safeFileToken(idl.name))-constants";
        import { build\(accountsType) } from "./\(safeFileToken(instruction.name))-accounts";

        export type \(argsType) = {
        \(args)
        };

        export type \(accountsType) = Record<string, PublicKey>;

        // Generated by KeySlot Frontend Assistant using \(dependencyStyle).
        // This hook prepares build-only data. It never signs or broadcasts.
        export function useBuild\(pascalIdentifier(instruction.name))Instruction(args: \(argsType), accounts: \(accountsType)) {
          return useMemo(() => {
            const accountMap = build\(accountsType)(accounts as never);
            return {
              programId: PROGRAM_ID,
              instructionName: "\(instruction.name)",
              args,
              accounts: accountMap,
              buildInstruction: (): TransactionInstruction => {
                throw new Error("Draft only: encode instruction data with your reviewed client before signing elsewhere.");
              },
            };
          }, [args, accounts]);
        }
        """
    }

    private static func expectedProgramIDs(projectBrain: DeveloperProjectBrain?, idl: WorkstationIDL?) -> [String] {
        var ids = Set<String>()
        if let address = idl?.address, SolanaAddressValidator.isValidAddress(address) {
            ids.insert(address)
        }
        for program in projectBrain?.programs ?? [] {
            [program.programIdFromDeclareId, program.programIdFromAnchorToml, program.programIdFromIdl].compactMap { $0 }.forEach {
                if SolanaAddressValidator.isValidAddress($0) { ids.insert($0) }
            }
        }
        return Array(ids).sorted()
    }

    private static func captureBase58Strings(_ text: String) -> [(value: String, line: Int, context: String)] {
        let pattern = #""([1-9A-HJ-NP-Za-km-z]{20,60})""#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsText = text as NSString
        return (regex?.matches(in: text, range: NSRange(location: 0, length: nsText.length)) ?? []).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let value = nsText.substring(with: match.range(at: 1))
            let line = nsText.substring(to: match.range.location).components(separatedBy: .newlines).count
            let lineText = text.components(separatedBy: .newlines).dropFirst(max(0, line - 1)).first ?? value
            return (value, line, WorkstationCommandRunner.safeSummary(lineText))
        }
    }

    private static func looksLikeProgramIDContext(_ context: String) -> Bool {
        let lower = context.lowercased()
        return lower.contains("program")
            || lower.contains("programid")
            || lower.contains("publickey")
            || lower.contains("anchorprovider")
            || lower.contains("new publickey")
    }

    private static func typescriptType(for idlType: String) -> String {
        switch idlType {
        case "u64", "u128", "i64", "i128":
            return "bigint"
        case "u8", "u16", "u32", "i8", "i16", "i32":
            return "number"
        case "bool":
            return "boolean"
        case "string":
            return "string"
        case "pubkey", "publicKey", "PublicKey":
            return "PublicKey"
        default:
            return "unknown"
        }
    }

    private static func existingFile(root: URL, relativePath: String, fileManager: FileManager) -> URL? {
        let url = root.appendingPathComponent(relativePath).standardizedFileURL
        guard url.path.hasPrefix(root.path + "/"), fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    private static func isSafeRoot(_ path: String) -> Bool {
        path.hasPrefix("/")
            && !path.contains("..")
            && !path.contains(";")
            && !path.contains("|")
            && !path.contains("&")
            && !path.contains("`")
    }

    private static func shouldSkipDirectory(_ relativePath: String) -> Bool {
        let first = relativePath.split(separator: "/").first.map(String.init) ?? ""
        return [".git", ".build", ".anchor", "node_modules", "target", "dist", "build", ".next", ".turbo"].contains(first)
    }

    private static func isFrontendCandidatePath(_ relativePath: String) -> Bool {
        relativePath == "package.json"
            || relativePath.hasSuffix(".ts")
            || relativePath.hasSuffix(".tsx")
            || relativePath.hasSuffix(".js")
            || relativePath.hasSuffix(".jsx")
            || relativePath.hasSuffix(".json")
    }

    private static func relativePath(root: URL, url: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path.hasPrefix(rootPath) else {
            return url.lastPathComponent
        }
        return DeveloperProjectBrainPath.cleanRelativePath(String(url.path.dropFirst(rootPath.count)))
    }

    private static func safeFileToken(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return cleaned.isEmpty ? "program" : cleaned
    }

    private static func camelIdentifier(_ value: String) -> String {
        let parts = value.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        guard let first = parts.first else { return "value" }
        return ([first.lowercased()] + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }).joined()
    }

    private static func pascalIdentifier(_ value: String) -> String {
        let camel = camelIdentifier(value)
        return camel.prefix(1).uppercased() + camel.dropFirst()
    }
}

struct FrontendAssistantEvidenceStore {
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

    func load() -> [FrontendGenerationEvidence] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([FrontendGenerationEvidence].self, from: data)) ?? []
    }

    func append(_ evidence: FrontendGenerationEvidence) throws -> [FrontendGenerationEvidence] {
        var entries = load()
        entries.insert(evidence, at: 0)
        entries = Array(entries.prefix(50))
        try save(entries)
        return entries
    }

    func save(_ entries: [FrontendGenerationEvidence]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: [.atomic])
    }

    func exportJSON(_ evidence: FrontendGenerationEvidence) throws -> String {
        let data = try encoder.encode(evidence)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("KeySlot", isDirectory: true)
            .appendingPathComponent("DeveloperWorkstation", isDirectory: true)
            .appendingPathComponent("frontend-assistant-evidence.json")
    }
}

private struct FrontendSourceFile {
    let url: URL
    let relativePath: String
    let byteCount: Int
}

private extension Array where Element == FrontendIntegrationFinding {
    func deduplicatedFrontendFindings() -> [FrontendIntegrationFinding] {
        var seen = Set<String>()
        return filter { finding in
            let key = "\(finding.id):\(finding.sourceRelativePath ?? ""):\(finding.line ?? 0)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
}
