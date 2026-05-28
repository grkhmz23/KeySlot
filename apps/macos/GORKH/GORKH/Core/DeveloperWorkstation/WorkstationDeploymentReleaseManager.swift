import CryptoKit
import Foundation

enum WorkstationProgramManagerTab: String, Codable, CaseIterable, Identifiable {
    case buildDeploy = "build_deploy"
    case upgradePreview = "upgrade_preview"
    case authorityPreview = "authority_preview"
    case releaseRecords = "release_records"
    case preflightChecks = "preflight_checks"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buildDeploy:
            return "Build / Deploy"
        case .upgradePreview:
            return "Upgrade Preview"
        case .authorityPreview:
            return "Authority Preview"
        case .releaseRecords:
            return "Release Records"
        case .preflightChecks:
            return "Preflight Checks"
        }
    }
}

enum WorkstationDeploymentPreflightStatus: String, Codable, Equatable {
    case passed
    case warning
    case blocked
    case unavailable

    var title: String {
        switch self {
        case .passed:
            return "Passed"
        case .warning:
            return "Warning"
        case .blocked:
            return "Blocked"
        case .unavailable:
            return "Unavailable"
        }
    }
}

struct WorkstationDeploymentPreflightCheck: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let status: WorkstationDeploymentPreflightStatus
    let detail: String

    init(id: String, title: String, status: WorkstationDeploymentPreflightStatus, detail: String) {
        self.id = id
        self.title = AgentSafetyRedactor.redact(title)
        self.status = status
        self.detail = WorkstationDeploymentReleaseService.safeText(detail, limit: 600)
    }
}

struct WorkstationDeploymentPreflightReport: Codable, Equatable, Identifiable {
    let id: UUID
    let generatedAt: Date
    let operation: WorkstationProgramOperation
    let cluster: WorkstationCluster
    let checks: [WorkstationDeploymentPreflightCheck]

    var isDeployReady: Bool {
        checks.contains { $0.status == .blocked } == false
    }

    var status: WorkstationDeploymentPreflightStatus {
        if checks.contains(where: { $0.status == .blocked }) {
            return .blocked
        }
        if checks.contains(where: { $0.status == .warning }) {
            return .warning
        }
        if checks.contains(where: { $0.status == .unavailable }) {
            return .unavailable
        }
        return .passed
    }

    var summary: String {
        "\(checks.filter { $0.status == .passed }.count) passed, \(checks.filter { $0.status == .warning }.count) warning(s), \(checks.filter { $0.status == .blocked }.count) blocked."
    }

    static let notRun = WorkstationDeploymentPreflightReport(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000D601")!,
        generatedAt: Date(timeIntervalSince1970: 0),
        operation: .solanaProgramDeploy,
        cluster: .localnet,
        checks: [
            WorkstationDeploymentPreflightCheck(
                id: "not-run",
                title: "Preflight not run",
                status: .unavailable,
                detail: "Run preflight after selecting a project, cluster, artifact, IDL, and fixed command preview."
            )
        ]
    )
}

struct WorkstationDeploymentPreflightInput: Codable, Equatable {
    let project: WorkstationProject?
    let cluster: WorkstationCluster
    let operation: WorkstationProgramOperation
    let toolchain: WorkstationToolchainSnapshot
    let developerWallet: DeveloperWalletMetadata?
    let selectedProgramID: String?
    let artifactPath: String?
    let idlPath: String?
    let idl: WorkstationIDL?
    let projectBrain: DeveloperProjectBrain?
    let idlDriftReport: WorkstationIDLDriftReport?
    let commandPreview: WorkstationCommandPlan?
    let explicitApprovalReady: Bool
    let tempKeypairPolicyReady: Bool
    let upgradeAuthorityPubkey: String?
}

struct WorkstationDeploymentReleaseRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let projectId: String?
    let projectName: String
    let cluster: WorkstationCluster
    let operation: WorkstationProgramOperation
    let programId: String?
    let signature: String?
    let gitCommit: String?
    let gitDirtyStatus: String
    let artifactPathSummary: String?
    let artifactHash: String?
    let idlPathSummary: String?
    let idlHash: String?
    let toolVersions: [String: String]
    let commandSummary: String
    let upgradeAuthorityPubkey: String?
    let createdAt: Date
    let evidenceId: UUID?
    let status: WorkstationProgramOperationEvidenceStatus
    let failureSummary: String?

    init(
        id: UUID = UUID(),
        projectId: String?,
        projectName: String,
        cluster: WorkstationCluster,
        operation: WorkstationProgramOperation,
        programId: String?,
        signature: String?,
        gitCommit: String?,
        gitDirtyStatus: String,
        artifactPathSummary: String?,
        artifactHash: String?,
        idlPathSummary: String?,
        idlHash: String?,
        toolVersions: [String: String],
        commandSummary: String,
        upgradeAuthorityPubkey: String?,
        createdAt: Date = Date(),
        evidenceId: UUID?,
        status: WorkstationProgramOperationEvidenceStatus,
        failureSummary: String?
    ) {
        self.id = id
        self.projectId = projectId.map { WorkstationDeploymentReleaseService.safeText($0, limit: 120) }
        self.projectName = WorkstationDeploymentReleaseService.safeText(projectName, limit: 160)
        self.cluster = cluster
        self.operation = operation
        self.programId = programId.flatMap(WorkstationDeploymentReleaseService.safePublicIdentifier)
        self.signature = signature.flatMap(WorkstationDeploymentReleaseService.safePublicIdentifier)
        self.gitCommit = gitCommit.flatMap(WorkstationDeploymentReleaseService.safePublicIdentifier)
        self.gitDirtyStatus = WorkstationDeploymentReleaseService.safeText(gitDirtyStatus, limit: 120)
        self.artifactPathSummary = artifactPathSummary.map(WorkstationDeploymentReleaseService.safePathSummary)
        self.artifactHash = artifactHash.flatMap(WorkstationDeploymentReleaseService.safeSHA256)
        self.idlPathSummary = idlPathSummary.map(WorkstationDeploymentReleaseService.safePathSummary)
        self.idlHash = idlHash.flatMap(WorkstationDeploymentReleaseService.safeSHA256)
        self.toolVersions = WorkstationDeploymentReleaseService.safeToolVersions(toolVersions)
        self.commandSummary = WorkstationDeploymentReleaseService.safeText(commandSummary, limit: 600)
        self.upgradeAuthorityPubkey = upgradeAuthorityPubkey.flatMap(WorkstationDeploymentReleaseService.safePublicIdentifier)
        self.createdAt = createdAt
        self.evidenceId = evidenceId
        self.status = status
        self.failureSummary = failureSummary.map { WorkstationDeploymentReleaseService.safeText($0, limit: 600) }
    }
}

struct WorkstationDeploymentReleasePayload: Codable, Equatable {
    var records: [WorkstationDeploymentReleaseRecord]
}

enum WorkstationDeploymentReleaseError: LocalizedError, Equatable {
    case missingEvidence
    case unsupportedOperation
    case unsafePath
    case unreadableFile(String)

    var errorDescription: String? {
        switch self {
        case .missingEvidence:
            return "Release record requires real program-operation evidence."
        case .unsupportedOperation:
            return "Release records are created for deploy or upgrade operations only."
        case .unsafePath:
            return "Release artifact or IDL path failed safety validation."
        case .unreadableFile(let path):
            return "Could not read file for release hash: \(path)."
        }
    }
}

