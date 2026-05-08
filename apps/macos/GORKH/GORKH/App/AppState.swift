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
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wallet:
            return "Wallet"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .wallet:
            return "wallet.pass"
        case .settings:
            return "gearshape"
        }
    }
}
