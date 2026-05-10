import Foundation

enum WorkstationToolchainInstallStrategy: String, Codable, Equatable {
    case prebuiltArchive = "prebuilt_archive"
    case prebuiltExecutable = "prebuilt_executable"
    case avmCargoInstall = "avm_cargo_install"
    case avmManagedAnchor = "avm_managed_anchor"
    case externalPackageManager = "external_package_manager"
    case unavailable

    var title: String {
        switch self {
        case .prebuiltArchive:
            return "Prebuilt archive"
        case .prebuiltExecutable:
            return "Prebuilt executable"
        case .avmCargoInstall:
            return "Install AVM with Cargo"
        case .avmManagedAnchor:
            return "Install Anchor with AVM"
        case .externalPackageManager:
            return "External package manager"
        case .unavailable:
            return "Unavailable"
        }
    }
}

enum WorkstationToolchainManifestSourceType: String, Codable, Equatable {
    case officialReleaseArchive = "official_release_archive"
    case officialSourceBuild = "official_source_build"
    case detectedOnly = "detected_only"
    case planned
    case unsupported
}

enum WorkstationToolchainManifestInstallStatus: String, Codable, Equatable {
    case verifiedInstallAvailable = "verified_install_available"
    case detectedOnly = "detected_only"
    case plannedBlockedMissingArtifact = "planned_blocked_missing_artifact"
    case plannedBlockedMissingChecksum = "planned_blocked_missing_checksum"
    case unsupported

    var title: String {
        switch self {
        case .verifiedInstallAvailable:
            return "Verified install available"
        case .detectedOnly:
            return "Detected only"
        case .plannedBlockedMissingArtifact:
            return "Blocked: artifact required"
        case .plannedBlockedMissingChecksum:
            return "Blocked: checksum required"
        case .unsupported:
            return "Unsupported"
        }
    }
}

struct WorkstationToolchainManifestEntry: Codable, Equatable, Identifiable {
    var id: String { toolID.rawValue }

    let toolID: WorkstationToolchainComponent
    let version: String
    let versionPolicy: String?
    let platform: String
    let architecture: String
    let sourceType: WorkstationToolchainManifestSourceType
    let officialSourceNote: String
    let sourceURL: String?
    let sha256: String?
    let executableRelativePath: String
    let installStrategy: WorkstationToolchainInstallStrategy
    let installStatus: WorkstationToolchainManifestInstallStatus
    let compatibilityStrategy: String?
    let recommendedAnchorCandidates: [String]?
    let rustToolchainPinningNote: String?
    let prebuiltArtifactStatus: String?
    let notes: String
    let licenseNote: String

    var hasVerifiedDownload: Bool {
        guard let sourceURL,
              sourceURL.hasPrefix("https://"),
              let sha256,
              sha256.range(of: #"^[a-fA-F0-9]{64}$"#, options: .regularExpression) != nil else {
            return false
        }
        return installStatus == .verifiedInstallAvailable && installStrategy != .unavailable
    }
}

struct WorkstationToolchainManifest: Codable, Equatable {
    let schemaVersion: Int
    let generatedAt: String
    let tools: [WorkstationToolchainManifestEntry]

    func entry(for component: WorkstationToolchainComponent) -> WorkstationToolchainManifestEntry? {
        tools.first { $0.toolID == component }
    }

    static let d3Default = WorkstationToolchainManifest(
        schemaVersion: 1,
        generatedAt: "2026-05-10",
        tools: WorkstationToolchainComponent.allCases.map {
            WorkstationToolchainManifestEntry(
                toolID: $0,
                version: "pending",
                versionPolicy: "detected-only until release engineering pins a verified artifact",
                platform: "macos",
                architecture: "arm64",
                sourceType: .planned,
                officialSourceNote: "Use official upstream release documentation and artifacts only.",
                sourceURL: nil,
                sha256: nil,
                executableRelativePath: "bin/\($0.executableName)",
                installStrategy: .unavailable,
                installStatus: .plannedBlockedMissingArtifact,
                compatibilityStrategy: nil,
                recommendedAnchorCandidates: nil,
                rustToolchainPinningNote: nil,
                prebuiltArtifactStatus: "blocked_without_verified_artifact_and_sha256",
                notes: "Managed install is blocked until release engineering fills a verified HTTPS source and sha256.",
                licenseNote: "See upstream tool license before packaging."
            )
        }
    )

    static let d2Placeholder = d3Default
}

enum WorkstationToolchainManifestError: LocalizedError, Equatable {
    case invalidJSON
    case missingTool(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Toolchain manifest could not be decoded."
        case .missingTool(let tool):
            return "Toolchain manifest is missing \(tool)."
        }
    }
}

struct WorkstationToolchainManifestLoader {
    static func parse(data: Data) throws -> WorkstationToolchainManifest {
        do {
            return try JSONDecoder().decode(WorkstationToolchainManifest.self, from: data)
        } catch {
            throw WorkstationToolchainManifestError.invalidJSON
        }
    }

    static func parse(string: String) throws -> WorkstationToolchainManifest {
        try parse(data: Data(string.utf8))
    }
}
