import Foundation

struct ZerionCLICommandRunner {
    let executablePath: String
    let timeoutSeconds: TimeInterval
    let environment: [String: String]

    init(
        executablePath: String,
        timeoutSeconds: TimeInterval = 8,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.executablePath = executablePath
        self.timeoutSeconds = timeoutSeconds
        self.environment = environment
    }

    func run(_ command: ZerionCLICommand) -> ZerionCommandResult {
        run(commandName: command.name, arguments: command.arguments, requiresAPIKey: command.requiresAPIKey)
    }

    func run(commandName: String, arguments: [String], requiresAPIKey: Bool) -> ZerionCommandResult {
        do {
            try ZerionCLICommandBuilder.validateNoUnsafeArgument(arguments)
        } catch {
            return .blocked(command: commandName, reason: error.localizedDescription)
        }

        if requiresAPIKey {
            let apiKeyStatus = ZerionRedaction.apiKeyStatus(from: environment)
            guard apiKeyStatus == .presentRedacted else {
                return .blocked(
                    command: commandName,
                    reason: "ZERION_API_KEY is required for \(commandName), but the key is \(apiKeyStatus.label.lowercased())."
                )
            }
        }

        guard ZerionCLIPathResolver(environment: environment).isValidExecutable(executablePath) else {
            return .blocked(command: commandName, reason: "Zerion executable path failed validation.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        do {
            try process.run()
        } catch {
            return ZerionCommandResult(
                command: commandName,
                status: .failed,
                exitCode: nil,
                stdoutSummary: "",
                stderrSummary: ZerionRedaction.redact(error.localizedDescription),
                completedAt: Date()
            )
        }

        if semaphore.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            process.terminate()
            return ZerionCommandResult(
                command: commandName,
                status: .timedOut,
                exitCode: nil,
                stdoutSummary: "",
                stderrSummary: "Zerion command timed out.",
                completedAt: Date()
            )
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let exitCode = process.terminationStatus

        return ZerionCommandResult(
            command: commandName,
            status: exitCode == 0 ? .succeeded : .failed,
            exitCode: exitCode,
            stdoutSummary: ZerionJSONSummary.safeSummary(from: stdout),
            stderrSummary: ZerionJSONSummary.safeSummary(from: stderr),
            completedAt: Date()
        )
    }
}

enum ZerionJSONSummary {
    static func safeSummary(from text: String) -> String {
        let redacted = ZerionRedaction.redact(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard redacted.count > 500 else {
            return redacted
        }
        return String(redacted.prefix(500)) + "..."
    }

    static func itemCount(from summary: String) -> Int? {
        guard let data = summary.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        if let array = object as? [Any] {
            return array.count
        }
        if let dictionary = object as? [String: Any] {
            if let data = dictionary["data"] as? [Any] {
                return data.count
            }
            if let wallets = dictionary["wallets"] as? [Any] {
                return wallets.count
            }
            if let policies = dictionary["policies"] as? [Any] {
                return policies.count
            }
            if let tokens = dictionary["tokens"] as? [Any] {
                return tokens.count
            }
        }
        return nil
    }
}
