import Foundation

enum TransactionAccountEnrichmentStatus: String, Codable, Equatable {
    case notRun
    case loaded
    case partial
    case unavailable

    var title: String {
        switch self {
        case .notRun:
            return "Not run"
        case .loaded:
            return "Loaded"
        case .partial:
            return "Partial"
        case .unavailable:
            return "Unavailable"
        }
    }
}

struct TransactionAccountEnrichment: Codable, Equatable, Identifiable {
    var id: String { address }

    let address: String
    let ownerProgram: String?
    let ownerLabel: String?
    let lamports: UInt64?
    let executable: Bool?
    let dataLength: Int?
    let tokenMint: String?
    let tokenOwner: String?
    let tokenAmountRaw: String?
    let tokenDecimals: Int?
    let tokenUIAmount: String?
    let source: String
}

struct TransactionAccountEnrichmentReport: Codable, Equatable {
    let status: TransactionAccountEnrichmentStatus
    let accounts: [TransactionAccountEnrichment]
    let requestedCount: Int
    let maxRequestedCount: Int
    let truncated: Bool
    let unavailableReason: String?
    let fetchedAt: Date?

    nonisolated static let notRun = TransactionAccountEnrichmentReport(
        status: .notRun,
        accounts: [],
        requestedCount: 0,
        maxRequestedCount: TransactionAccountWatchList.defaultLimit,
        truncated: false,
        unavailableReason: nil,
        fetchedAt: nil
    )
}

struct TransactionAccountWatch: Codable, Equatable, Identifiable {
    var id: String { "\(address):\(reason)" }

    let address: String
    let reason: String
    let isSigner: Bool
    let isWritable: Bool
}

struct TransactionAccountWatchList: Codable, Equatable {
    nonisolated static let defaultLimit = 20

    let accounts: [TransactionAccountWatch]
    let maxCount: Int
    let truncated: Bool

    nonisolated static let empty = TransactionAccountWatchList(accounts: [], maxCount: defaultLimit, truncated: false)
}
