import Foundation

enum WorkstationComputeEstimateStatus: String, Codable, Equatable {
    case notRun
    case simulated
    case failed
    case unavailable
}

struct WorkstationComputeEstimate: Codable, Equatable {
    let status: WorkstationComputeEstimateStatus
    let unitsConsumed: UInt64?
    let logs: [String]
    let errorMessage: String?
    let perInstructionAvailable: Bool

    static let notRun = WorkstationComputeEstimate(
        status: .notRun,
        unitsConsumed: nil,
        logs: [],
        errorMessage: nil,
        perInstructionAvailable: false
    )
}

struct WorkstationComputeEstimator {
    static func summarize(simulation: TransactionStudioSimulationSummary) -> WorkstationComputeEstimate {
        switch simulation.status {
        case .notRun:
            return .notRun
        case .success:
            return WorkstationComputeEstimate(
                status: .simulated,
                unitsConsumed: simulation.unitsConsumed,
                logs: simulation.logs.map(AgentSafetyRedactor.redact),
                errorMessage: nil,
                perInstructionAvailable: false
            )
        case .failed:
            return WorkstationComputeEstimate(
                status: .failed,
                unitsConsumed: simulation.unitsConsumed,
                logs: simulation.logs.map(AgentSafetyRedactor.redact),
                errorMessage: simulation.errorMessage.map(AgentSafetyRedactor.redact),
                perInstructionAvailable: false
            )
        case .unavailable:
            return WorkstationComputeEstimate(
                status: .unavailable,
                unitsConsumed: nil,
                logs: [],
                errorMessage: simulation.errorMessage.map(AgentSafetyRedactor.redact) ?? "Simulation unavailable.",
                perInstructionAvailable: false
            )
        }
    }
}
