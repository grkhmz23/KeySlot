import Foundation

struct ZerionCLIPathResolver {
    private let fileManager: FileManager
    private let environment: [String: String]
    private let knownPaths: [String]

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        knownPaths: [String] = ["/opt/homebrew/bin/zerion", "/usr/local/bin/zerion"]
    ) {
        self.fileManager = fileManager
        self.environment = environment
        self.knownPaths = knownPaths
    }

    func resolve() -> ZerionCLIPathResolution {
        for path in knownPaths {
            if isValidExecutable(path) {
                return ZerionCLIPathResolution(status: .installed, executablePath: path, reason: nil)
            }
        }

        for path in pathCandidatesFromEnvironment() {
            if isValidExecutable(path) {
                return ZerionCLIPathResolution(status: .installed, executablePath: path, reason: nil)
            }
        }

        return .missing
    }

    func isValidExecutable(_ path: String) -> Bool {
        guard path.hasPrefix("/"),
              path.contains("..") == false,
              path.contains(";") == false,
              path.contains("|") == false,
              path.contains("&") == false,
              path.contains("`") == false,
              URL(fileURLWithPath: path).lastPathComponent == "zerion" else {
            return false
        }
        return fileManager.isExecutableFile(atPath: path)
    }

    private func pathCandidatesFromEnvironment() -> [String] {
        guard let pathValue = environment["PATH"] else {
            return []
        }
        return pathValue
            .split(separator: ":")
            .map(String.init)
            .filter { $0.hasPrefix("/") && $0.contains("..") == false }
            .map { URL(fileURLWithPath: $0).appendingPathComponent("zerion").path }
    }
}
