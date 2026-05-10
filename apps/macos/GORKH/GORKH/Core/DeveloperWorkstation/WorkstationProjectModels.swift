import Foundation

enum WorkstationProjectSourceType: String, Codable, CaseIterable, Identifiable {
    case folder
    case zip
    case gitHTTPS = "git_https"
    case gitSSH = "git_ssh"
    case manualIDL = "manual_idl"

    var id: String { rawValue }
}

enum WorkstationDetectedFramework: String, Codable, Equatable {
    case anchor = "Anchor"
    case solanaNativeRust = "Solana native Rust"
    case nodeTypeScript = "Node / TypeScript"
    case unknown = "Unknown"
}

enum WorkstationProjectTrustStatus: String, Codable, Equatable {
    case untrusted
    case trusted

    var title: String {
        switch self {
        case .untrusted:
            return "Untrusted"
        case .trusted:
            return "Trusted"
        }
    }
}

struct WorkstationDetectedFiles: Codable, Equatable {
    var anchorToml: Bool
    var cargoToml: Bool
    var packageJSON: Bool
    var idlJSONCount: Int
    var targetIDLJSONCount: Int
    var programDirectoryCount: Int

    static let empty = WorkstationDetectedFiles(
        anchorToml: false,
        cargoToml: false,
        packageJSON: false,
        idlJSONCount: 0,
        targetIDLJSONCount: 0,
        programDirectoryCount: 0
    )
}

struct WorkstationProject: Codable, Equatable, Identifiable {
    let id: UUID
    var displayName: String
    var localPath: String
    var sourceType: WorkstationProjectSourceType
    var trustStatus: WorkstationProjectTrustStatus
    var detectedFramework: WorkstationDetectedFramework
    var detectedFiles: WorkstationDetectedFiles
    var lastOpened: Date
    var warnings: [String]

    var canRunCommands: Bool {
        trustStatus == .trusted
    }

    static let placeholder = WorkstationProject(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000D001")!,
        displayName: "No project imported",
        localPath: "",
        sourceType: .folder,
        trustStatus: .untrusted,
        detectedFramework: .unknown,
        detectedFiles: .empty,
        lastOpened: Date(timeIntervalSince1970: 0),
        warnings: ["Import a project to inspect IDLs and metadata. No commands run after import."]
    )
}

enum WorkstationProjectImportError: LocalizedError, Equatable {
    case unsafePath
    case unsupportedGitURL
    case missingPath

    var errorDescription: String? {
        switch self {
        case .unsafePath:
            return "Project path failed safety validation."
        case .unsupportedGitURL:
            return "Only HTTPS Git URLs are supported in this phase."
        case .missingPath:
            return "Project path does not exist."
        }
    }
}

struct WorkstationProjectImporter {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func inspectFolder(_ url: URL, now: Date = Date()) throws -> WorkstationProject {
        let path = url.path
        guard isSafeLocalPath(path) else {
            throw WorkstationProjectImportError.unsafePath
        }
        guard fileManager.fileExists(atPath: path) else {
            throw WorkstationProjectImportError.missingPath
        }
        let detected = detectFiles(root: url)
        return WorkstationProject(
            id: UUID(),
            displayName: url.lastPathComponent,
            localPath: path,
            sourceType: .folder,
            trustStatus: .untrusted,
            detectedFramework: framework(from: detected),
            detectedFiles: detected,
            lastOpened: now,
            warnings: ["Project imported as untrusted. Browsing is allowed; build and deploy are blocked until trusted."]
        )
    }

    func inspectZip(_ url: URL, now: Date = Date()) throws -> WorkstationProject {
        guard isSafeLocalPath(url.path), url.pathExtension.lowercased() == "zip" else {
            throw WorkstationProjectImportError.unsafePath
        }
        return WorkstationProject(
            id: UUID(),
            displayName: url.deletingPathExtension().lastPathComponent,
            localPath: url.path,
            sourceType: .zip,
            trustStatus: .untrusted,
            detectedFramework: .unknown,
            detectedFiles: .empty,
            lastOpened: now,
            warnings: ["Zip import is metadata-only until extracted by an approved future flow. No scripts were run."]
        )
    }

    func prepareGitImport(urlString: String, workspaceRoot: URL, now: Date = Date()) throws -> (project: WorkstationProject, command: WorkstationCommandPlan) {
        guard let url = URL(string: urlString),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false,
              urlString.lowercased().hasSuffix(".git") || url.host != nil else {
            throw WorkstationProjectImportError.unsupportedGitURL
        }
        guard isSafeLocalPath(workspaceRoot.path) else {
            throw WorkstationProjectImportError.unsafePath
        }

        let displayName = url.deletingPathExtension().lastPathComponent.isEmpty ? "Imported Git Project" : url.deletingPathExtension().lastPathComponent
        let destination = workspaceRoot.appendingPathComponent(displayName, isDirectory: true)
        let project = WorkstationProject(
            id: UUID(),
            displayName: displayName,
            localPath: destination.path,
            sourceType: .gitHTTPS,
            trustStatus: .untrusted,
            detectedFramework: .unknown,
            detectedFiles: .empty,
            lastOpened: now,
            warnings: ["Git clone is a fixed command. No scripts run after clone; project remains untrusted."]
        )
        let command = WorkstationCommandBuilders.gitClone(url: url.absoluteString, destination: destination.path)
        return (project, command)
    }

    func isSafeLocalPath(_ path: String) -> Bool {
        path.hasPrefix("/")
            && path.contains("..") == false
            && path.contains(";") == false
            && path.contains("|") == false
            && path.contains("&") == false
            && path.contains("`") == false
    }

    private func detectFiles(root: URL) -> WorkstationDetectedFiles {
        var isDirectory: ObjCBool = false
        func exists(_ relative: String) -> Bool {
            fileManager.fileExists(atPath: root.appendingPathComponent(relative).path, isDirectory: &isDirectory)
        }
        let idlCount = countJSONFiles(root.appendingPathComponent("idl"))
        let targetIDLCount = countJSONFiles(root.appendingPathComponent("target/idl"))
        let programsURL = root.appendingPathComponent("programs", isDirectory: true)
        let programCount = (try? fileManager.contentsOfDirectory(at: programsURL, includingPropertiesForKeys: nil)
            .filter { $0.hasDirectoryPath }
            .count) ?? 0
        return WorkstationDetectedFiles(
            anchorToml: exists("Anchor.toml"),
            cargoToml: exists("Cargo.toml"),
            packageJSON: exists("package.json"),
            idlJSONCount: idlCount,
            targetIDLJSONCount: targetIDLCount,
            programDirectoryCount: programCount
        )
    }

    private func countJSONFiles(_ url: URL) -> Int {
        (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "json" }
            .count) ?? 0
    }

    private func framework(from files: WorkstationDetectedFiles) -> WorkstationDetectedFramework {
        if files.anchorToml {
            return .anchor
        }
        if files.cargoToml {
            return .solanaNativeRust
        }
        if files.packageJSON {
            return .nodeTypeScript
        }
        return .unknown
    }
}
