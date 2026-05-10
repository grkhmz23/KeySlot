import Foundation

struct TransactionAccountEnrichmentService {
    private let rpcClient: SolanaRPCClient

    init(rpcClient: SolanaRPCClient = SolanaRPCClient()) {
        self.rpcClient = rpcClient
    }

    func enrich(decoded: DecodedTransaction, maxCount: Int = TransactionAccountWatchList.defaultLimit) async -> TransactionAccountEnrichmentReport {
        let watchList = TransactionAccountWatchListBuilder.build(decoded: decoded, maxCount: maxCount)
        guard watchList.accounts.isEmpty == false else {
            return TransactionAccountEnrichmentReport(
                status: .unavailable,
                accounts: [],
                requestedCount: 0,
                maxRequestedCount: maxCount,
                truncated: false,
                unavailableReason: "No accounts were available for bounded enrichment.",
                fetchedAt: Date()
            )
        }

        var accounts: [TransactionAccountEnrichment] = []
        var failureCount = 0
        for watch in watchList.accounts {
            do {
                if let account = try await rpcClient.getAccountEnrichmentForStudio(address: watch.address, network: decoded.network) {
                    accounts.append(account)
                } else {
                    failureCount += 1
                }
            } catch {
                failureCount += 1
            }
        }

        let status: TransactionAccountEnrichmentStatus
        if accounts.isEmpty {
            status = .unavailable
        } else if failureCount > 0 || watchList.truncated {
            status = .partial
        } else {
            status = .loaded
        }

        return TransactionAccountEnrichmentReport(
            status: status,
            accounts: accounts,
            requestedCount: watchList.accounts.count,
            maxRequestedCount: maxCount,
            truncated: watchList.truncated,
            unavailableReason: accounts.isEmpty ? "Account enrichment was unavailable from RPC." : nil,
            fetchedAt: Date()
        )
    }
}
