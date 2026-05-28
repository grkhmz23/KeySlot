import Foundation

enum SecurityFindingSeverity: String, Codable, CaseIterable, Identifiable {
    case info
    case low
    case medium
    case high

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum SecurityFindingConfidence: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum SecurityFindingStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case dismissed

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct SecurityFinding: Codable, Equatable, Identifiable {
    let id: String
    let severity: SecurityFindingSeverity
    let confidence: SecurityFindingConfidence
    let category: String
    let title: String
    let detail: String
    let sourceRelativePath: String?
    let sourceLineStart: Int?
    let relatedInstruction: String?
    let relatedAccount: String?
    let evidence: String
    let suggestedFix: String
    var falsePositiveReason: String?
    var status: SecurityFindingStatus

    init(
        id: String,
        severity: SecurityFindingSeverity,
        confidence: SecurityFindingConfidence,
        category: String,
        title: String,
        detail: String,
        sourceRelativePath: String? = nil,
        sourceLineStart: Int? = nil,
        relatedInstruction: String? = nil,
        relatedAccount: String? = nil,
        evidence: String,
        suggestedFix: String,
        falsePositiveReason: String? = nil,
        status: SecurityFindingStatus = .open
    ) {
        self.id = WorkstationCommandRunner.safeSummary(id)
        self.severity = severity
        self.confidence = confidence
        self.category = WorkstationCommandRunner.safeSummary(category)
        self.title = WorkstationCommandRunner.safeSummary(title)
        self.detail = WorkstationCommandRunner.safeSummary(detail)
        self.sourceRelativePath = sourceRelativePath.map(DeveloperProjectBrainPath.cleanRelativePath)
        self.sourceLineStart = sourceLineStart
        self.relatedInstruction = relatedInstruction.map(WorkstationCommandRunner.safeSummary)
        self.relatedAccount = relatedAccount.map(WorkstationCommandRunner.safeSummary)
        self.evidence = WorkstationCommandRunner.safeSummary(evidence)
        self.suggestedFix = WorkstationCommandRunner.safeSummary(suggestedFix)
        self.falsePositiveReason = falsePositiveReason.map(WorkstationCommandRunner.safeSummary)
        self.status = status
    }

    func dismissed(reason: String) -> SecurityFinding {
        var copy = self
        copy.status = .dismissed
        copy.falsePositiveReason = WorkstationCommandRunner.safeSummary(reason)
        return copy
    }
}

struct SecurityScanReport: Codable, Equatable, Identifiable {
    let id: UUID
    let projectId: String?
    let projectName: String
    let projectRootDisplay: String
    let generatedAt: Date
    let readOnly: Bool
    let scannedFileCount: Int
    let sourceLineCount: Int
    let projectBrainId: UUID?
    let findings: [SecurityFinding]
    let unsupportedFindings: [UnsupportedFinding]
    let summary: String

    init(
        id: UUID = UUID(),
        projectId: String?,
        projectName: String,
        projectRootDisplay: String,
        generatedAt: Date = Date(),
        readOnly: Bool = true,
        scannedFileCount: Int,
        sourceLineCount: Int,
        projectBrainId: UUID?,
        findings: [SecurityFinding],
        unsupportedFindings: [UnsupportedFinding] = [],
        summary: String
    ) {
        self.id = id
        self.projectId = projectId.map(WorkstationCommandRunner.safeSummary)
        self.projectName = WorkstationCommandRunner.safeSummary(projectName)
        self.projectRootDisplay = DeveloperProjectBrainPath.display(path: projectRootDisplay)
        self.generatedAt = generatedAt
        self.readOnly = readOnly
        self.scannedFileCount = scannedFileCount
        self.sourceLineCount = sourceLineCount
        self.projectBrainId = projectBrainId
        self.findings = findings
        self.unsupportedFindings = unsupportedFindings
        self.summary = WorkstationCommandRunner.safeSummary(summary)
    }

    var openFindings: [SecurityFinding] {
        findings.filter { $0.status == .open }
    }

