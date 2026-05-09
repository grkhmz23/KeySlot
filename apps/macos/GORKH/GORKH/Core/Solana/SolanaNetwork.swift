import Foundation

enum WalletNetwork: String, CaseIterable, Codable, Identifiable {
    case devnet
    case mainnetBeta = "mainnet-beta"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .devnet:
            return "Devnet"
        case .mainnetBeta:
            return "Mainnet Beta"
        }
    }

    var rpcURL: URL {
        RPCFastConfiguration().httpURL(for: self)
    }

    var webSocketURL: URL {
        RPCFastConfiguration().webSocketURL(for: self)
    }

    var explorerClusterQuery: String {
        switch self {
        case .devnet:
            return "?cluster=devnet"
        case .mainnetBeta:
            return ""
        }
    }

    var isMainnet: Bool {
        self == .mainnetBeta
    }
}
