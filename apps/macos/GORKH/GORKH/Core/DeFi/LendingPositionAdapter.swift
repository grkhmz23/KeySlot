import Foundation

protocol LendingPositionAdapter {
    var protocolKind: LendingProtocolKind { get }

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LendingAdapterResult
}
