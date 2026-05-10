import Foundation

enum ShieldReviewPolicy {
    static func requiresBlockingReview(_ summary: ShieldReviewSummary) -> Bool {
        summary.status == .unavailable && summary.unavailableReason?.localizedCaseInsensitiveContains("internal") == true
    }

    static func canContinueAfterReview(summary: ShieldReviewSummary, simulationRequired: Bool) -> Bool {
        if requiresBlockingReview(summary) {
            return false
        }
        if simulationRequired {
            return summary.simulation.status == .success
        }
        return true
    }
}
