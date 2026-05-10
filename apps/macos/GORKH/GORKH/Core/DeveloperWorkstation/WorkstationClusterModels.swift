import Foundation

enum WorkstationCluster: String, Codable, CaseIterable, Identifiable {
    case localnet
    case devnet
    case testnet
    case mainnetBeta = "mainnet-beta"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localnet:
            return "Localnet"
        case .devnet:
            return "Devnet"
        case .testnet:
            return "Testnet"
        case .mainnetBeta:
            return "Mainnet Beta"
        }
    }

    var rpcURL: URL {
        switch self {
        case .localnet:
            return URL(string: "http://127.0.0.1:8899")!
        case .devnet:
            return WalletNetwork.devnet.rpcURL
        case .testnet:
            return URL(string: "https://api.testnet.solana.com")!
        case .mainnetBeta:
            return WalletNetwork.mainnetBeta.rpcURL
        }
    }

    var webSocketURL: URL {
        switch self {
        case .localnet:
            return URL(string: "ws://127.0.0.1:8900")!
        case .devnet:
            return WalletNetwork.devnet.webSocketURL
        case .testnet:
            return URL(string: "wss://api.testnet.solana.com")!
        case .mainnetBeta:
            return WalletNetwork.mainnetBeta.webSocketURL
        }
    }

    var walletNetwork: WalletNetwork? {
        switch self {
        case .devnet:
            return .devnet
        case .mainnetBeta:
            return .mainnetBeta
        case .localnet, .testnet:
            return nil
        }
    }

    var programOpsMode: WorkstationClusterWriteMode {
        switch self {
        case .localnet, .devnet:
            return .enabled
        case .testnet:
            return .readOnlyLimited
        case .mainnetBeta:
            return .lockedMainnet
        }
    }

    var allowsAirdrop: Bool {
        self == .localnet || self == .devnet
    }

    var isMainnet: Bool {
        self == .mainnetBeta
    }
}

enum WorkstationClusterWriteMode: String, Codable, Equatable {
    case enabled
    case readOnlyLimited = "read_only_limited"
    case lockedMainnet = "locked_mainnet"

    var title: String {
        switch self {
        case .enabled:
            return "Local/dev writes enabled"
        case .readOnlyLimited:
            return "Limited read-only"
        case .lockedMainnet:
            return "Mainnet program ops locked"
        }
    }
}
