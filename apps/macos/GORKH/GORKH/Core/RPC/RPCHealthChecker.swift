import Foundation

struct RPCHealthChecker {
    private let rpcClient: SolanaRPCClient
    private let configuration: RPCFastConfiguration

    init(
        rpcClient: SolanaRPCClient = SolanaRPCClient(),
        configuration: RPCFastConfiguration? = nil
    ) {
        self.rpcClient = rpcClient
        self.configuration = configuration ?? rpcClient.configuration
    }

    func check(network: WalletNetwork) async -> RPCHealthSnapshot {
        guard configuration.tokenStatus(for: network) == .present else {
            return .tokenMissing(network: network, configuration: configuration)
        }

        let endpoint = configuration.endpoint(for: network)
        let startedAt = Date()

        do {
            _ = try await rpcClient.getHealth(network: network)
            async let version = try? rpcClient.getVersion(network: network)
            async let slot = try? rpcClient.getSlot(network: network)
            async let blockHeight = try? rpcClient.getBlockHeight(network: network)

            let resolvedVersion = await version
            let resolvedSlot = await slot
            let resolvedBlockHeight = await blockHeight
            let latency = max(0, Int(Date().timeIntervalSince(startedAt) * 1000))

            let status: RPCProviderStatus = (resolvedSlot == nil && resolvedBlockHeight == nil) ? .degraded : .healthy
            let errorMessage = status == .degraded ? "RPC Fast health succeeded, but slot or block height was unavailable." : nil

            return RPCHealthSnapshot(
                provider: endpoint.provider,
                network: endpoint.network,
                httpEndpointHost: endpoint.httpHost,
                webSocketEndpointHost: endpoint.webSocketHost,
                tokenStatus: .present,
                status: status,
                latencyMilliseconds: latency,
                slot: resolvedSlot,
                blockHeight: resolvedBlockHeight,
                version: resolvedVersion,
                checkedAt: Date(),
                errorMessage: errorMessage,
                beamStatus: RPCFastConfiguration.beamStatus
            )
        } catch {
            let normalized = RPCErrorNormalizer.normalize(error, configuration: configuration)
            return RPCHealthSnapshot(
                provider: endpoint.provider,
                network: endpoint.network,
                httpEndpointHost: endpoint.httpHost,
                webSocketEndpointHost: endpoint.webSocketHost,
                tokenStatus: .present,
                status: normalized.category == .timeout ? .degraded : .unavailable,
                latencyMilliseconds: max(0, Int(Date().timeIntervalSince(startedAt) * 1000)),
                slot: nil,
                blockHeight: nil,
                version: nil,
                checkedAt: Date(),
                errorMessage: normalized.message,
                beamStatus: RPCFastConfiguration.beamStatus
            )
        }
    }
}
