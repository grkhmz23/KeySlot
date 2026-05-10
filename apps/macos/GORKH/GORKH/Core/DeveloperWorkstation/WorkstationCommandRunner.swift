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

    static func safeSummary(_ text: String) -> String {
        let redacted = AgentSafetyRedactor.redact(text.trimmingCharacters(in: .whitespacesAndNewlines))
        if redacted.count <= 1_000 {
            return redacted
        }
        return String(redacted.prefix(1_000)) + "..."
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
        try WorkstationRustToolchainPolicy.validateEnvironmentOverrides(plan.environmentOverrides)
        if let workingDirectory = plan.workingDirectory {
            try Self.validateArgument(workingDirectory)
            guard workingDirectory.hasPrefix("/") else {
                throw WorkstationCommandValidationError.unsafeWorkingDirectory
            }
        }
    }

    private func validateFixedToolchainArguments(_ plan: WorkstationCommandPlan) throws {
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

        if plan.name == "Install AVM",
           let tagIndex = plan.arguments.firstIndex(of: "--tag"),
           plan.arguments.indices.contains(tagIndex + 1) {
            let tag = plan.arguments[tagIndex + 1]
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            if version == WorkstationAnchorVersionPolicy.latestChannel ||
                !WorkstationAnchorVersionPolicy.isFixedCandidate(version) {
                throw WorkstationCommandValidationError.unsafeArgument(tag)
            }
        }
    }

    static func validateArgument(_ argument: String) throws {
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
