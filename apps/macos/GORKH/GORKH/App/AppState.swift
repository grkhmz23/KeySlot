import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedModule: KeySlotModule = .wallet
    @Published var requestedWalletSection: WalletSection?
    @Published var pendingAgentMessage: String?
    @Published var pendingTransactionStudioSummary: String?
    @Published var pendingShieldReviewStudioHandoffID: UUID?
    @Published var pendingDeveloperWorkstationSection: DeveloperWorkstationSection?

    let walletManager: WalletManager
    private let shieldReviewHandoffStore = ShieldReviewHandoffStore()

    init() {
        self.walletManager = WalletManager()
    }

    init(walletManager: WalletManager) {
        self.walletManager = walletManager
    }

    func requestWalletSection(_ section: WalletSection) {
        requestedWalletSection = section
        selectedModule = .wallet
    }

    func requestAgentMessage(_ message: String) {
        pendingAgentMessage = message
        selectedModule = .agent
    }

    func requestTransactionStudioSummary(_ summary: String) {
        pendingTransactionStudioSummary = summary
        selectedModule = .transactionStudio
    }

    func requestShieldReviewStudioHandoff(_ handoff: ShieldReviewStudioHandoff) {
        shieldReviewHandoffStore.store(handoff)
        pendingShieldReviewStudioHandoffID = handoff.id
        selectedModule = .transactionStudio
    }

    func requestDeveloperWorkstationSection(_ section: DeveloperWorkstationSection) {
        pendingDeveloperWorkstationSection = section
        selectedModule = .developerWorkstation
    }

    func consumePendingDeveloperWorkstationSection() -> DeveloperWorkstationSection? {
        guard let section = pendingDeveloperWorkstationSection else {
            return nil
        }
        pendingDeveloperWorkstationSection = nil
        return section
    }

    func consumePendingShieldReviewStudioHandoff() -> ShieldReviewStudioHandoff? {
        guard let id = pendingShieldReviewStudioHandoffID else {
            return nil
        }
        pendingShieldReviewStudioHandoffID = nil
        return shieldReviewHandoffStore.take(id)
    }
}

enum KeySlotModule: String, CaseIterable, Identifiable {
    case wallet
    case agent
    case transactionStudio
    case developerWorkstation
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wallet:
            return "Wallet"
        case .agent:
            return "Agent"
        case .transactionStudio:
            return "Transaction Studio"
        case .developerWorkstation:
            return "Developer Workstation"
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
        case .transactionStudio:
            return "doc.text.magnifyingglass"
        case .developerWorkstation:
            return "hammer"
        case .settings:
            return "gearshape"
        }
    }
}
