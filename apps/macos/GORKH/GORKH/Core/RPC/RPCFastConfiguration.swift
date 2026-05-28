import Foundation

struct RPCFastConfiguration: Equatable {
    static let devnetTokenEnvironmentName = "KEYSLOT_RPCFAST_DEVNET_TOKEN"
    static let mainnetTokenEnvironmentName = "KEYSLOT_RPCFAST_MAINNET_TOKEN"
    static let fallbackDevnetTokenEnvironmentName = "RPCFAST_DEVNET_TOKEN"
    static let fallbackMainnetTokenEnvironmentName = "RPCFAST_MAINNET_TOKEN"
    static let beamStatus = "locked-future"

    private static let devnetEndpoint = RPCFastEndpoint(
        provider: .rpcFast,
        network: .devnet,
        httpURL: URL(string: "https://sol-devnet-rpc.rpcfast.com")!,
        webSocketURL: URL(string: "wss://sol-devnet-rpc.rpcfast.com")!
    )
    private static let mainnetEndpoint = RPCFastEndpoint(
        provider: .rpcFast,
        network: .mainnetBeta,
        httpURL: URL(string: "https://solana-rpc.rpcfast.com/")!,
        webSocketURL: URL(string: "wss://solana-rpc.rpcfast.com/")!
    )

    private let environment: [String: String]

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    func endpoint(for network: WalletNetwork) -> RPCFastEndpoint {
        switch network {
        case .devnet:
            return Self.devnetEndpoint
        case .mainnetBeta:
            return Self.mainnetEndpoint
        }
    }

    func httpURL(for network: WalletNetwork) -> URL {
        endpoint(for: network).httpURL
    }

    func webSocketURL(for network: WalletNetwork) -> URL {
        endpoint(for: network).webSocketURL
    }

    func tokenStatus(for network: WalletNetwork) -> RPCFastTokenStatus {
        token(for: network) == nil ? .missing : .present
    }

    func applyAuthentication(to request: inout URLRequest, network: WalletNetwork) {
        guard let token = token(for: network) else {
            return
        }
        request.setValue(token, forHTTPHeaderField: "X-Token")
    }

    func securityStatus(for network: WalletNetwork) -> RPCProviderSecurityStatus {
        RPCProviderSecurityStatus(
            provider: .rpcFast,
            network: RPCNetwork(walletNetwork: network),
            tokenStatus: tokenStatus(for: network),
            tokenEnvironmentNames: tokenEnvironmentNames(for: network),
            beamStatus: Self.beamStatus
        )
    }

    func missingTokenMessage(for network: WalletNetwork) -> String {
        "RPC Fast token missing for \(network.displayName). Set \(tokenEnvironmentNames(for: network).joined(separator: " or "))."
    }

    func redact(_ value: String) -> String {
        RPCFastRedaction.redact(value, knownTokens: knownTokenValues)
    }

    func tokenEnvironmentNames(for network: WalletNetwork) -> [String] {
        switch network {
        case .devnet:
            return [Self.devnetTokenEnvironmentName, Self.fallbackDevnetTokenEnvironmentName]
        case .mainnetBeta:
            return [Self.mainnetTokenEnvironmentName, Self.fallbackMainnetTokenEnvironmentName]
        }
    }

    func token(for network: WalletNetwork) -> String? {
        for name in tokenEnvironmentNames(for: network) {
            if let value = environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private var knownTokenValues: [String] {
        [
            Self.devnetTokenEnvironmentName,
            Self.mainnetTokenEnvironmentName,
            Self.fallbackDevnetTokenEnvironmentName,
            Self.fallbackMainnetTokenEnvironmentName
        ]
        .compactMap { environment[$0] }
        .filter { !$0.isEmpty }
    }
}
