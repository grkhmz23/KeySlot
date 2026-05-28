import SwiftUI

enum WalletSection: String, CaseIterable, Identifiable {
    case overview
    case portfolio
    case send
    case swap
    case defi
    case security
    case activity

    static let productionOrder: [WalletSection] = [
        .overview,
        .portfolio,
        .send,
        .swap,
        .defi,
        .security,
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
        case .defi:
            return "DeFi"
        case .security:
            return "Security"
        case .activity:
            return "Activity"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:
            return "Balances, safety state, and quick actions."
        case .portfolio:
            return "Assets, PUSD, DeFi, yield, and PnL."
        case .send:
            return "Receive, send SOL, and review token transfers."
        case .swap:
            return "Swap tokens with custom slippage and contract address."
        case .defi:
            return "PUSD, yield, lending, stake, and liquidity."
        case .security:
            return "Backup, lock, authentication, and RPC status."
        case .activity:
            return "Wallet events with safe technical details."
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
        case .defi:
            return "chart.line.uptrend.xyaxis"
        case .security:
            return "lock.shield"
        case .activity:
            return "clock.arrow.circlepath"
        }
    }
}
