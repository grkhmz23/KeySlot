import Foundation

enum DeveloperProjectType: String, Codable, CaseIterable, Identifiable {
    case anchor
    case nativeSolanaRust
    case nodeTypescript
    case mixed
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anchor:
            return "Anchor"
        case .nativeSolanaRust:
            return "Native Solana Rust"
        case .nodeTypescript:
            return "Node / TypeScript"
        case .mixed:
            return "Mixed"
        case .unknown:
            return "Unknown"
        }
    }
}

typealias DeveloperProjectTrustStatus = WorkstationProjectTrustStatus

enum BrainConfidence: String, Codable, Equatable {
    case high
    case medium
    case low
    case unknown

    var title: String { rawValue.capitalized }
}

enum ProjectBrainWarningSeverity: String, Codable, Equatable {
    case info
    case warning
    case high

    var title: String { rawValue.capitalized }
}

struct DeveloperProjectBrain: Codable, Equatable, Identifiable {
    let id: UUID
    let projectId: String
    let projectName: String
    let projectRootDisplay: String
    let generatedAt: Date
    let projectType: DeveloperProjectType
    let trustStatus: DeveloperProjectTrustStatus
    let detectedFiles: [DetectedProjectFile]
    let toolchainHints: [ToolchainHint]
    let programs: [ProgramBrain]
    let idls: [IDLBrain]
    let instructions: [InstructionBrain]
    let accounts: [AccountBrain]
    let pdaCandidates: [PDACandidate]
    let clientCandidates: [ClientCandidate]
    let testCandidates: [TestCandidate]
    let frontendCandidates: [FrontendCandidate]
    let warnings: [ProjectBrainWarning]
    let unsupportedFindings: [UnsupportedFinding]
    let confidence: BrainConfidence
}

struct DetectedProjectFile: Codable, Equatable, Identifiable {
    var id: String { relativePath }

    let relativePath: String
    let kind: String
    let byteCount: Int
    let modifiedAt: Date?
}

struct ToolchainHint: Codable, Equatable, Identifiable {
    var id: String { "\(component):\(source)" }

    let component: String
    let source: String
    let versionOrRequirement: String?
    let detail: String
}

struct ProgramBrain: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let relativePath: String
    let language: String
    let programIdFromDeclareId: String?
    let programIdFromAnchorToml: String?
    let programIdFromIdl: String?
    let programIdMismatchWarnings: [ProjectBrainWarning]
    let sourceFiles: [String]
    let idlPaths: [String]
    let deployArtifacts: [String]
    let instructions: [String]
    let accountTypes: [String]
    let errorTypes: [String]
    let events: [String]
}

struct InstructionBrain: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let sourceRelativePath: String?
    let sourceLineStart: Int?
    let args: [String]
    let accounts: [String]
    let signerAccounts: [String]
    let writableAccounts: [String]
    let anchorConstraints: [String]
    let cpiHints: [String]
    let pdaHints: [String]
    let confidence: BrainConfidence
}

struct AccountBrain: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let sourceRelativePath: String?
    let sourceLineStart: Int?
    let fields: [String]
    let discriminator: String?
    let idlTypeRef: String?
    let confidence: BrainConfidence
}

struct PDACandidate: Codable, Equatable, Identifiable {
    let id: String
    let label: String
    let sourceRelativePath: String?
    let sourceLineStart: Int?
    let programIdSource: String?
    let seeds: [String]
    let bumpUsage: String?
    let accountType: String?
    let instructionName: String?
    let confidence: BrainConfidence
    let unsupportedReason: String?
}

struct IDLBrain: Codable, Equatable, Identifiable {
    let id: String
    let relativePath: String
    let programName: String
    let programId: String?
    let instructions: [String]
    let accounts: [String]
    let types: [String]
    let errors: [String]
    let events: [String]
    let discriminators: [String]
    let source: String
    let modifiedAt: Date?
}

struct ClientCandidate: Codable, Equatable, Identifiable {
    let id: String
    let relativePath: String
    let framework: String
    let modifiedAt: Date?
    let staleComparedToIDL: Bool?
}

struct TestCandidate: Codable, Equatable, Identifiable {
    let id: String
    let relativePath: String
    let kind: String
    let modifiedAt: Date?
}

struct FrontendCandidate: Codable, Equatable, Identifiable {
    let id: String
    let relativePath: String
    let frameworkHint: String
    let warnings: [ProjectBrainWarning]
}

struct ProjectBrainWarning: Codable, Equatable, Identifiable {
    let id: String
    let severity: ProjectBrainWarningSeverity
    let category: String
    let title: String
    let detail: String
    let sourceRelativePath: String?
    let line: Int?
    let suggestedAction: String

    init(
        id: String,
        severity: ProjectBrainWarningSeverity,
        category: String,
        title: String,
        detail: String,
        sourceRelativePath: String? = nil,
        line: Int? = nil,
        suggestedAction: String
    ) {
        self.id = id
        self.severity = severity
        self.category = AgentSafetyRedactor.redact(category)
        self.title = AgentSafetyRedactor.redact(title)
        self.detail = AgentSafetyRedactor.redact(detail)
        self.sourceRelativePath = sourceRelativePath.map(DeveloperProjectBrainPath.cleanRelativePath)
        self.line = line
        self.suggestedAction = AgentSafetyRedactor.redact(suggestedAction)
    }
}

struct UnsupportedFinding: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let reason: String
    let sourceRelativePath: String?

    init(id: String, title: String, reason: String, sourceRelativePath: String? = nil) {
        self.id = id
        self.title = AgentSafetyRedactor.redact(title)
        self.reason = AgentSafetyRedactor.redact(reason)
        self.sourceRelativePath = sourceRelativePath.map(DeveloperProjectBrainPath.cleanRelativePath)
    }
}

enum DeveloperProjectBrainPath {
    nonisolated static func display(path: String) -> String {
        let redacted = AgentSafetyRedactor.redact(path)
        let components = redacted
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard components.count > 2 else {
            return redacted
        }
        return components.suffix(2).joined(separator: "/")
    }

    nonisolated static func cleanRelativePath(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
            .joined(separator: "/")
    }
}
