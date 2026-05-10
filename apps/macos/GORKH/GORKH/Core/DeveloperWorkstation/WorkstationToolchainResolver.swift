import Foundation

struct WorkstationToolchainResolver {
    private let fileManager: FileManager
    private let environment: [String: String]
    private let bundleRoot: URL?
    private let managedRoot: URL
    private let systemDirectories: [String]

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundleRoot: URL? = Bundle.main.resourceURL?.appendingPathComponent("Toolchains", isDirectory: true),
        managedRoot: URL? = nil,
        systemDirectories: [String] = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin"
        ]
    ) {
        self.fileManager = fileManager
        self.environment = environment
        self.bundleRoot = bundleRoot
        self.managedRoot = managedRoot ?? fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("GORKH/Toolchains", isDirectory: true)
        self.systemDirectories = systemDirectories
    }

    func resolveAll(now: Date = Date()) -> WorkstationToolchainSnapshot {
        WorkstationToolchainSnapshot(
            resolutions: WorkstationToolchainComponent.allCases.map { resolve($0, now: now) }
        )
    }

    func resolve(_ component: WorkstationToolchainComponent, now: Date = Date()) -> WorkstationToolchainResolution {
        for candidate in candidatePaths(for: component) {
            guard isValidExecutable(candidate.path, expectedName: component.executableName) else {
                continue
            }
            return WorkstationToolchainResolution(
                component: component,
                source: candidate.source,
                status: .available,
                executablePath: candidate.path,
                version: nil,
                lastCheckedAt: now,
                message: "Executable resolved from \(candidate.source.title.lowercased()) path."
            )
        }
        return .missing(component)
    }

    func isValidExecutable(_ path: String, expectedName: String) -> Bool {
        guard path.hasPrefix("/"),
              path.contains("..") == false,
              path.contains(";") == false,
              path.contains("|") == false,
              path.contains("&") == false,
              path.contains("`") == false,
              URL(fileURLWithPath: path).lastPathComponent == expectedName else {
            return false
        }
        return fileManager.isExecutableFile(atPath: path)
    }

    private func candidatePaths(for component: WorkstationToolchainComponent) -> [(path: String, source: WorkstationToolchainSource)] {
        var candidates: [(String, WorkstationToolchainSource)] = []
        if let bundleRoot {
            candidates.append((bundleRoot.appendingPathComponent(component.executableName).path, .bundled))
            candidates.append((bundleRoot.appendingPathComponent(component.executableName).appendingPathComponent("bin/\(component.executableName)").path, .bundled))
        }
        candidates.append((managedRoot.appendingPathComponent(component.executableName).path, .managed))
        candidates.append((managedRoot.appendingPathComponent(component.executableName).appendingPathComponent("bin/\(component.executableName)").path, .managed))
        for directory in systemDirectories {
            candidates.append((URL(fileURLWithPath: directory).appendingPathComponent(component.executableName).path, .system))
        }
        for directory in pathDirectoriesFromEnvironment() {
            candidates.append((URL(fileURLWithPath: directory).appendingPathComponent(component.executableName).path, .system))
        }
        return candidates
    }

    private func pathDirectoriesFromEnvironment() -> [String] {
        guard let path = environment["PATH"] else {
            return []
        }
        return path
            .split(separator: ":")
            .map(String.init)
            .filter { $0.hasPrefix("/") && !$0.contains("..") && !$0.contains(";") && !$0.contains("|") && !$0.contains("&") }
    }
}
