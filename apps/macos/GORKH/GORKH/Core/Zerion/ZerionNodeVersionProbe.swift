import Foundation

struct ZerionNodeVersionProbeResult: Codable, Equatable {
    let status: ZerionCLIInstallStatus
    let version: String?
    let reason: String?
}

struct ZerionNodeVersionProbe {
    let environment: [String: String]
    let knownPaths: [String]

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        knownPaths: [String] = ["/opt/homebrew/bin/node", "/usr/local/bin/node"]
    ) {
        self.environment = environment
        self.knownPaths = knownPaths
    }

    func probe() -> ZerionNodeVersionProbeResult {
        guard let path = resolveNodePath() else {
            return ZerionNodeVersionProbeResult(status: .missing, version: nil, reason: "Node.js was not found.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return ZerionNodeVersionProbeResult(status: .error, version: nil, reason: ZerionRedaction.redact(error.localizedDescription))
        }
        process.waitUntilExit()

        let rawVersion = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawError = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0, let version = rawVersion, version.isEmpty == false else {
            return ZerionNodeVersionProbeResult(status: .error, version: rawVersion, reason: ZerionRedaction.redact(rawError ?? "Node.js version probe failed."))
        }

        return ZerionNodeVersionProbeResult(
            status: majorVersion(from: version).map { $0 >= 20 ? .installed : .incompatible } ?? .error,
            version: version,
            reason: majorVersion(from: version).map { $0 >= 20 ? nil : "Node.js 20 or later is required." } ?? "Could not parse Node.js version."
        )
    }

    private func resolveNodePath() -> String? {
        let fileManager = FileManager.default
        for path in knownPaths where isValidNodeExecutable(path) && fileManager.isExecutableFile(atPath: path) {
            return path
        }

        let pathValue = environment["PATH"] ?? ""
        for directory in pathValue.split(separator: ":").map(String.init) {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("node").path
            if isValidNodeExecutable(candidate) && fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private func isValidNodeExecutable(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return path.hasPrefix("/")
            && path.contains("..") == false
            && path.contains(";") == false
            && path.contains("|") == false
            && url.lastPathComponent == "node"
    }

    private func majorVersion(from version: String) -> Int? {
        let trimmed = version.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        guard let first = trimmed.split(separator: ".").first else {
            return nil
        }
        return Int(String(first))
    }
}
