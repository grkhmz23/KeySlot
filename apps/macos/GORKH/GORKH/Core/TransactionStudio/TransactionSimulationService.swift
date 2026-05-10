import Foundation

struct TransactionSimulationService {
    private let rpcClient: SolanaRPCClient

    init(rpcClient: SolanaRPCClient = SolanaRPCClient()) {
        self.rpcClient = rpcClient
    }

    func simulate(
        decoded: DecodedTransaction,
        enrichment: TransactionAccountEnrichmentReport = .notRun
    ) async -> TransactionStudioSimulationSummary {
        guard let transactionBase64 = decoded.simulationTransactionBase64 else {
            return .unavailable("Decoded transaction has no safe simulation payload.")
        }
        let watchList = TransactionAccountWatchListBuilder.build(decoded: decoded)
        do {
            return try await rpcClient.simulateTransactionForStudio(
                transactionBase64: transactionBase64,
                network: decoded.network,
                watchList: watchList,
                preSimulationAccounts: enrichment.accounts
            )
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }
}
