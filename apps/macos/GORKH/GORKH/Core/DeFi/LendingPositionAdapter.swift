import Foundation

protocol LendingPositionAdapter {
    var protocolKind: LendingProtocolKind { get }

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LendingAdapterResult
}

struct MarginFiReadOnlyAdapter: LendingPositionAdapter {
    let protocolKind: LendingProtocolKind = .marginFi

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LendingAdapterResult {
        LendingAdapterResult.unavailable(
            protocolKind: protocolKind,
            reason: "MarginFi read-only position lookup is not wired to a reviewed public endpoint or audited read-only SDK path yet. No action builders are imported."
        )
    }
}
