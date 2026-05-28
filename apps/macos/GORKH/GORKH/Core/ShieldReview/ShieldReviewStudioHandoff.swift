import Foundation

enum ShieldReviewSourceFlow: String, Codable, Equatable, Hashable, CaseIterable {
    case solSend
    case splSend
    case jupiterSwap
    case orcaHarvest
    case transactionStudio
    case unknown

    var title: String {
        switch self {
        case .solSend:
            return "SOL send"
        case .splSend:
            return "SPL token send"
        case .jupiterSwap:
            return "Jupiter swap"
        case .orcaHarvest:
            return "Orca harvest"
        case .transactionStudio:
            return "Transaction Studio"
        case .unknown:
            return "Unknown approval"
        }
    }
}

enum ShieldReviewPayloadAvailability: String, Codable, Equatable, Hashable, CaseIterable {
    case summaryOnly
    case transientPayload
    case unavailable

    var title: String {
        switch self {
        case .summaryOnly:
            return "Summary only"
        case .transientPayload:
            return "Exact transaction"
        case .unavailable:
            return "Unavailable"
        }
    }

    var studioButtonTitle: String {
        switch self {
        case .transientPayload:
            return "Open exact decode in Transaction Studio"
        case .summaryOnly:
            return "Open summary in Transaction Studio"
        case .unavailable:
            return "Open unavailable summary in Transaction Studio"
        }
    }
}

struct ShieldReviewStudioHandoff: Equatable, Identifiable {
    let id: UUID
    let sourceFlow: ShieldReviewSourceFlow
    let safeSummary: String
    let transientTransactionBase64: String?
    let createdAt: Date
    let expiresAt: Date
    let redactionStatus: String
    let payloadAvailability: ShieldReviewPayloadAvailability
    let unavailableReason: String?

    init(
        id: UUID = UUID(),
        sourceFlow: ShieldReviewSourceFlow,
        safeSummary: String,
        transientTransactionBase64: String?,
        createdAt: Date = Date(),
        expiresAt: Date,
        redactionStatus: String,
        payloadAvailability: ShieldReviewPayloadAvailability,
        unavailableReason: String? = nil
    ) {
        self.id = id
        self.sourceFlow = sourceFlow
        self.safeSummary = safeSummary
        self.transientTransactionBase64 = transientTransactionBase64
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.redactionStatus = redactionStatus
        self.payloadAvailability = payloadAvailability
        self.unavailableReason = unavailableReason
    }

    var isExpired: Bool {
        Date() >= expiresAt
    }

    func expiredSummaryOnly() -> ShieldReviewStudioHandoff {
        ShieldReviewStudioHandoff(
            id: id,
            sourceFlow: sourceFlow,
            safeSummary: safeSummary,
            transientTransactionBase64: nil,
            createdAt: createdAt,
            expiresAt: expiresAt,
            redactionStatus: "payload_expired",
            payloadAvailability: .summaryOnly,
            unavailableReason: "Transient approval payload expired. Summary-only review remains available."
        )
    }
}

