import SwiftUI

enum WalletSection: String, CaseIterable, Identifiable {
    case overview
    case portfolio
    case send
    case swap
    case privateWallet
    case security
    case activity

    static let productionOrder: [WalletSection] = [
        .overview,
        .portfolio,
        .send,
        .swap,
        .privateWallet,
        .security,
        .activity
    ]

    static let watchOnlyOrder: [WalletSection] = [
        .overview,
        .portfolio,
        .activity
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .portfolio:
            return "Portfolio"
        case .send:
            return "Send"
        case .swap:
            return "Swap"
        case .privateWallet:
            return "Private"
        case .security:
            return "Security"
        case .activity:
            return "Activity"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "rectangle.grid.2x2"
        case .portfolio:
            return "chart.pie"
        case .send:
            return "paperplane"
        case .swap:
            return "arrow.left.arrow.right"
        case .privateWallet:
            return "eye.slash"
        case .security:
            return "lock.shield"
        case .activity:
            return "clock.arrow.circlepath"
        }
    }
}
