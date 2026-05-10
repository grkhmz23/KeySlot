import Foundation

enum WorkstationOfflineSigningStatus: String, Codable, Equatable {
    case foundationOnly
    case unsignedDecoded
    case signedImported
    case verificationUnavailable
}

struct WorkstationOfflineSigningState: Codable, Equatable {
    let status: WorkstationOfflineSigningStatus
    let message: String
    let canBroadcast: Bool
    let canSign: Bool

    static let foundation = WorkstationOfflineSigningState(
        status: .foundationOnly,
        message: "Offline signing foundation is review-only in D1. It can decode and verify future files, but cannot sign or broadcast.",
        canBroadcast: false,
        canSign: false
    )
}
