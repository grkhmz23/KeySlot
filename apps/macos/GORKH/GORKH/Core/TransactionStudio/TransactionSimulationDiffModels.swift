import Foundation

enum TransactionSimulationDiffStatus: String, Codable, Equatable {
    case notRequested
    case available
    case unavailable

    var title: String {
        switch self {
        case .notRequested:
            return "Not requested"
        case .available:
            return "Available"
        case .unavailable:
            return "Unavailable"
        }
    }
}

struct TransactionAccountDiff: Codable, Equatable, Identifiable {
    var id: String { address }

    let address: String
    let lamportsBefore: UInt64?
    let lamportsAfter: UInt64?
    let lamportsDelta: Int64?
    let tokenAmountBefore: String?
    let tokenAmountAfter: String?
    let tokenAmountDelta: String?
    let ownerBefore: String?
    let ownerAfter: String?
    let status: String
}

struct TransactionSimulationDiffSummary: Codable, Equatable {
    let status: TransactionSimulationDiffStatus
    let rows: [TransactionAccountDiff]
    let unavailableReason: String?

    static let notRequested = TransactionSimulationDiffSummary(
        status: .notRequested,
        rows: [],
        unavailableReason: "Simulation has not requested account state."
    )

    static func unavailable(_ reason: String) -> TransactionSimulationDiffSummary {
        TransactionSimulationDiffSummary(status: .unavailable, rows: [], unavailableReason: reason)
    }
}