    func count(_ severity: SecurityFindingSeverity) -> Int {
        openFindings.filter { $0.severity == severity }.count
    }
}

enum SecurityScannerError: LocalizedError, Equatable {
    case missingProject
    case unsupportedSource(String)
    case unsafeProjectRoot
    case missingProjectRoot

    var errorDescription: String? {
        switch self {
        case .missingProject:
            return "Import a folder project before running Security Scanner."
        case .unsupportedSource(let source):
            return "Security Scanner reads folder projects only. \(source) imports remain unsupported until extracted by a reviewed safe flow."
        case .unsafeProjectRoot:
            return "Project root failed safety validation."
        case .missingProjectRoot:
            return "Project root is unavailable."
        }
    }
}

enum SecurityScannerService {
    private static let maxFiles = 650
    private static let maxFileBytes = 512 * 1024
    private static let allowedExtensions = Set(["rs", "ts", "tsx", "js", "jsx"])
    private static let skippedDirectories = Set([".git", ".build", ".anchor", "node_modules", "target", "dist", "build", ".turbo", ".next"])

    static func scan(
        project: WorkstationProject?,
        projectBrain: DeveloperProjectBrain?,
        idl: WorkstationIDL?,
        releaseRecords: [WorkstationDeploymentReleaseRecord] = [],
        fileManager: FileManager = .default
    ) throws -> SecurityScanReport {
        guard let project else {
            throw SecurityScannerError.missingProject
        }
        guard project.sourceType == .folder else {
            throw SecurityScannerError.unsupportedSource(project.sourceType.rawValue)
        }

        let root = URL(fileURLWithPath: project.localPath, isDirectory: true).standardizedFileURL
        guard WorkstationProjectImporter(fileManager: fileManager).isSafeLocalPath(root.path) else {
            throw SecurityScannerError.unsafeProjectRoot
        }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw SecurityScannerError.missingProjectRoot
        }

        let files = collectSourceFiles(root: root, fileManager: fileManager)
        var findings: [SecurityFinding] = []
        for file in files {
            findings.append(contentsOf: scanRustFile(file))
            findings.append(contentsOf: scanClientFile(file, idl: idl, projectBrain: projectBrain))
        }
        findings.append(contentsOf: projectBrainFindings(projectBrain))
        findings.append(contentsOf: releaseFindings(projectBrain: projectBrain, releaseRecords: releaseRecords))

        let unsupported = files.count >= maxFiles
            ? [UnsupportedFinding(id: "scan-file-limit", title: "Scan reached file limit", reason: "Security Scanner read \(maxFiles) source files and stopped to keep the read-only scan bounded.")]
            : []
        let sorted = findings.deduplicatedSecurityFindings().sorted { lhs, rhs in
            if lhs.severity.weight != rhs.severity.weight { return lhs.severity.weight > rhs.severity.weight }
            return lhs.id < rhs.id
        }
        let lineCount = files.reduce(0) { $0 + $1.lines.count }
        return SecurityScanReport(
            projectId: project.id.uuidString,
            projectName: project.displayName,
            projectRootDisplay: project.localPath,
            scannedFileCount: files.count,
            sourceLineCount: lineCount,
            projectBrainId: projectBrain?.id,
            findings: sorted,
            unsupportedFindings: unsupported,
            summary: "Developer Review Assistant found \(sorted.count) potential issue(s) in \(files.count) source file(s) using conservative static checks. This is not a formal audit and can miss vulnerabilities or produce false positives."
        )
    }

    private static func collectSourceFiles(root: URL, fileManager: FileManager) -> [SecuritySourceFile] {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var files: [SecuritySourceFile] = []
        for case let url as URL in enumerator {
            if files.count >= maxFiles { break }
            let standardized = url.standardizedFileURL
            guard standardized.path.hasPrefix(rootPath) else { continue }
            guard let values = try? standardized.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]) else {
                continue
            }
            if values.isSymbolicLink == true {
                if values.isDirectory == true { enumerator.skipDescendants() }
                continue
            }
            if values.isDirectory == true {
                if skippedDirectories.contains(standardized.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values.isRegularFile == true,
                  allowedExtensions.contains(standardized.pathExtension.lowercased()),
                  (values.fileSize ?? 0) <= maxFileBytes,
                  let text = try? String(contentsOf: standardized, encoding: .utf8) else {
                continue
            }
            let relative = DeveloperProjectBrainPath.cleanRelativePath(String(standardized.path.dropFirst(rootPath.count)))
            files.append(SecuritySourceFile(relativePath: relative, text: text))
        }
        return files
    }

