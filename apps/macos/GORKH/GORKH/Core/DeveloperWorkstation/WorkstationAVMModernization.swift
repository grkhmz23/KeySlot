import Foundation

enum WorkstationAVMVersionStatus: String, Codable, Equatable {
    case unchecked
    case available
    case selfUpdateAvailable = "self_update_available"
    case cargoReinstallAvailable = "cargo_reinstall_available"
    case blocked

    var title: String {
        switch self {
        case .unchecked:
            return "Unchecked"
        case .available:
            return "AVM available"
        case .selfUpdateAvailable:
            return "Self-update available"
        case .cargoReinstallAvailable:
            return "Cargo reinstall available"
        case .blocked:
            return "Blocked"
        }
    }
}

enum WorkstationAVMUpdateStrategy: String, Codable, Equatable {
    case none
    case selfUpdate = "self_update"
    case cargoReinstallOfficialRepo = "cargo_reinstall_official_repo"
    case verifiedArtifactBlocked = "verified_artifact_blocked"
    case blocked
}

struct WorkstationAVMUpdatePlan: Codable, Equatable, Identifiable {
    let id: String
    let currentVersion: String?
    let status: WorkstationAVMVersionStatus
    let strategy: WorkstationAVMUpdateStrategy
    let message: String
    let commandPreviews: [String]

    var canRunWithApproval: Bool {
        status == .selfUpdateAvailable || status == .cargoReinstallAvailable
    }
}

struct WorkstationAVMUpdateResult: Codable, Equatable {
    let strategy: WorkstationAVMUpdateStrategy
    let status: WorkstationCommandStatus
    let versionBefore: String?
    let versionAfter: String?
    let message: String
    let completedAt: Date
}

enum WorkstationOfficialArtifactVerification: String, Codable, Equatable {
    case blockedMissingURL = "blocked_missing_url"
    case blockedMissingSHA256 = "blocked_missing_sha256"
    case blockedUnverifiedSource = "blocked_unverified_source"
    case readyForVerification = "ready_for_verification"
    case verified

    var title: String {
        switch self {
        case .blockedMissingURL:
            return "Blocked: URL missing"
        case .blockedMissingSHA256:
            return "Blocked: SHA-256 missing"
        case .blockedUnverifiedSource:
            return "Blocked: unverified source"
        case .readyForVerification:
            return "Ready for verification"
        case .verified:
            return "Verified"
        }
    }
}

struct WorkstationAnchorBinaryInstallPlan: Codable, Equatable, Identifiable {
    let id: String
    let version: String
    let platform: String
    let architecture: String
    let sourceURL: String?
    let sha256: String?
    let installDirectory: String
    let executableRelativePath: String
    let verification: WorkstationOfficialArtifactVerification
    let message: String

    var canInstall: Bool {
        verification == .readyForVerification || verification == .verified
    }
}

enum WorkstationAVMModernizationPlanner {
    static func avmUpdatePlan(snapshot: WorkstationToolchainSnapshot) -> WorkstationAVMUpdatePlan {
        let avm = snapshot.resolution(for: .avm)
        let cargo = snapshot.resolution(for: .cargo)
        let currentVersion = avm?.version ?? avm?.message

        if let avmPath = avm?.executablePath {
            let selfUpdate = WorkstationCommandBuilders.avmSelfUpdate(avmPath: avmPath)
            let cargoReinstall = cargo?.executablePath.map {
                WorkstationCommandBuilders.cargoInstallAVM(
                    cargoPath: $0,
                    anchorVersion: WorkstationAnchorVersionPolicy.recommendedCandidate
                )
            }
            return WorkstationAVMUpdatePlan(
                id: "avm-modernization",
                currentVersion: currentVersion,
                status: .selfUpdateAvailable,
                strategy: .selfUpdate,
                message: "Try fixed AVM self-update first. If this AVM does not support self-update, use the fixed Cargo reinstall from the official Anchor repository after explicit tooling approval.",
                commandPreviews: ([selfUpdate.redactedPreview] + [cargoReinstall?.redactedPreview].compactMap { $0 })
            )
        }

        if let cargoPath = cargo?.executablePath {
            let cargoReinstall = WorkstationCommandBuilders.cargoInstallAVM(
                cargoPath: cargoPath,
                anchorVersion: WorkstationAnchorVersionPolicy.recommendedCandidate
            )
            return WorkstationAVMUpdatePlan(
                id: "avm-modernization",
                currentVersion: currentVersion,
                status: .cargoReinstallAvailable,
                strategy: .cargoReinstallOfficialRepo,
                message: "AVM is missing. Cargo can install AVM from the official Anchor repository with fixed args after explicit tooling-install approval.",
                commandPreviews: [cargoReinstall.redactedPreview]
            )
        }

        return WorkstationAVMUpdatePlan(
            id: "avm-modernization",
            currentVersion: currentVersion,
            status: .blocked,
            strategy: .verifiedArtifactBlocked,
            message: "AVM update is blocked until AVM, Cargo, or a verified official AVM artifact with SHA-256 is available.",
            commandPreviews: []
        )
    }

    static func anchorBinaryInstallPlan(
        manifest: WorkstationToolchainManifest,
        managedRoot: URL? = nil
    ) -> WorkstationAnchorBinaryInstallPlan {
        let installer = WorkstationToolchainInstaller(manifest: manifest, managedRoot: managedRoot)
        let entry = manifest.entry(for: .anchor)
        let version = WorkstationAnchorVersionPolicy.explicitStableCandidate
        let directory = installer.managedRoot
            .appendingPathComponent("anchor", isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
            .standardizedFileURL
        let executableRelativePath = entry?.executableRelativePath ?? "bin/anchor"

        let verification: WorkstationOfficialArtifactVerification
        let message: String
        if entry?.sourceURL == nil {
            verification = .blockedMissingURL
            message = "Official Anchor binary install is blocked until a GitHub release asset URL is pinned."
        } else if entry?.sha256 == nil {
            verification = .blockedMissingSHA256
            message = "Official Anchor binary install is blocked until the release asset SHA-256 is pinned."
        } else if entry?.hasVerifiedDownload == true {
            verification = .readyForVerification
            message = "Official Anchor artifact can be downloaded, SHA-256 verified, and installed under KeySlot/Toolchains."
        } else {
            verification = .blockedUnverifiedSource
            message = "Official Anchor artifact metadata is incomplete or not marked as a verified install."
        }

        return WorkstationAnchorBinaryInstallPlan(
            id: "anchor-binary-\(version)",
            version: version,
            platform: entry?.platform ?? "macos",
            architecture: entry?.architecture ?? "arm64",
            sourceURL: entry?.sourceURL,
            sha256: entry?.sha256,
            installDirectory: directory.path,
            executableRelativePath: executableRelativePath,
            verification: verification,
            message: message
        )
    }
}