enum WorkstationDeploymentReleaseService {
    static func preflight(_ input: WorkstationDeploymentPreflightInput) -> WorkstationDeploymentPreflightReport {
        let checks = [
            projectTrustCheck(input.project),
            clusterCheck(input.cluster),
            toolchainCheck(input.toolchain, operation: input.operation),
            developerWalletCheck(input.developerWallet, operation: input.operation),
            programIDConsistencyCheck(
                selectedProgramID: input.selectedProgramID,
                idl: input.idl,
                projectBrain: input.projectBrain
            ),
            artifactCheck(path: input.artifactPath, project: input.project, operation: input.operation),
            idlCheck(path: input.idlPath, idl: input.idl, projectBrain: input.projectBrain),
            idlDriftCheck(input.idlDriftReport, projectBrain: input.projectBrain),
            upgradeAuthorityCheck(input.upgradeAuthorityPubkey),
            devWalletBalanceCheck(cluster: input.cluster),
            tempKeypairCheck(input.tempKeypairPolicyReady),
            commandPreviewCheck(input.commandPreview),
            explicitApprovalCheck(input.explicitApprovalReady)
        ]
        return WorkstationDeploymentPreflightReport(
            id: UUID(),
            generatedAt: Date(),
            operation: input.operation,
            cluster: input.cluster,
            checks: checks
        )
    }

    static func makeReleaseRecord(
        evidence: WorkstationProgramOperationEvidence,
        project: WorkstationProject?,
        artifactURL: URL?,
        idlURL: URL?,
        gitCommit: String? = nil,
        gitDirtyStatus: String? = nil,
        upgradeAuthorityPubkey: String? = nil
    ) throws -> WorkstationDeploymentReleaseRecord {
        guard [.anchorDeploy, .solanaProgramDeploy, .solanaProgramUpgrade].contains(evidence.operation) else {
            throw WorkstationDeploymentReleaseError.unsupportedOperation
        }
        let artifactHash = try artifactURL.flatMap(fileSHA256Hex)
        let idlHash = try idlURL.flatMap(fileSHA256Hex)
        return WorkstationDeploymentReleaseRecord(
            projectId: evidence.projectID?.uuidString ?? project?.id.uuidString,
            projectName: project?.displayName ?? evidence.projectName,
            cluster: evidence.cluster,
            operation: evidence.operation,
            programId: evidence.programID,
            signature: evidence.signature,
            gitCommit: gitCommit,
            gitDirtyStatus: gitDirtyStatus ?? "Unavailable: fixed git metadata was not run.",
            artifactPathSummary: artifactURL?.path ?? evidence.artifactPath,
            artifactHash: artifactHash,
            idlPathSummary: idlURL?.path ?? evidence.idlPath,
            idlHash: idlHash,
            toolVersions: evidence.toolVersions,
            commandSummary: evidence.commandSummary,
            upgradeAuthorityPubkey: upgradeAuthorityPubkey,
            createdAt: Date(),
            evidenceId: evidence.id,
            status: evidence.status,
            failureSummary: evidence.status == .failed ? evidence.logSummary : nil
        )
    }

