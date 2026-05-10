import CryptoKit
import Foundation

enum WorkstationToolchainInstallStatus: String, Codable, Equatable {
    case bundledAvailable = "bundled_available"
    case managedInstalled = "managed_installed"
    case systemDetected = "system_detected"
    case installAvailable = "install_available"
    case installBlockedMissingChecksum = "install_blocked_missing_checksum"
    case installFailed = "install_failed"
    case missing

    var title: String {
        switch self {
        case .bundledAvailable:
            return "Bundled available"
        case .managedInstalled:
            return "Managed installed"
        case .systemDetected:
            return "System detected"
        case .installAvailable:
            return "Install available"
        case .installBlockedMissingChecksum:
            return "Blocked: checksum required"
        case .installFailed:
            return "Install failed"
        case .missing:
            return "Missing"
        }
    }
}

enum WorkstationToolchainDownloadStatus: String, Codable, Equatable {
    case notStarted = "not_started"
    case ready
    case blocked
    case downloaded
    case failed
}

enum WorkstationToolchainVerificationStatus: String, Codable, Equatable {
    case notChecked = "not_checked"
    case verified
    case failed
    case missingChecksum = "missing_checksum"
}

enum WorkstationToolchainInstallError: LocalizedError, Equatable {
    case missingManifestEntry
    case missingVerifiedChecksum
    case unsafeInstallRoot
    case unsafeArchiveEntry(String)
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .missingManifestEntry:
            return "No managed toolchain manifest entry exists for this component."
        case .missingVerifiedChecksum:
            return "Managed install is blocked until the manifest includes a verified HTTPS source and sha256."
        case .unsafeInstallRoot:
            return "Managed install path is outside Application Support/GORKH/Toolchains."
        case .unsafeArchiveEntry(let entry):
            return "Archive entry is unsafe: \(entry)."
        case .checksumMismatch:
            return "Downloaded toolchain checksum did not match the manifest."
        }
    }
}

struct WorkstationToolchainInstallPlan: Codable, Equatable, Identifiable {
    var id: WorkstationToolchainComponent { component }

    let component: WorkstationToolchainComponent
    let status: WorkstationToolchainInstallStatus
    let downloadStatus: WorkstationToolchainDownloadStatus
    let verificationStatus: WorkstationToolchainVerificationStatus
    let installDirectory: String?
    let executablePath: String?
    let message: String
    let commandPreview: String?

    var canInstall: Bool {
        status == .installAvailable && verificationStatus != .missingChecksum
    }
}

struct WorkstationToolchainVerifier {
    static func sha256Hex(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func verify(data: Data, expectedSHA256: String) -> WorkstationToolchainVerificationStatus {
        sha256Hex(data: data).caseInsensitiveCompare(expectedSHA256) == .orderedSame ? .verified : .failed
    }
}

struct WorkstationArchiveSafety {
    static func validateEntryPaths(_ entries: [String]) throws {
        for entry in entries {
            if entry.isEmpty ||
                entry.hasPrefix("/") ||
                entry.contains("..") ||
                entry.contains("\\") ||
                entry.contains("\0") {
                throw WorkstationToolchainInstallError.unsafeArchiveEntry(entry)
            }
        }
    }
}

struct WorkstationToolchainInstaller {
    let manifest: WorkstationToolchainManifest
    let managedRoot: URL
    let fileManager: FileManager

    init(
        manifest: WorkstationToolchainManifest,
        managedRoot: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.manifest = manifest
        self.fileManager = fileManager
        self.managedRoot = managedRoot ?? fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("GORKH/Toolchains", isDirectory: true)
    }

    func plan(component: WorkstationToolchainComponent, resolution: WorkstationToolchainResolution?) -> WorkstationToolchainInstallPlan {
        if let resolution, resolution.status == .available {
            let status: WorkstationToolchainInstallStatus
            switch resolution.source {
            case .bundled:
                status = .bundledAvailable
            case .managed:
                status = .managedInstalled
            case .system:
                status = .systemDetected
            default:
                status = .missing
            }
            return WorkstationToolchainInstallPlan(
                component: component,
                status: status,
                downloadStatus: .notStarted,
                verificationStatus: .notChecked,
                installDirectory: nil,
                executablePath: resolution.executablePath,
                message: resolution.message,
                commandPreview: nil
            )
        }

        guard let entry = manifest.entry(for: component) else {
            return blockedPlan(component: component, error: .missingManifestEntry)
        }

        let installDirectory = managedInstallDirectory(for: entry)
        let executablePath = installDirectory.appendingPathComponent(entry.executableRelativePath).standardizedFileURL.path
        if fileManager.isExecutableFile(atPath: executablePath) {
            return WorkstationToolchainInstallPlan(
                component: component,
                status: .managedInstalled,
                downloadStatus: .downloaded,
                verificationStatus: .verified,
                installDirectory: installDirectory.path,
                executablePath: executablePath,
                message: "Managed executable exists and is confined to the GORKH toolchain directory.",
                commandPreview: nil
            )
        }

        guard entry.hasVerifiedDownload else {
            return WorkstationToolchainInstallPlan(
                component: component,
                status: .installBlockedMissingChecksum,
                downloadStatus: .blocked,
                verificationStatus: .missingChecksum,
                installDirectory: installDirectory.path,
                executablePath: executablePath,
                message: "Managed install is unavailable until this manifest entry has a verified HTTPS source and sha256.",
                commandPreview: nil
            )
        }

        return WorkstationToolchainInstallPlan(
            component: component,
            status: .installAvailable,
            downloadStatus: .ready,
            verificationStatus: .notChecked,
            installDirectory: installDirectory.path,
            executablePath: executablePath,
            message: "Managed install can download, verify sha256, and unpack into Application Support.",
            commandPreview: "Download \(component.displayName) \(entry.version), verify sha256, install under GORKH/Toolchains."
        )
    }

    func managedInstallDirectory(for entry: WorkstationToolchainManifestEntry) -> URL {
        managedRoot
            .appendingPathComponent(entry.toolID.rawValue, isDirectory: true)
            .appendingPathComponent(entry.version, isDirectory: true)
            .standardizedFileURL
    }

    func validateManagedInstallDirectory(_ directory: URL) throws {
        let root = managedRoot.standardizedFileURL.path
        let path = directory.standardizedFileURL.path
        guard path == root || path.hasPrefix(root + "/") else {
            throw WorkstationToolchainInstallError.unsafeInstallRoot
        }
    }

    private func blockedPlan(component: WorkstationToolchainComponent, error: WorkstationToolchainInstallError) -> WorkstationToolchainInstallPlan {
        WorkstationToolchainInstallPlan(
            component: component,
            status: .missing,
            downloadStatus: .blocked,
            verificationStatus: .notChecked,
            installDirectory: nil,
            executablePath: nil,
            message: error.localizedDescription,
            commandPreview: nil
        )
    }
}
