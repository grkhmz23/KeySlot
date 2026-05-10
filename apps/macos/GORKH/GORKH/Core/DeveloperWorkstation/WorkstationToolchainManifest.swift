import Foundation

enum WorkstationToolchainInstallStrategy: String, Codable, Equatable {
    case prebuiltArchive = "prebuilt_archive"
    case prebuiltExecutable = "prebuilt_executable"
    case externalPackageManager = "external_package_manager"
    case unavailable

    var title: String {
        switch self {
        case .prebuiltArchive:
            return "Prebuilt archive"
        case .prebuiltExecutable:
            return "Prebuilt executable"
        case .externalPackageManager:
            return "External package manager"
        case .unavailable:
            return "Unavailable"
        }
    }
}

struct WorkstationToolchainManifestEntry: Codable, Equatable, Identifiable {
    var id: String { toolID.rawValue }

    let toolID: WorkstationToolchainComponent
    let version: String
    let platform: String
    let architecture: String
    let sourceURL: String?
    let sha256: String?
    let executableRelativePath: String
    let installStrategy: WorkstationToolchainInstallStrategy
    let notes: String
    let licenseNote: String

    var hasVerifiedDownload: Bool {
        guard let sourceURL,
              sourceURL.hasPrefix("https://"),
              let sha256,
              sha256.range(of: #"^[a-fA-F0-9]{64}$"#, options: .regularExpression) != nil else {
            return false
        }
        return installStrategy != .unavailable
    }
}

struct WorkstationToolchainManifest: Codable, Equatable {
    let schemaVersion: Int
    let generatedAt: String
    let tools: [WorkstationToolchainManifestEntry]

    func entry(for component: WorkstationToolchainComponent) -> WorkstationToolchainManifestEntry? {
        tools.first { $0.toolID == component }
    }

    static let d2Placeholder = WorkstationToolchainManifest(
        schemaVersion: 1,
        generatedAt: "2026-05-10",
        tools: WorkstationToolchainComponent.allCases.map {
            WorkstationToolchainManifestEntry(
                toolID: $0,
                version: "pending",
                platform: "macos",
                architecture: "arm64",
                sourceURL: nil,
                sha256: nil,
                executableRelativePath: "bin/\($0.executableName)",
                installStrategy: .unavailable,
                notes: "Managed install is blocked until release engineering fills a verified HTTPS source and sha256.",
                licenseNote: "See upstream tool license before packaging."
            )
        }
    )
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