    nonisolated static func fileSHA256Hex(_ url: URL) throws -> String {
        guard isSafeReadablePath(url.path) else {
            throw WorkstationDeploymentReleaseError.unsafePath
        }
        guard let data = try? Data(contentsOf: url) else {
            throw WorkstationDeploymentReleaseError.unreadableFile(safePathSummary(url.path))
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func gitMetadataPlans(gitPath: String, projectPath: String) -> [WorkstationCommandPlan] {
        [
            WorkstationCommandBuilders.gitRevParseHead(gitPath: gitPath, projectPath: projectPath),
            WorkstationCommandBuilders.gitStatusPorcelain(gitPath: gitPath, projectPath: projectPath)
        ]
    }

    nonisolated static func safeText(_ text: String, limit: Int) -> String {
        let redacted = removeSensitiveLabels(AgentSafetyRedactor.redact(text.trimmingCharacters(in: .whitespacesAndNewlines)))
        if redacted.count <= limit {
            return redacted
        }
        return String(redacted.prefix(limit)) + "..."
    }

    nonisolated static func safePathSummary(_ path: String) -> String {
        let redacted = removeSensitiveLabels(AgentSafetyRedactor.redact(path))
        let components = redacted
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard components.count > 2 else {
            return redacted
        }
        return components.suffix(2).joined(separator: "/")
    }

    nonisolated static func safePublicIdentifier(_ value: String) -> String? {
        let trimmed = safeText(value, limit: 160)
        guard trimmed.isEmpty == false else {
            return nil
        }
        return trimmed
    }

    nonisolated static func safeSHA256(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: #"^[a-fA-F0-9]{64}$"#, options: .regularExpression) != nil else {
            return nil
        }
        return trimmed.lowercased()
    }

    nonisolated static func safeToolVersions(_ versions: [String: String]) -> [String: String] {
        versions.reduce(into: [:]) { partial, item in
            partial[safeText(item.key, limit: 80)] = safeText(item.value, limit: 160)
        }
    }

    nonisolated static func isSafeReadablePath(_ path: String) -> Bool {
        path.hasPrefix("/")
            && path.contains("..") == false
            && path.contains(";") == false
            && path.contains("|") == false
            && path.contains("&") == false
            && path.contains("`") == false
            && path.contains("$(") == false
    }

    private static func projectTrustCheck(_ project: WorkstationProject?) -> WorkstationDeploymentPreflightCheck {
        if project?.trustStatus == .trusted {
            return check("project-trust", "Project trusted", .passed, "The selected project has explicit trust.")
        }
        return check("project-trust", "Project trusted", .blocked, "Build/deploy remains blocked until the exact project trust phrase is accepted.")
    }

    private static func clusterCheck(_ cluster: WorkstationCluster) -> WorkstationDeploymentPreflightCheck {
        if cluster.programOpsMode == .enabled {
            return check("cluster", "Cluster write policy", .passed, "\(cluster.title) allows reviewed Program Manager writes.")
        }
        return check("cluster", "Cluster write policy", .blocked, "Mainnet and testnet program writes remain locked in this phase.")
    }

    private static func toolchainCheck(_ toolchain: WorkstationToolchainSnapshot, operation: WorkstationProgramOperation) -> WorkstationDeploymentPreflightCheck {
        let anchorNeeded = [.anchorBuild, .anchorDeploy].contains(operation)
        let solanaNeeded = operation != .anchorBuild
        var missing: [String] = []
        if anchorNeeded && !toolchain.isAvailable(.anchor) {
            missing.append("Anchor CLI")
        }
        if solanaNeeded && !toolchain.isAvailable(.solana) {
            missing.append("Solana CLI")
        }
        if missing.isEmpty {
            return check("toolchain", "Active toolchain", .passed, "Required fixed toolchain executables are available.")
        }
        return check("toolchain", "Active toolchain", .blocked, "Missing: \(missing.joined(separator: ", ")).")
    }

    private static func developerWalletCheck(_ wallet: DeveloperWalletMetadata?, operation: WorkstationProgramOperation) -> WorkstationDeploymentPreflightCheck {
        if operation == .anchorBuild || operation == .solanaProgramShow {
            return check("dev-wallet", "Developer wallet", .passed, "This operation does not require a payer/deployer keypair.")
        }
        if wallet?.status == .ready {
            return check("dev-wallet", "Developer wallet", .passed, "Separate Developer Workstation wallet is ready.")
        }
        return check("dev-wallet", "Developer wallet", .blocked, "A separate Developer Workstation wallet is required. Main KeySlot wallet secrets are not used.")
    }

    private static func programIDConsistencyCheck(
        selectedProgramID: String?,
        idl: WorkstationIDL?,
        projectBrain: DeveloperProjectBrain?
    ) -> WorkstationDeploymentPreflightCheck {
        let selected = selectedProgramID?.trimmingCharacters(in: .whitespacesAndNewlines)
        var known: [(String, String)] = []
        for program in projectBrain?.programs ?? [] {
            if let id = program.programIdFromDeclareId { known.append(("declare_id!", id)) }
            if let id = program.programIdFromAnchorToml { known.append(("Anchor.toml", id)) }
            if let id = program.programIdFromIdl { known.append(("Project Brain IDL", id)) }
        }
        if let id = idl?.address {
            known.append(("Loaded IDL metadata", id))
        }
        let uniqueIDs = Array(Set(known.map(\.1))).sorted()
        if let selected, !selected.isEmpty, !SolanaAddressValidator.isValidAddress(selected) {
            return check("program-id", "Program id consistency", .blocked, "Selected deploy target is not a valid Solana public key.")
        }
        if uniqueIDs.count > 1 {
            return check("program-id", "Program id consistency", .blocked, "Program ids disagree across \(known.map(\.0).joined(separator: ", ")). Resolve before deploy.")
        }
        if let selected, !selected.isEmpty, let knownID = uniqueIDs.first, selected != knownID {
            return check("program-id", "Program id consistency", .blocked, "Selected deploy target differs from project metadata.")
        }
        if uniqueIDs.isEmpty && (selected?.isEmpty ?? true) {
            return check("program-id", "Program id consistency", .warning, "No declare_id!, Anchor.toml program id, loaded IDL address, or selected deploy target was found.")
        }
        return check("program-id", "Program id consistency", .passed, "Program id metadata is consistent for the available sources.")
    }

    private static func artifactCheck(path: String?, project: WorkstationProject?, operation: WorkstationProgramOperation) -> WorkstationDeploymentPreflightCheck {
        guard [.anchorDeploy, .solanaProgramDeploy, .solanaProgramUpgrade].contains(operation) else {
            return check("artifact", "Build artifact", .unavailable, "Artifact hash is not required for this operation.")
        }
        guard let url = resolvedURL(path: path, project: project) else {
            return check("artifact", "Build artifact", .blocked, "Select the compiled program artifact after build.")
        }
        guard isSafeReadablePath(url.path) else {
            return check("artifact", "Build artifact", .blocked, "Artifact path failed safety validation.")
        }
        if FileManager.default.fileExists(atPath: url.path) {
            return check("artifact", "Build artifact", .passed, "Artifact exists and can be hashed locally.")
        }
        return check("artifact", "Build artifact", .blocked, "Artifact is not present at \(safePathSummary(url.path)).")
    }

    private static func idlCheck(path: String?, idl: WorkstationIDL?, projectBrain: DeveloperProjectBrain?) -> WorkstationDeploymentPreflightCheck {
        if idl != nil {
            return check("idl", "IDL after build", .passed, "A loaded IDL is available for release review.")
        }
        if let idlPath = path, !idlPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return check("idl", "IDL after build", .passed, "IDL path is selected for release hashing.")
        }
        if projectBrain?.idls.isEmpty == false {
            return check("idl", "IDL after build", .warning, "Project Brain found IDL files. Select or load one before release export.")
        }
        return check("idl", "IDL after build", .warning, "No IDL is loaded or selected. Deploy can be reviewed, but release record will not include an IDL hash.")
    }

