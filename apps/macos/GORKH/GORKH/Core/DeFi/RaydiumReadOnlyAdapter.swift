import Foundation

struct RaydiumReadOnlyAdapter: LPPositionAdapter {
    let protocolKind: LPProtocolKind = .raydium

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LPAdapterResult {
        .unavailable(
            protocolKind: protocolKind,
            reason: "Raydium CLMM/CPMM read-only position tracking is a placeholder pending separate protocol review.",
            updatedAt: Date()
        )
    }
}
