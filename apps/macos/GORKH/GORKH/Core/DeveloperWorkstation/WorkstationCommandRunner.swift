import Foundation

enum WorkstationCommandStatus: String, Codable, Equatable {
    case pending
    case blocked
    case running
    case succeeded
    case failed
    case timedOut = "timed_out"
}

struct WorkstationCommandPlan: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let executablePath: String
    let arguments: [String]
    let environmentOverrides: [String: String]
    let workingDirectory: String?
    let cluster: WorkstationCluster?
    let requiresTrustedProject: Bool
    let writesToCluster: Bool
    let redactedPreview: String

    init(
        id: UUID = UUID(),
        name: String,
        executablePath: String,
        arguments: [String],
        environmentOverrides: [String: String] = [:],
        workingDirectory: String? = nil,
        cluster: WorkstationCluster? = nil,
        requiresTrustedProject: Bool = false,
        writesToCluster: Bool = false
    ) {
        self.id = id
        self.name = name
        self.executablePath = executablePath
        self.arguments = arguments
        self.environmentOverrides = environmentOverrides
        self.workingDirectory = workingDirectory
        self.cluster = cluster
        self.requiresTrustedProject = requiresTrustedProject
        self.writesToCluster = writesToCluster
        self.redactedPreview = AgentSafetyRedactor.redact(([executablePath] + arguments).joined(separator: " "))
    }
}

struct WorkstationCommandResult: Codable, Equatable {
    let planName: String
    let status: WorkstationCommandStatus
    let exitCode: Int32?
    let stdoutSummary: String
    let stderrSummary: String
    let completedAt: Date
}

struct WorkstationCommandRunner {
    let timeoutSeconds: TimeInterval
    let environment: [String: String]

    init(timeoutSeconds: TimeInterval = 20, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.timeoutSeconds = timeoutSeconds
        self.environment = environment
    }

    func run(_ plan: WorkstationCommandPlan) -> WorkstationCommandResult {
        do {
            try validate(plan)
        } catch {
            return WorkstationCommandResult(
                planName: plan.name,
                status: .blocked,
                exitCode: nil,
                stdoutSummary: "",
                stderrSummary: AgentSafetyRedactor.redact(error.localizedDescription),
                completedAt: Date()
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: plan.executablePath)
        process.arguments = plan.arguments
        process.environment = environment.merging(plan.environmentOverrides) { _, override in override }
        if let workingDirectory = plan.workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }

        do {
            try process.run()
        } catch {
            return WorkstationCommandResult(
                planName: plan.name,
                status: .failed,
                exitCode: nil,
                stdoutSummary: "",
                stderrSummary: AgentSafetyRedactor.redact(error.localizedDescription),
                completedAt: Date()
            )
        }

        if semaphore.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            process.terminate()
            return WorkstationCommandResult(
                planName: plan.name,
                status: .timedOut,
                exitCode: nil,
                stdoutSummary: "",
                stderrSummary: "Developer Workstation command timed out.",
                completedAt: Date()
            )
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let exitCode = process.terminationStatus
        return WorkstationCommandResult(
            planName: plan.name,
            status: exitCode == 0 ? .succeeded : .failed,
            exitCode: exitCode,
            stdoutSummary: Self.safeSummary(stdout),
            stderrSummary: Self.safeSummary(stderr),
            completedAt: Date()
        )
    }

    nonisolated static func safeSummary(_ text: String) -> String {
        let redacted = removeSensitiveLabels(AgentSafetyRedactor.redact(text.trimmingCharacters(in: .whitespacesAndNewlines)))
        if redacted.count <= 1_000 {
            return redacted
        }
        return String(redacted.prefix(997)) + "..."
    }

    nonisolated static func removeSensitiveLabels(_ value: String) -> String {
        [
            "privateKey",
            "private key",
            "secretKey",
            "secret key",
            "seed phrase",
            "mnemonic",
            "wallet JSON",
            "signingSeed",
            "signing seed",
            "agent token",
            "api key",
            "keypair"
        ].reduce(value) { text, term in
            text.replacingOccurrences(of: term, with: "[redacted]", options: [.caseInsensitive])
        }
    }

