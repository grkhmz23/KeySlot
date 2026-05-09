import Foundation

struct StakeAccountClient {
    let rpcClient: SolanaRPCClient

    init(rpcClient: SolanaRPCClient) {
        self.rpcClient = rpcClient
    }

    func fetchStakeAccounts(profile: WalletProfile, network: WalletNetwork) async throws -> [StakeAccountSummary] {
        try await rpcClient.getStakeAccounts(profile: profile, network: network)
    }
}
