import Foundation

enum WorkstationProgramOperationEvidenceStatus: String, Codable, Equatable {
    case succeeded
    case failed
    case blocked
    case skipped

    var title: String {
        switch self {
        case .succeeded:
            return "Succeeded"
        case .failed:
            return "Failed"
        case .blocked:
            return "Blocked"
        case .skipped:
            return "Skipped"
        }
    }
}

enum WorkstationTempKeyCleanupStatus: String, Codable, Equatable {
    case notCreated = "not_created"
    case cleaned
    case failed
    case unknown

    var title: String {
        switch self {
        case .notCreated:
            return "Not created"
        case .cleaned:
            return "Cleaned"
        case .failed:
            return "Cleanup failed"
        case .unknown:
            return "Unknown"
        }
    }
}

struct WorkstationProgramOperationEvidence: Codable, Equatable, Identifiable {
    let id: UUID
    let projectID: UUID?
    let projectName: String
    let cluster: WorkstationCluster
    let operation: WorkstationProgramOperation
    let programID: String?
    let signature: String?
    let timestamp: Date
    let toolVersions: [String: String]
    let commandSummary: String
    let status: WorkstationProgramOperationEvidenceStatus
    let logSummary: String
    let idlPath: String?
    let artifactPath: String?
    let tempKeyCleanupStatus: WorkstationTempKeyCleanupStatus

    init(
        id: UUID = UUID(),
        projectID: UUID?,
        projectName: String,
        cluster: WorkstationCluster,
        operation: WorkstationProgramOperation,
        programID: String?,
        signature: String?,
        timestamp: Date = Date(),
        toolVersions: [String: String],
        commandSummary: String,
        status: WorkstationProgramOperationEvidenceStatus,
        logSummary: String,
        idlPath: String?,
        artifactPath: String?,
        tempKeyCleanupStatus: WorkstationTempKeyCleanupStatus
    ) {
        self.id = id
        self.projectID = projectID
        self.projectName = AgentSafetyRedactor.redact(projectName)
        self.cluster = cluster
        self.operation = operation
        self.programID = programID.flatMap(Self.safePublicIdentifier)
        self.signature = signature.flatMap(Self.safePublicIdentifier)
        self.timestamp = timestamp
        self.toolVersions = Self.safeToolVersions(toolVersions)
        self.commandSummary = Self.safeText(commandSummary, limit: 500)
        self.status = status
        self.logSummary = Self.safeText(logSummary, limit: 1_000)
        self.idlPath = idlPath.map(Self.safePathSummary)
        self.artifactPath = artifactPath.map(Self.safePathSummary)
        self.tempKeyCleanupStatus = tempKeyCleanupStatus
    }

    static let d7LocalnetCertification = WorkstationProgramOperationEvidence(
        projectID: nil,
        projectName: "Anchor Hello World sample",
        cluster: .localnet,
        operation: .solanaProgramDeploy,
        programID: "9aR9XnArCREYz86Y7kqy2W9iKYnWT8CSbEjnBTAQLvsJ",
        signature: "5FS38zAwXX4SP3VVRi1r1ubHHXYFdsv7S9WBYCdFbG4uR8ANWTyy6u9jAqt1Bq8YNby61xTu4DE94eQ8KA6Ed2To",
        timestamp: Date(timeIntervalSince1970: 1_778_367_600),
        toolVersions: [
            "anchor": "anchor-cli 1.0.2",
            "rustc": "rustc 1.95.0",
            "cargo": "cargo 1.95.0",
            "solana": "solana-cli 3.1.10",
            "validator": "solana-test-validator 3.1.10"
        ],
        commandSummary: "Fixed localnet sample smoke: anchor build, solana program deploy, solana program show.",
        status: .succeeded,
        logSummary: "Anchor build and localnet deploy succeeded. Temporary keypair cleanup confirmed.",
        idlPath: "samples/anchor-hello-world/target/idl/hello_world.json",
        artifactPath: "target/deploy/hello_world.so",
        tempKeyCleanupStatus: .cleaned
    )