    private static func scanRustFile(_ file: SecuritySourceFile) -> [SecurityFinding] {
        guard file.isRust else { return [] }
        var findings: [SecurityFinding] = []
        for (offset, line) in file.lines.enumerated() {
            let lineNumber = offset + 1
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let context = file.context(around: offset)
            let contextLower = context.lowercased()
            let immediateContextLower = file.context(around: offset, radius: 2).lowercased()
            let lineLower = trimmed.lowercased()
            guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("use ") else { continue }

            if lineLower.contains("seeds") && !contextLower.contains("bump") {
                findings.append(finding(
                    id: "pda-missing-bump-\(file.relativePath)-\(lineNumber)",
                    severity: .medium,
                    confidence: .medium,
                    category: "PDA/account validation",
                    title: "PDA seeds without nearby bump validation",
                    detail: "Seeds were detected without a nearby bump constraint or bump usage. This may be valid, but PDA accounts usually need explicit bump validation.",
                    file: file,
                    line: lineNumber,
                    evidence: trimmed,
                    suggestedFix: "If this is an Anchor PDA account, add an explicit `bump` constraint or document why the bump is validated elsewhere."
                ))
            }

            if isUncheckedAccountLine(lineLower), !hasValidationIndicator(immediateContextLower) {
                findings.append(finding(
                    id: "unchecked-account-\(file.relativePath)-\(lineNumber)",
                    severity: .medium,
                    confidence: .medium,
                    category: "PDA/account validation",
                    title: "Unchecked account with weak validation indicators",
                    detail: "`AccountInfo` or `UncheckedAccount` appears without nearby owner/address/seeds/constraint validation indicators.",
                    file: file,
                    line: lineNumber,
                    relatedAccount: accountName(from: trimmed),
                    evidence: trimmed,
                    suggestedFix: "Prefer typed Anchor accounts or add explicit owner/address/key checks with clear constraints."
                ))
            } else if isUncheckedAccountLine(lineLower), !immediateContextLower.contains("owner") {
                findings.append(finding(
                    id: "unchecked-owner-\(file.relativePath)-\(lineNumber)",
                    severity: .low,
                    confidence: .medium,
                    category: "PDA/account validation",
                    title: "Unchecked account owner validation not obvious",
                    detail: "The account is unchecked and nearby source does not show an owner check.",
                    file: file,
                    line: lineNumber,
                    relatedAccount: accountName(from: trimmed),
                    evidence: trimmed,
                    suggestedFix: "Confirm owner validation is enforced by Anchor constraints or explicit runtime checks."
                ))
            }

            if lineLower.contains("tokenaccount") && contextLower.contains("#[account") &&
                !contextLower.contains("token::mint") && !contextLower.contains("token::authority") && !contextLower.contains("associated_token::") {
                findings.append(finding(
                    id: "token-constraints-\(file.relativePath)-\(lineNumber)",
                    severity: .medium,
                    confidence: .medium,
                    category: "Anchor constraints",
                    title: "Token account constraints are not obvious",
                    detail: "A token account field was detected without nearby `token::mint`, `token::authority`, or associated-token constraints.",
                    file: file,
                    line: lineNumber,
                    relatedAccount: accountName(from: trimmed),
                    evidence: trimmed,
                    suggestedFix: "Add explicit token mint/authority constraints or verify they are enforced elsewhere."
                ))
            }

            if isAuthoritySensitive(lineLower), !lineLower.contains("signer<") && !lineLower.contains("program<") {
                findings.append(finding(
                    id: "authority-weak-\(file.relativePath)-\(lineNumber)",
                    severity: .medium,
                    confidence: .medium,
                    category: "Anchor constraints",
                    title: "Authority-sensitive account is not obviously a signer",
                    detail: "An authority/admin/owner account name appears without an obvious `Signer` type.",
                    file: file,
                    line: lineNumber,
                    relatedAccount: accountName(from: trimmed),
                    evidence: trimmed,
                    suggestedFix: "Require the authority account to sign or document how the authority relationship is enforced."
                ))
            }

            if suggestsMissingHasOne(lineLower, contextLower) {
                findings.append(finding(
                    id: "missing-has-one-\(file.relativePath)-\(lineNumber)",
                    severity: .low,
                    confidence: .low,
                    category: "Anchor constraints",
                    title: "`has_one` relationship may be missing",
                    detail: "A state/config account appears near an authority signer, but no nearby `has_one` relationship was found.",
                    file: file,
                    line: lineNumber,
                    relatedAccount: accountName(from: trimmed),
                    evidence: trimmed,
                    suggestedFix: "If the account stores an authority field, add `has_one = authority` or an equivalent explicit check."
                ))
            }

            if hasUncheckedArithmetic(lineLower) {
                findings.append(finding(
                    id: "unchecked-arithmetic-\(file.relativePath)-\(lineNumber)",
                    severity: .medium,
                    confidence: .medium,
                    category: "Arithmetic",
                    title: "Potential unchecked arithmetic",
                    detail: "A direct arithmetic operation was detected without an obvious checked/saturating/wrapping helper.",
                    file: file,
                    line: lineNumber,
                    evidence: trimmed,
                    suggestedFix: "Use checked arithmetic and handle overflow errors explicitly."
                ))
            }

            if hasNarrowingCast(lineLower) {
                findings.append(finding(
                    id: "narrowing-cast-\(file.relativePath)-\(lineNumber)",
                    severity: .medium,
                    confidence: .medium,
                    category: "Arithmetic",
                    title: "Potential narrowing integer cast",
                    detail: "A cast to a smaller integer type was detected. This can truncate values if not range-checked first.",
                    file: file,
                    line: lineNumber,
                    evidence: trimmed,
                    suggestedFix: "Use `try_from` or validate the value range before casting."
                ))
            }

            if lineLower.contains("f32") || lineLower.contains("f64") || lineLower.contains(" as f32") || lineLower.contains(" as f64") {
                findings.append(finding(
                    id: "float-onchain-\(file.relativePath)-\(lineNumber)",
                    severity: .high,
                    confidence: .high,
                    category: "Arithmetic",
                    title: "Floating point usage in on-chain Rust source",
                    detail: "Floating point arithmetic is usually unsuitable for deterministic Solana program logic.",
                    file: file,
                    line: lineNumber,
                    evidence: trimmed,
                    suggestedFix: "Use fixed-point integer math with explicit scale and checked arithmetic."
                ))
            }

            if (lineLower.contains("invoke(") || lineLower.contains("invoke_signed(")) && !hasValidationIndicator(contextLower) {
                findings.append(finding(
                    id: "cpi-validation-\(file.relativePath)-\(lineNumber)",
                    severity: .medium,
                    confidence: .medium,
                    category: "CPI safety",
                    title: "CPI call with weak program validation indicators",
                    detail: "A CPI invocation was detected without nearby typed program or key validation indicators.",
                    file: file,
                    line: lineNumber,
                    evidence: trimmed,
                    suggestedFix: "Use typed `Program<'info, ...>` accounts or validate the invoked program id explicitly before CPI."
                ))
            }

            if lineLower.contains("program") && isUncheckedAccountLine(lineLower) {
                findings.append(finding(
                    id: "unchecked-program-account-\(file.relativePath)-\(lineNumber)",
                    severity: .medium,
                    confidence: .medium,
                    category: "CPI safety",
                    title: "External program account is unchecked",
                    detail: "A program-like account is modeled as `AccountInfo` or `UncheckedAccount`.",
                    file: file,
                    line: lineNumber,
                    relatedAccount: accountName(from: trimmed),
                    evidence: trimmed,
                    suggestedFix: "Prefer typed program accounts or verify the program id with an address constraint."
                ))
            }

            if lineLower.contains("#[account") && lineLower.contains("init") &&
                !lineLower.contains("seeds") && !lineLower.contains("associated_token") {
                findings.append(finding(
                    id: "init-uniqueness-\(file.relativePath)-\(lineNumber)",
                    severity: .low,
                    confidence: .low,
                    category: "Reinitialization/close",
                    title: "Init account uniqueness is not obvious",
                    detail: "`init` was detected without an obvious PDA seed or associated-token uniqueness constraint.",
                    file: file,
                    line: lineNumber,
                    evidence: trimmed,
                    suggestedFix: "Confirm account uniqueness is enforced by PDA seeds, address constraints, or an equivalent invariant."
                ))
            }

            if lineLower.contains("close ="), let closeTarget = closeTarget(from: trimmed), !isLikelySafeCloseTarget(closeTarget) {
                findings.append(finding(
                    id: "close-destination-\(file.relativePath)-\(lineNumber)",
                    severity: .medium,
                    confidence: .medium,
                    category: "Reinitialization/close",
                    title: "Close destination authority is not obvious",
                    detail: "A close destination was detected, but its name does not clearly indicate authority/signer ownership.",
                    file: file,
                    line: lineNumber,
                    relatedAccount: closeTarget,
                    evidence: trimmed,
                    suggestedFix: "Ensure closed lamports go to the expected signer/authority and add explicit constraints if needed."
                ))
            }
        }
        return findings
    }