    private static func idlDriftCheck(_ drift: WorkstationIDLDriftReport?, projectBrain: DeveloperProjectBrain?) -> WorkstationDeploymentPreflightCheck {
        if let drift {
            let status: WorkstationDeploymentPreflightStatus = drift.status == .ready ? .passed : .warning
            return check("idl-drift", "IDL drift warnings", status, drift.summary)
        }
        if let brain = projectBrain, brain.warnings.contains(where: { $0.category.lowercased().contains("idl") || $0.title.lowercased().contains("idl") }) {
            return check("idl-drift", "IDL drift warnings", .warning, "Project Brain has IDL-related warnings. Open IDL Drift before deploy.")
        }
        return check("idl-drift", "IDL drift warnings", .unavailable, "Run IDL Drift to compare loaded IDL metadata before release.")
    }

    private static func upgradeAuthorityCheck(_ authority: String?) -> WorkstationDeploymentPreflightCheck {
        guard let authority, !authority.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return check("upgrade-authority", "Upgrade authority", .unavailable, "Upgrade authority is not loaded. Use program show when available.")
        }
        if SolanaAddressValidator.isValidAddress(authority) {
            return check("upgrade-authority", "Upgrade authority", .passed, "Upgrade authority public key is known.")
        }
        return check("upgrade-authority", "Upgrade authority", .warning, "Upgrade authority value is not a valid public key.")
    }

    private static func devWalletBalanceCheck(cluster: WorkstationCluster) -> WorkstationDeploymentPreflightCheck {
        if cluster == .localnet {
            return check("dev-wallet-balance", "Developer wallet balance", .unavailable, "Localnet balance check is available through the faucet/local validator panels.")
        }
        if cluster == .devnet {
            return check("dev-wallet-balance", "Developer wallet balance", .unavailable, "Use the devnet faucet helper or `solana balance` before deploy; no balance was fetched by this preflight.")
        }
        return check("dev-wallet-balance", "Developer wallet balance", .blocked, "Program writes are locked on this cluster.")
    }

    private static func tempKeypairCheck(_ ready: Bool) -> WorkstationDeploymentPreflightCheck {
        if ready {
            return check("temp-keypair", "Temporary keypair lifecycle", .passed, "CLI keypair files remain temporary, chmod 0600 where possible, and delete-after-use.")
        }
        return check("temp-keypair", "Temporary keypair lifecycle", .blocked, "Temporary keypair lifecycle policy is unavailable.")
    }

    private static func commandPreviewCheck(_ preview: WorkstationCommandPlan?) -> WorkstationDeploymentPreflightCheck {
        if let preview {
            return check("command-preview", "Fixed command preview", .passed, preview.redactedPreview)
        }
        return check("command-preview", "Fixed command preview", .blocked, "Prepare a fixed command preview before deploy.")
    }

    private static func explicitApprovalCheck(_ ready: Bool) -> WorkstationDeploymentPreflightCheck {
        if ready {
            return check("explicit-approval", "Explicit approval", .passed, "The required confirmation is present for this operation.")
        }
        return check("explicit-approval", "Explicit approval", .blocked, "Deployment still requires explicit approval in the Program Manager flow.")
    }

    private static func check(_ id: String, _ title: String, _ status: WorkstationDeploymentPreflightStatus, _ detail: String) -> WorkstationDeploymentPreflightCheck {
        WorkstationDeploymentPreflightCheck(id: id, title: title, status: status, detail: detail)
    }

    private static func resolvedURL(path: String?, project: WorkstationProject?) -> URL? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return nil
        }
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        guard let root = project?.localPath, !root.isEmpty else {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent(path)
    }

    nonisolated private static func removeSensitiveLabels(_ value: String) -> String {
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
            "agent token",
            "api key",
            "keypair"
        ].reduce(value) { text, term in
            text.replacingOccurrences(of: term, with: "[redacted]", options: [.caseInsensitive])
        }
    }
}

final class WorkstationDeploymentReleaseStore {
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

    func load() -> [WorkstationDeploymentReleaseRecord] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        if let payload = try? decoder.decode(WorkstationDeploymentReleasePayload.self, from: data) {
            return payload.records
        }
        return (try? decoder.decode([WorkstationDeploymentReleaseRecord].self, from: data)) ?? []
    }

    func append(_ record: WorkstationDeploymentReleaseRecord) throws -> [WorkstationDeploymentReleaseRecord] {
        var entries = load()
        entries.insert(record, at: 0)
        entries = Array(entries.prefix(200))
        try save(entries)
        return entries
    }

    func save(_ entries: [WorkstationDeploymentReleaseRecord]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(WorkstationDeploymentReleasePayload(records: entries))
        try data.write(to: fileURL, options: [.atomic])
    }

    func exportJSON(_ record: WorkstationDeploymentReleaseRecord) throws -> String {
        let data = try encoder.encode(record)
        return String(decoding: data, as: UTF8.self)
    }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("KeySlot", isDirectory: true)
            .appendingPathComponent("DeveloperWorkstation", isDirectory: true)
            .appendingPathComponent("deployment-release-records.json")
    }
}
