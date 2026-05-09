import Foundation

struct MarginFiAccountDiscovery {
    let rpcClient: SolanaRPCClient

    init(rpcClient: SolanaRPCClient = SolanaRPCClient()) {
        self.rpcClient = rpcClient
    }

    func fetchAccounts(
        authority profile: WalletProfile,
        network: WalletNetwork
    ) async throws -> [SolanaProgramAccountData] {
        try MarginFiEndpointGuard.validateProgramID(MarginFiConstants.programID)
        try MarginFiEndpointGuard.validateRPCMethod("getProgramAccounts")

        return try await rpcClient.getFilteredProgramAccountsBase64(
            programID: MarginFiConstants.programID,
            dataSize: MarginFiAccountLayout.accountDataSize,
            memcmpOffset: MarginFiAccountLayout.authorityOffset,
            memcmpBytes: profile.publicAddress,
            network: network
        )
    }
}
