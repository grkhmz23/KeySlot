import Foundation

enum CostBasisMethod: String, Codable, CaseIterable, Identifiable, Equatable {
    case manual
    case snapshotEstimate = "snapshot_estimate"
    case activityDerived = "activity_derived"
    case unavailable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual:
            return "Manual"
        case .snapshotEstimate:
            return "Snapshot estimate"
        case .activityDerived:
            return "Activity-derived"
        case .unavailable:
            return "Unavailable"
        }
    }
}

struct CostBasisEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let walletPublicAddress: String?
    let tokenMint: String
    let tokenSymbol: String?
    let quantity: Decimal
    let totalCostUSD: Decimal
    let acquisitionDate: Date
    let note: String?
    let method: CostBasisMethod
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        walletPublicAddress: String?,
        tokenMint: String,
        tokenSymbol: String? = nil,
        quantity: Decimal,
        totalCostUSD: Decimal,
        acquisitionDate: Date,
        note: String? = nil,
        method: CostBasisMethod = .manual,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.walletPublicAddress = walletPublicAddress
        self.tokenMint = tokenMint
        self.tokenSymbol = tokenSymbol
        self.quantity = quantity
        self.totalCostUSD = totalCostUSD
        self.acquisitionDate = acquisitionDate
        self.note = note
        self.method = method
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct CostBasisCoverage: Codable, Equatable {
    let method: CostBasisMethod
    let entryCount: Int
    let coveredAssetCount: Int
    let missingAssetCount: Int
    let totalCostUSD: Decimal?
    let status: PnLDataStatus
    let reason: String?

    static func unavailable(reason: String = PnLConstants.costBasisMissingReason) -> CostBasisCoverage {
        CostBasisCoverage(
            method: .unavailable,
            entryCount: 0,
            coveredAssetCount: 0,
            missingAssetCount: 0,
            totalCostUSD: nil,
            status: .unavailable,
            reason: reason
        )
    }
}
