import Foundation

struct TransactionSimulationService {
    private let rpcClient: SolanaRPCClient

    init(rpcClient: SolanaRPCClient = SolanaRPCClient()) {
        self.rpcClient = rpcClient
    }

    func simulate(decoded: DecodedTransaction) async -> TransactionStudioSimulationSummary {
        guard let transactionBase64 = decoded.simulationTransactionBase64 else {
            return .unavailable("Decoded transaction has no safe simulation payload.")
        }
        do {
            return try await rpcClient.simulateTransactionForStudio(transactionBase64: transactionBase64, network: decoded.network)
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }
}