    func validate(_ plan: WorkstationCommandPlan) throws {
        guard plan.executablePath.hasPrefix("/"),
              !plan.executablePath.contains(".."),
              !plan.executablePath.contains(";"),
              !plan.executablePath.contains("|"),
              !plan.executablePath.contains("&"),
              !plan.executablePath.contains("`") else {
            throw WorkstationCommandValidationError.unsafeExecutable
        }
        try plan.arguments.forEach(Self.validateArgument)
        try validateFixedToolchainArguments(plan)
        try validateFixedProgramArguments(plan)
        try WorkstationRustToolchainPolicy.validateEnvironmentOverrides(plan.environmentOverrides)
        if let workingDirectory = plan.workingDirectory {
            try Self.validateArgument(workingDirectory)
            guard workingDirectory.hasPrefix("/") else {
                throw WorkstationCommandValidationError.unsafeWorkingDirectory
            }
        }
    }

    private func validateFixedProgramArguments(_ plan: WorkstationCommandPlan) throws {
        switch plan.name {
        case "Git rev-parse HEAD":
            guard URL(fileURLWithPath: plan.executablePath).lastPathComponent == "git",
                  plan.arguments == ["rev-parse", "HEAD"],
                  plan.writesToCluster == false,
                  plan.cluster == nil else {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        case "Git status porcelain":
            guard URL(fileURLWithPath: plan.executablePath).lastPathComponent == "git",
                  plan.arguments == ["status", "--porcelain"],
                  plan.writesToCluster == false,
                  plan.cluster == nil else {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        case "Anchor build":
            guard plan.arguments == ["build"] else {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        case "Anchor test":
            guard plan.arguments == ["test", "--provider.cluster", WorkstationCluster.localnet.rpcURL.absoluteString],
                  plan.cluster == .localnet,
                  plan.writesToCluster == false else {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        case "Cargo test":
            guard plan.arguments == ["test"],
                  plan.writesToCluster == false,
                  plan.cluster == nil else {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        case "Anchor deploy":
            guard plan.arguments.count == 5,
                  plan.arguments[0] == "deploy",
                  plan.arguments[1] == "--provider.cluster",
                  plan.arguments[3] == "--provider.wallet",
                  WorkstationCluster.allCases.contains(where: { $0.programOpsMode == .enabled && $0.rpcURL.absoluteString == plan.arguments[2] }) else {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        case "Solana program deploy":
            guard plan.arguments.count == 7,
                  Array(plan.arguments[0...1]) == ["program", "deploy"],
                  plan.arguments[3] == "--url",
                  plan.arguments[5] == "--keypair",
                  WorkstationCluster.allCases.contains(where: { $0.programOpsMode == .enabled && $0.rpcURL.absoluteString == plan.arguments[4] }) else {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        case "Solana program upgrade":
            guard plan.arguments.count == 9,
                  Array(plan.arguments[0...1]) == ["program", "deploy"],
                  plan.arguments[3] == "--program-id",
                  SolanaAddressValidator.isValidAddress(plan.arguments[4]),
                  plan.arguments[5] == "--url",
                  plan.arguments[7] == "--keypair",
                  WorkstationCluster.allCases.contains(where: { $0.programOpsMode == .enabled && $0.rpcURL.absoluteString == plan.arguments[6] }) else {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        case "Solana program show":
            guard plan.arguments.count == 5,
                  Array(plan.arguments[0...1]) == ["program", "show"],
                  SolanaAddressValidator.isValidAddress(plan.arguments[2]),
                  plan.arguments[3] == "--url" else {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        case "Solana program close":
            guard plan.arguments.count == 7,
                  Array(plan.arguments[0...1]) == ["program", "close"],
                  SolanaAddressValidator.isValidAddress(plan.arguments[2]),
                  plan.arguments[3] == "--url",
                  plan.arguments[5] == "--keypair",
                  WorkstationCluster.allCases.contains(where: { $0.programOpsMode == .enabled && $0.rpcURL.absoluteString == plan.arguments[4] }) else {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        case "Solana transfer upgrade authority":
            guard plan.arguments.count == 9,
                  Array(plan.arguments[0...1]) == ["program", "set-upgrade-authority"],
                  SolanaAddressValidator.isValidAddress(plan.arguments[2]),
                  plan.arguments[3] == "--new-upgrade-authority",
                  SolanaAddressValidator.isValidAddress(plan.arguments[4]),
                  plan.arguments[5] == "--url",
                  plan.arguments[7] == "--keypair",
                  WorkstationCluster.allCases.contains(where: { $0.programOpsMode == .enabled && $0.rpcURL.absoluteString == plan.arguments[6] }) else {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        case "Solana revoke upgrade authority":
            guard plan.arguments.count == 8,
                  Array(plan.arguments[0...1]) == ["program", "set-upgrade-authority"],
                  SolanaAddressValidator.isValidAddress(plan.arguments[2]),
                  plan.arguments[3] == "--final",
                  plan.arguments[4] == "--url",
                  plan.arguments[6] == "--keypair",
                  WorkstationCluster.allCases.contains(where: { $0.programOpsMode == .enabled && $0.rpcURL.absoluteString == plan.arguments[5] }) else {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        default:
            return
        }

        if plan.writesToCluster, plan.cluster?.programOpsMode != .enabled {
            throw WorkstationCommandValidationError.unsafeArgument(plan.cluster?.rawValue ?? "missing cluster")
        }
    }

    private func validateFixedToolchainArguments(_ plan: WorkstationCommandPlan) throws {
        if URL(fileURLWithPath: plan.executablePath).lastPathComponent == "avm" {
            let allowedSimple = [["--version"], ["list"], ["self-update"]]
            let isAllowedSimple = allowedSimple.contains(plan.arguments)
            let isAllowedAnchorVersionCommand = plan.arguments.count == 2 &&
                ["install", "use"].contains(plan.arguments[0]) &&
                WorkstationAnchorVersionPolicy.isFixedCandidate(plan.arguments[1])
            if !isAllowedSimple && !isAllowedAnchorVersionCommand {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        }

        if plan.arguments.count == 3,
           plan.arguments[0] == "toolchain",
           plan.arguments[1] == "install",
           !WorkstationRustToolchainPolicy.isFixedCandidate(plan.arguments[2]) {
            throw WorkstationCommandValidationError.unsafeArgument(plan.arguments[2])
        }

        if plan.arguments.count == 2,
           ["install", "use"].contains(plan.arguments[0]),
           plan.name.contains("Anchor"),
           !WorkstationAnchorVersionPolicy.isFixedCandidate(plan.arguments[1]) {
            throw WorkstationCommandValidationError.unsafeArgument(plan.arguments[1])
        }

        if plan.arguments.count == 2,
           plan.arguments[1] == "--version",
           plan.arguments[0].hasPrefix("+") {
            let toolchain = String(plan.arguments[0].dropFirst())
            if !WorkstationRustToolchainPolicy.isFixedCandidate(toolchain) {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments[0])
            }
        }

        if plan.name == "AVM self-update",
           plan.arguments != ["self-update"] {
            throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
        }

        if plan.name == "Install AVM" {
            let allowed = [
                "install",
                "--git",
                "https://github.com/solana-foundation/anchor",
                "avm",
                "--force"
            ]
            if plan.arguments != allowed {
                throw WorkstationCommandValidationError.unsafeArgument(plan.arguments.joined(separator: " "))
            }
        }
    }

    nonisolated static func validateArgument(_ argument: String) throws {
        let forbiddenFragments = [";", "|", "&", "`", "$(", ">", "<"]
        if forbiddenFragments.contains(where: { argument.contains($0) }) {
            throw WorkstationCommandValidationError.unsafeArgument(argument)
        }
    }
}

enum WorkstationCommandValidationError: LocalizedError, Equatable {
    case unsafeExecutable
    case unsafeWorkingDirectory
    case unsafeArgument(String)

    var errorDescription: String? {
        switch self {
        case .unsafeExecutable:
            return "Command executable failed fixed-path validation."
        case .unsafeWorkingDirectory:
            return "Command working directory failed validation."
        case .unsafeArgument(let argument):
            return "Command argument is not allowed: \(argument)."
        }
    }
}
