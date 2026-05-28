import Foundation

struct WalletDemoState: Codable, Equatable {
    struct DemoWallet: Codable, Equatable, Identifiable {
        let id: String
        let label: String
        let publicAddress: String
        let role: String
    }

    struct DemoBalance: Codable, Equatable, Identifiable {
        let id: String
        let walletID: String
        let symbol: String
        let mintAddress: String
        let displayAmount: String
        let estimatedUSD: String
        let source: String
    }

    let title: String
    let enabledByDefault: Bool
    let allowsExecution: Bool
    let wallets: [DemoWallet]
    let balances: [DemoBalance]
    let screenCoverage: [String]
    let safetyNotes: [String]

    var containsOnlyWatchOnlyWallets: Bool {
        wallets.allSatisfy { $0.role == "watch-only" }
    }

    static let releaseQA = WalletDemoState(
        title: "Release QA demo state",
        enabledByDefault: false,
        allowsExecution: false,
        wallets: [
            DemoWallet(
                id: "demo-treasury-mainnet",
                label: "Demo Treasury",
                publicAddress: SolanaConstants.systemProgramID,
                role: "watch-only"
            ),
            DemoWallet(
                id: "demo-ops-mainnet",
                label: "Demo Operations",
                publicAddress: "Vote111111111111111111111111111111111111111",
                role: "watch-only"
            )
        ],
        balances: [
            DemoBalance(
                id: "demo-sol",
                walletID: "demo-treasury-mainnet",
                symbol: "SOL",
                mintAddress: "So11111111111111111111111111111111111111112",
                displayAmount: "12.500000000",
                estimatedUSD: "$1,875.00",
                source: "mock-display-only"
            ),
            DemoBalance(
                id: "demo-pusd",
                walletID: "demo-treasury-mainnet",
                symbol: "PUSD",
                mintAddress: PUSDConstants.mintAddress,
                displayAmount: "2,500.000000",
                estimatedUSD: "$2,500.00",
                source: "mock-display-only"
            )
        ],
        screenCoverage: [
            "Overview",
            "Portfolio",
            "Send",
            "Swap",
            "DeFi",
            "Private",
            "Security",
            "Activity",
            "Receive"
        ],
        safetyNotes: [
            "Public watch-only addresses only.",
            "Mock balances are display-only.",
            "Execution is disabled and cannot bypass wallet approval gates.",
            "No API tokens or wallet recovery material are included."
        ]
    )
}
