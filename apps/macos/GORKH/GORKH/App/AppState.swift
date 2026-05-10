import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedModule: GORKHModule = .wallet

    let walletManager: WalletManager

    init() {
        self.walletManager = WalletManager()
    }

    init(walletManager: WalletManager) {
        self.walletManager = walletManager
    }
}

enum GORKHModule: String, CaseIterable, Identifiable {
    case wallet
    case agent
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wallet:
            return "Wallet"
        case .agent:
            return "Agent"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .wallet:
            return "wallet.pass"
        case .agent:
            return "sparkles"
        case .settings:
            return "gearshape"
        }
    }
}
