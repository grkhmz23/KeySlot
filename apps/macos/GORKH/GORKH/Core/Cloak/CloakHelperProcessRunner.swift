import Foundation

struct CloakHelperProcessResult: Equatable {
    let exitCode: Int32
    let stdout: Data
    let stderr: String
}

enum CloakHelperProcessError: LocalizedError, Equatable {
    case nonZeroExit(Int32, String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .nonZeroExit(let code, let stderr):
            return "Cloak helper exited with code \(code): \(stderr)"
        case .invalidOutput:
            return "Cloak helper returned invalid output."
        }
    }
}

protocol CloakHelperProcessRunning {
    func run(
        resolvedPath: CloakHelperResolvedPath,
        command: CloakBridgeCommand,
        stdin: Data
    ) async throws -> CloakHelperProcessResult
}

enum CloakHelperEnvironment {
    static func rpcFastMainnetOnly(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var filtered: [String: String] = [:]
        for name in ["GORKH_RPCFAST_MAINNET_TOKEN", "RPCFAST_MAINNET_TOKEN"] {
            if let value = environment[name], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                filtered[name] = value
            }
        }
        return filtered
    }
}

struct CloakHelperDirectProcessRunner: CloakHelperProcessRunning {
    func run(
        resolvedPath: CloakHelperResolvedPath,
        command: CloakBridgeCommand,
        stdin: Data
    ) async throws -> CloakHelperProcessResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let input = Pipe()

        process.executableURL = resolvedPath.nodeExecutable
        process.arguments = [resolvedPath.helperScript.path, command.rawValue]
        process.standardInput = input
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = CloakHelperEnvironment.rpcFastMainnetOnly()

        try process.run()
        try input.fileHandleForWriting.write(contentsOf: stdin)
        try input.fileHandleForWriting.close()
        process.waitUntilExit()

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return CloakHelperProcessResult(
            exitCode: process.terminationStatus,
            stdout: stdoutData,
            stderr: CloakHelperStderrRedactor.redact(stderrText)
        )
    }
}

enum CloakHelperStderrRedactor {
    static func redact(_ value: String) -> String {
        guard !value.isEmpty else {
            return ""
        }
        if Redaction.containsSensitiveMaterial(value)
            || CloakBridgeContractValidator.forbiddenFieldTokens.contains(where: { value.lowercased().contains($0) }) {
            return "[redacted cloak helper stderr]"
        }

        return String(value.prefix(500))
    }
}
