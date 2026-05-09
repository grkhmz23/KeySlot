import Foundation

struct OrcaReadOnlyAdapter: LPPositionAdapter {
    let protocolKind: LPProtocolKind = .orca

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LPAdapterResult {
        .unavailable(
            protocolKind: protocolKind,
            reason: "Orca Whirlpools read-only position tracking is a placeholder pending isolated SDK review.",
            updatedAt: Date()
        )
    }
}
