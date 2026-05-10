import Foundation

struct WorkstationDevnetFaucetService {
    private let rpcClient: SolanaRPCClient

    init(rpcClient: SolanaRPCClient = SolanaRPCClient()) {
        self.rpcClient = rpcClient
    }

    func requestCappedDevnetFunds(address: String, amountText: String) async throws -> String {
        let lamports = try SolanaAmountValidator.lamports(fromSOLText: amountText)
        return try await rpcClient.requestAirdrop(address: address, lamports: lamports, network: .devnet)
    }
}
