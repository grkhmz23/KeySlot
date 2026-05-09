import Foundation

enum YieldRiskClassifier {
    static func classifyLST(status: YieldDataStatus, isHeld: Bool) -> YieldRiskLevel {
        guard status != .unavailable && status != .error else {
            return .unavailable
        }
        return isHeld ? .medium : .unavailable
    }

    static func classifyLending(position: LendingPositionSummary?) -> YieldRiskLevel {
        guard let position else {
            return .unavailable
        }
        switch position.health.riskLevel {
        case .healthy:
            return .medium
        case .caution:
            return .medium
        case .highRisk, .liquidationRisk:
            return .high
        case .unavailable:
            return .unavailable
        }
    }

    static func classifyLendingMarket(status: YieldDataStatus) -> YieldRiskLevel {
        status == .loaded || status == .partial ? .medium : .unavailable
    }

    static func classifyLP(position: LPPositionSummary?) -> YieldRiskLevel {
        guard let position else {
            return .unavailable
        }
        switch position.rangeSummary.state {
        case .inRange:
            return .medium
        case .outOfRange:
            return .high
        case .unknown:
            return position.status == .loaded ? .medium : .unavailable
        }
    }

    static func classifyStablecoinYield(isActive: Bool) -> YieldRiskLevel {
        isActive ? .medium : .unavailable
    }
}
