import Foundation

struct OrcaReadOnlyAdapter: LPPositionAdapter {
    let protocolKind: LPProtocolKind = .orca
    let helperBridge: (any OrcaHelperBridging)?

    init(helperBridge: (any OrcaHelperBridging)? = nil) {
        self.helperBridge = helperBridge
    }

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LPAdapterResult {
        guard network == .mainnetBeta else {
            return .unavailable(
                protocolKind: protocolKind,
                reason: "Orca Whirlpools read-only position tracking is mainnet-beta only.",
                updatedAt: Date()
            )
        }

        if let helperResult = await helperBridge?.fetchPositions(profiles: profiles, network: network, prices: prices) {
            return helperResult
        }

        return .unavailable(
            protocolKind: protocolKind,
            reason: "Orca Whirlpools read-only helper is available under tools/orca-readonly, but native invocation is disabled unless explicitly injected for a safe development run.",
            updatedAt: Date()
        )
    }
}
