import Foundation

protocol LPPositionAdapter {
    var protocolKind: LPProtocolKind { get }

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LPAdapterResult
}