    private static func scanClientFile(_ file: SecuritySourceFile, idl: WorkstationIDL?, projectBrain: DeveloperProjectBrain?) -> [SecurityFinding] {
        guard file.isClient else { return [] }
        var findings: [SecurityFinding] = []
        let bigIntegerArgs = idl?.instructions.flatMap { instruction in
            instruction.args
                .filter { isBigIntegerIDLType($0.type) }
                .map { (instruction.name, $0.name, $0.type) }
        } ?? []

        for (offset, line) in file.lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lineLower = trimmed.lowercased()
            guard !trimmed.hasPrefix("//") else { continue }
            let lineNumber = offset + 1
            for arg in bigIntegerArgs where lineLower.contains(arg.1.lowercased()) && lineLower.contains(": number") {
                findings.append(finding(
                    id: "ts-number-\(file.relativePath)-\(lineNumber)-\(arg.1)",
                    severity: .medium,
                    confidence: .high,
                    category: "Client safety",
                    title: "TypeScript `number` used for large integer IDL arg",
                    detail: "IDL argument `\(arg.1)` is `\(arg.2)`, but client source appears to type it as `number`.",
                    file: file,
                    line: lineNumber,
                    relatedInstruction: arg.0,
                    evidence: trimmed,
                    suggestedFix: "Use BN, bigint, or the client library's expected large-integer type instead of JavaScript `number`."
                ))
            }

            if lineLower.contains("program") || lineLower.contains("program_id") || lineLower.contains("programid") {
                for publicKey in publicKeys(in: trimmed) {
                    let expected = expectedProgramIDs(projectBrain: projectBrain, idl: idl)
                    if !expected.isEmpty, !expected.contains(publicKey) {
                        findings.append(finding(
                            id: "client-program-mismatch-\(file.relativePath)-\(lineNumber)-\(publicKey)",
                            severity: .medium,
                            confidence: .medium,
                            category: "Client safety",
                            title: "Hardcoded client program id may drift from project metadata",
                            detail: "A client-side program id does not match the loaded IDL/Project Brain program ids.",
                            file: file,
                            line: lineNumber,
                            evidence: trimmed,
                            suggestedFix: "Compare the client program id against Anchor.toml, `declare_id!`, and IDL metadata before release."
                        ))
                    }
                }
            }
        }
        return findings
    }

    private static func projectBrainFindings(_ brain: DeveloperProjectBrain?) -> [SecurityFinding] {
        guard let brain else { return [] }
        var findings: [SecurityFinding] = []
        for warning in brain.warnings where warning.category.lowercased().contains("program") || warning.title.lowercased().contains("mismatch") {
            findings.append(SecurityFinding(
                id: "brain-\(warning.id)",
                severity: warning.severity == .high ? .high : .medium,
                confidence: .high,
                category: "Deployment configuration",
                title: warning.title,
                detail: warning.detail,
                sourceRelativePath: warning.sourceRelativePath,
                sourceLineStart: warning.line,
                evidence: warning.detail,
                suggestedFix: warning.suggestedAction
            ))
        }
        return findings
    }

    private static func releaseFindings(projectBrain: DeveloperProjectBrain?, releaseRecords: [WorkstationDeploymentReleaseRecord]) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []
        let hasArtifacts = projectBrain?.programs.contains { !$0.deployArtifacts.isEmpty } ?? false
        if hasArtifacts, releaseRecords.isEmpty {
            findings.append(SecurityFinding(
                id: "release-hash-missing",
                severity: .low,
                confidence: .medium,
                category: "Upgrade/deployment",
                title: "Deploy artifact exists without release record hash",
                detail: "Project Brain found deploy artifact paths, but no Deployment Release Manager record with artifact/IDL hashes is loaded.",
                evidence: projectBrain?.programs.flatMap(\.deployArtifacts).joined(separator: ", ") ?? "Deploy artifact detected",
                suggestedFix: "After a real localnet/devnet deploy, create a release record so artifact and IDL SHA-256 hashes are preserved."
            ))
        }
        for record in releaseRecords where record.status == .succeeded && record.upgradeAuthorityPubkey == nil {
            findings.append(SecurityFinding(
                id: "release-authority-missing-\(record.id.uuidString)",
                severity: .low,
                confidence: .medium,
                category: "Upgrade/deployment",
                title: "Upgrade authority not recorded in release evidence",
                detail: "A successful release record exists, but the upgrade authority public key is unavailable.",
                evidence: record.programId ?? record.commandSummary,
                suggestedFix: "Run fixed `solana program show` for localnet/devnet and record the upgrade authority public key when available."
            ))
        }
        return findings
    }

    private static func finding(
        id: String,
        severity: SecurityFindingSeverity,
        confidence: SecurityFindingConfidence,
        category: String,
        title: String,
        detail: String,
        file: SecuritySourceFile,
        line: Int,
        relatedInstruction: String? = nil,
        relatedAccount: String? = nil,
        evidence: String,
        suggestedFix: String
    ) -> SecurityFinding {
        SecurityFinding(
            id: id,
            severity: severity,
            confidence: confidence,
            category: category,
            title: title,
            detail: detail,
            sourceRelativePath: file.relativePath,
            sourceLineStart: line,
            relatedInstruction: relatedInstruction,
            relatedAccount: relatedAccount,
            evidence: evidence,
            suggestedFix: suggestedFix
        )
    }

    private static func isUncheckedAccountLine(_ lower: String) -> Bool {
        lower.contains("uncheckedaccount") || lower.contains("accountinfo")
    }

    private static func hasValidationIndicator(_ lower: String) -> Bool {
        ["constraint", "owner", "address =", "has_one", "require_keys_eq", "program<", "seeds", "token::", "associated_token::", ".key() =="]
            .contains { lower.contains($0) }
    }

    private static func isAuthoritySensitive(_ lower: String) -> Bool {
        (lower.contains("pub authority") || lower.contains("pub admin") || lower.contains("pub owner")) &&
            (lower.contains("uncheckedaccount") || lower.contains("accountinfo") || lower.contains("account<"))
    }

    private static func suggestsMissingHasOne(_ lower: String, _ context: String) -> Bool {
        (lower.contains("pub state") || lower.contains("pub config") || lower.contains("pub vault")) &&
            lower.contains("account<") &&
            context.contains("authority") &&
            !context.contains("has_one")
    }

    private static func hasUncheckedArithmetic(_ lower: String) -> Bool {
        guard !lower.contains("checked_"), !lower.contains("saturating_"), !lower.contains("wrapping_") else {
            return false
        }
        if lower.contains("+=") || lower.contains("-=") || lower.contains("*=") { return true }
        guard lower.contains("="), lower.contains(";") else { return false }
        return lower.contains(" + ") || lower.contains(" - ") || lower.contains(" * ")
    }

    private static func hasNarrowingCast(_ lower: String) -> Bool {
        [" as u8", " as u16", " as u32", " as i8", " as i16", " as i32"].contains { lower.contains($0) }
    }

    private static func closeTarget(from line: String) -> String? {
        guard let range = line.range(of: #"close\s*=\s*([A-Za-z_][A-Za-z0-9_]*)"#, options: .regularExpression) else {
            return nil
        }
        let fragment = String(line[range])
        return fragment
            .components(separatedBy: "=")
            .last?
            .trimmingCharacters(in: CharacterSet(charactersIn: " )],"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isLikelySafeCloseTarget(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.contains("authority") || lower.contains("owner") || lower.contains("signer") || lower.contains("payer") || lower.contains("admin")
    }

    private static func accountName(from line: String) -> String? {
        guard let range = line.range(of: #"pub\s+([A-Za-z_][A-Za-z0-9_]*)\s*:"#, options: .regularExpression) else {
            return nil
        }
        let fragment = String(line[range])
        return fragment
            .replacingOccurrences(of: "pub", with: "")
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isBigIntegerIDLType(_ type: String) -> Bool {
        let lower = type.lowercased()
        return ["u64", "u128", "i64", "i128"].contains(lower)
    }

    private static func expectedProgramIDs(projectBrain: DeveloperProjectBrain?, idl: WorkstationIDL?) -> Set<String> {
        var ids = Set<String>()
        if let address = idl?.address, SolanaAddressValidator.isValidAddress(address) { ids.insert(address) }
        for program in projectBrain?.programs ?? [] {
            [program.programIdFromDeclareId, program.programIdFromAnchorToml, program.programIdFromIdl].compactMap { $0 }.forEach {
                if SolanaAddressValidator.isValidAddress($0) { ids.insert($0) }
            }
        }
        return ids
    }

    private static func publicKeys(in line: String) -> [String] {
        let pattern = #"[1-9A-HJ-NP-Za-km-z]{32,44}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: line) else { return nil }
            let candidate = String(line[swiftRange])
            return SolanaAddressValidator.isValidAddress(candidate) ? candidate : nil
        }
    }
}

final class SecurityScanEvidenceStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("KeySlot/DeveloperWorkstation", isDirectory: true)
            ?? fileManager.temporaryDirectory.appendingPathComponent("KeySlot/DeveloperWorkstation", isDirectory: true)
        self.fileURL = fileURL ?? base.appendingPathComponent("security-scan-reports.json")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [SecurityScanReport] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([SecurityScanReport].self, from: data)) ?? []
    }

    func append(_ report: SecurityScanReport) throws -> [SecurityScanReport] {
        var reports = load()
        reports.insert(report, at: 0)
        reports = Array(reports.prefix(100))
        try save(reports)
        return reports
    }

    func save(_ reports: [SecurityScanReport]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(reports)
        try data.write(to: fileURL, options: [.atomic])
    }

    func exportJSON(_ report: SecurityScanReport) throws -> String {
        let data = try encoder.encode(report)
        return WorkstationCommandRunner.safeSummary(String(data: data, encoding: .utf8) ?? "{}")
    }
}

private struct SecuritySourceFile {
    let relativePath: String
    let text: String
    let lines: [String]

    init(relativePath: String, text: String) {
        self.relativePath = DeveloperProjectBrainPath.cleanRelativePath(relativePath)
        self.text = text
        self.lines = text.components(separatedBy: .newlines)
    }

    var isRust: Bool { relativePath.hasSuffix(".rs") }
    var isClient: Bool {
        relativePath.hasSuffix(".ts") ||
            relativePath.hasSuffix(".tsx") ||
            relativePath.hasSuffix(".js") ||
            relativePath.hasSuffix(".jsx")
    }

    func context(around index: Int, radius: Int = 5) -> String {
        let lower = max(0, index - radius)
        let upper = min(lines.count - 1, index + radius)
        guard lower <= upper else { return "" }
        return lines[lower...upper].joined(separator: "\n")
    }
}

private extension SecurityFindingSeverity {
    var weight: Int {
        switch self {
        case .info: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
}

private extension Array where Element == SecurityFinding {
    func deduplicatedSecurityFindings() -> [SecurityFinding] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}