    static let d8LocalnetCertification = WorkstationProgramOperationEvidence(
        projectID: nil,
        projectName: "Anchor Hello World sample",
        cluster: .localnet,
        operation: .solanaProgramDeploy,
        programID: "4rQMkzANcjjinzHd47mp1Kj2W7pokFfJxmxMsjQPdnfJ",
        signature: "3UwxdFwWT3WhLfKT5Gssf3Z19pawgA4x5KwWbXqNzUJAyeSmiU7LHWBhWuTr363QjvDivfxSoheVbF883foX9r8r",
        timestamp: Date(timeIntervalSince1970: 1_778_450_800),
        toolVersions: [
            "anchor": "anchor-cli 1.0.2",
            "rustc": "rustc 1.95.0",
            "cargo": "cargo 1.95.0",
            "solana": "solana-cli 3.1.10",
            "validator": "solana-test-validator 3.1.10"
        ],
        commandSummary: "D8 fixed Program Ops localnet sample smoke: anchor build, solana program deploy, solana program show.",
        status: .succeeded,
        logSummary: "Program Ops localnet-sample wrapper passed outside the sandbox after the sandboxed validator faucet bind was blocked. Temporary keypair cleanup confirmed by smoke exit.",
        idlPath: "samples/anchor-hello-world/target/idl/hello_world.json",
        artifactPath: "target/deploy/hello_world.so",
        tempKeyCleanupStatus: .cleaned
    )

    nonisolated private static func safeText(_ text: String, limit: Int) -> String {
        let redacted = removeSecretLabels(AgentSafetyRedactor.redact(text.trimmingCharacters(in: .whitespacesAndNewlines)))
        if redacted.count <= limit {
            return redacted
        }
        return String(redacted.prefix(limit)) + "..."
    }

    nonisolated private static func safePathSummary(_ path: String) -> String {
        let redacted = removeSecretLabels(AgentSafetyRedactor.redact(path))
        let components = redacted
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard components.count > 2 else {
            return redacted
        }
        return components.suffix(2).joined(separator: "/")
    }

    nonisolated private static func safePublicIdentifier(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return removeSecretLabels(AgentSafetyRedactor.redact(trimmed))
    }

    nonisolated private static func safeToolVersions(_ versions: [String: String]) -> [String: String] {
        versions.reduce(into: [:]) { partial, item in
            partial[removeSecretLabels(AgentSafetyRedactor.redact(item.key))] = removeSecretLabels(AgentSafetyRedactor.redact(item.value))
        }
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
            "agent token",
            "api key",
            "keypair"
        ].reduce(value) { text, term in
            text.replacingOccurrences(of: term, with: "[redacted]", options: [.caseInsensitive])
        }
    }
}

final class WorkstationProgramOperationEvidenceStore {
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

    func load() -> [WorkstationProgramOperationEvidence] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        return (try? decoder.decode([WorkstationProgramOperationEvidence].self, from: data)) ?? []
    }

    func append(_ evidence: WorkstationProgramOperationEvidence) throws -> [WorkstationProgramOperationEvidence] {
        var entries = load()
        entries.insert(evidence, at: 0)
        entries = Array(entries.prefix(100))
        try save(entries)
        return entries
    }

    func save(_ entries: [WorkstationProgramOperationEvidence]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: [.atomic])
    }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("GORKH", isDirectory: true)
            .appendingPathComponent("DeveloperWorkstation", isDirectory: true)
            .appendingPathComponent("program-operation-evidence.json")
    }
}

enum WorkstationDevnetCertificationPolicy {
    static let requiredConfirmation = "I understand this deploys a Solana program on devnet using the Developer Workstation wallet."

    static func validate(
        cluster: WorkstationCluster,
        project: WorkstationProject?,
        toolchain: WorkstationToolchainSnapshot,
        developerWallet: DeveloperWalletMetadata?,
        confirmation: String
    ) -> WorkstationProgramOperationDecision {
        var reasons: [String] = []
        guard cluster == .devnet else {
            return .blocked(["Devnet certification is available only when Devnet is selected."])
        }
        if let block = WorkstationTrustPolicy.blocksExecution(project: project) {
            reasons.append(block)
        }
        if developerWallet?.status != .ready {
            reasons.append("Developer Workstation wallet is required for devnet certification.")
        }
        if toolchain.isAvailable(.anchor) == false || toolchain.isAvailable(.solana) == false {
            reasons.append("Anchor and Solana CLI are required for devnet certification.")
        }
        if confirmation != requiredConfirmation {
            reasons.append("Exact devnet certification confirmation is required.")
        }
        if reasons.isEmpty {
            return .allowed("Devnet certification may proceed only after command preview and explicit approval.")
        }
        return .blocked(reasons)
    }
}
