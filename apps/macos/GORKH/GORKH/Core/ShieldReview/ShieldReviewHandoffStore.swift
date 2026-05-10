import Foundation

@MainActor
final class ShieldReviewHandoffStore {
    private var handoffs: [UUID: ShieldReviewStudioHandoff] = [:]

    func store(_ handoff: ShieldReviewStudioHandoff) {
        purgeExpired()
        handoffs[handoff.id] = handoff
    }

    func take(_ id: UUID) -> ShieldReviewStudioHandoff? {
        guard let handoff = handoffs.removeValue(forKey: id) else {
            return nil
        }
        if handoff.isExpired {
            return handoff.expiredSummaryOnly()
        }
        return handoff
    }

    func purgeExpired() {
        let now = Date()
        handoffs = handoffs.filter { $0.value.expiresAt > now }
    }

    var count: Int {
        handoffs.count
    }
}

