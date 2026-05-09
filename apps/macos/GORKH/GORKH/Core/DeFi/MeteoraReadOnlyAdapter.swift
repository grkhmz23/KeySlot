import Foundation

struct MeteoraReadOnlyAdapter: LPPositionAdapter {
    let protocolKind: LPProtocolKind = .meteora

    private let helperBridge: (any MeteoraHelperBridging)?

    init(helperBridge: (any MeteoraHelperBridging)? = nil) {
        self.helperBridge = helperBridge
    }

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LPAdapterResult {
        let updatedAt = Date()
        guard network == .mainnetBeta else {
            return .unavailable(
                protocolKind: protocolKind,
                reason: "Meteora DLMM read-only LP tracking is mainnet-beta only.",
                updatedAt: updatedAt
            )
        }

        if let helperResult = await helperBridge?.fetchPositions(
            profiles: profiles,
            network: network,
            prices: prices
        ), helperResult.status != .unavailable || !helperResult.positions.isEmpty {
            return helperResult
        }

        return LPAdapterResult(
            protocolKind: protocolKind,
            status: .unavailable,
            positions: [],
            source: .sdkReadOnly,
            updatedAt: updatedAt,
            errorMessage: "Meteora read-only helper is not enabled in the native app bundle. Use tools/meteora-readonly or enable the fixed-path helper policy for development smoke only."
        )
    }
}
