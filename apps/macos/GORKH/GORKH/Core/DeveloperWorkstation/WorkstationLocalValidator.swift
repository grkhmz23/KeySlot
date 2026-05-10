import Foundation

enum WorkstationLocalValidatorState: String, Codable, Equatable {
    case unchecked
    case running
    case stopped
    case starting
    case stopping
    case unavailable
    case error

    var title: String {
        switch self {
        case .unchecked:
            return "Unchecked"
        case .running:
            return "Running"
        case .stopped:
            return "Stopped"
        case .starting:
            return "Starting"
        case .stopping:
            return "Stopping"
        case .unavailable:
            return "Unavailable"
        case .error:
            return "Error"
        }
    }
}

struct WorkstationLocalValidatorStatus: Codable, Equatable {
    let state: WorkstationLocalValidatorState
    let health: String?
    let slot: UInt64?
    let version: String?
    let ledgerPath: String?
    let startedByGORKH: Bool
    let lastCheckedAt: Date?
    let message: String

    static let unchecked = WorkstationLocalValidatorStatus(
        state: .unchecked,
        health: nil,
        slot: nil,
        version: nil,
        ledgerPath: nil,
        startedByGORKH: false,
        lastCheckedAt: nil,
        message: "Local validator has not been checked."
    )
}

enum WorkstationLocalValidatorCommandBuilder {
    static func start(
        validatorPath: String,
        ledgerPath: String,
        reset: Bool
    ) -> WorkstationCommandPlan {
        var arguments = [
            "--ledger", ledgerPath,
            "--rpc-port", "8899",
            "--faucet-port", "9900",
            "--limit-ledger-size", "50000000"
        ]
        if reset {
            arguments.append("--reset")
        }
        return WorkstationCommandPlan(
            name: "Start local validator",
            executablePath: validatorPath,
            arguments: arguments,
            cluster: .localnet,
            requiresTrustedProject: false,
            writesToCluster: true
        )
    }
}

final class WorkstationLocalValidatorController {
    private var process: Process?
    private(set) var logs: WorkstationLogStreamState = .idle(cluster: .localnet, maxEntries: 200)

    var isStartedByGORKH: Bool {
        process != nil
    }

    func start(plan: WorkstationCommandPlan) throws {
        guard process == nil else {
            return
        }
        try WorkstationCommandRunner().validate(plan)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: plan.executablePath)
        process.arguments = plan.arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let capture: (FileHandle) -> Void = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else {
                return
            }
            let lines = text.split(separator: "\n").map(String.init)
            for line in lines {
                self?.logs = self?.logs.appending(
                    WorkstationLogEntry(cluster: .localnet, programID: "solana-test-validator", signature: nil, line: line)
                ) ?? .idle(cluster: .localnet)
            }
        }

        stdout.fileHandleForReading.readabilityHandler = capture
        stderr.fileHandleForReading.readabilityHandler = capture

        try process.run()
        self.process = process
        logs = logs.started(programID: "solana-test-validator")
    }

    func stop() {
        process?.terminate()
        process = nil
        logs = logs.stopped()
    }
}
