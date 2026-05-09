import Foundation

struct MarginFiReadOnlyAdapter: LendingPositionAdapter {
    let protocolKind: LendingProtocolKind = .marginFi

    private let programAccountExists: (WalletNetwork) async throws -> Bool

    init(programAccountExists: @escaping (WalletNetwork) async throws -> Bool = { network in
        try await SolanaRPCClient().getAccountExists(address: MarginFiConstants.programID, network: network)
    }) {
        self.programAccountExists = programAccountExists
    }

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LendingAdapterResult {
        let updatedAt = Date()
        guard network == .mainnetBeta else {
            return .unavailable(
                protocolKind: protocolKind,
                reason: MarginFiConstants.unsupportedNetworkReason,
                updatedAt: updatedAt
            )
        }

        do {
            try MarginFiEndpointGuard.validateProgramID(MarginFiConstants.programID)
            try MarginFiEndpointGuard.validateRPCMethod("getAccountInfo")
            let programReachable = try await programAccountExists(network)

            guard programReachable else {
                return LendingAdapterResult(
                    protocolKind: protocolKind,
                    status: .unavailable,
                    positions: [],
                    source: .solanaRPC,
                    updatedAt: updatedAt,
                    errorMessage: "MarginFi v2 program account was not found on mainnet-beta RPC.",
                    marketReserves: []
                )
            }

            return LendingAdapterResult(
                protocolKind: protocolKind,
                status: .unavailable,
                positions: [],
                source: .solanaRPC,
                updatedAt: updatedAt,
                errorMessage: MarginFiConstants.positionParsingUnavailableReason,
                marketReserves: []
            )
        } catch {
            return LendingAdapterResult(
                protocolKind: protocolKind,
                status: .error,
                positions: [],
                source: .solanaRPC,
                updatedAt: updatedAt,
                errorMessage: error.localizedDescription,
                marketReserves: []
            )
        }
    }
}
