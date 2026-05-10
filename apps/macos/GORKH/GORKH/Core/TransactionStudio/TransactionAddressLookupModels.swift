import Foundation

enum TransactionAddressLookupResolutionStatus: String, Codable, Equatable, CaseIterable {
    case loaded
    case unresolved
    case unavailable

    var title: String {
        switch self {
        case .loaded:
            return "Loaded"
        case .unresolved:
            return "Unresolved"
        case .unavailable:
            return "Unavailable"
        }
    }
}

struct TransactionAddressLookupOverview: Codable, Equatable {
    let tableCount: Int
    let loadedWritableCount: Int
    let loadedReadonlyCount: Int
    let unresolvedTableCount: Int

    static let empty = TransactionAddressLookupOverview(
        tableCount: 0,
        loadedWritableCount: 0,
        loadedReadonlyCount: 0,
        unresolvedTableCount: 0
    )
}
