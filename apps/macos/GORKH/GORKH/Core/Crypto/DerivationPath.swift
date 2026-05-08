import Foundation

struct DerivationPath: Codable, Hashable, Identifiable {
    struct Component: Hashable {
        let index: UInt32

        var hardenedIndex: UInt32 {
            index | 0x8000_0000
        }
    }

    static let defaultSolana = try! DerivationPath("m/44'/501'/0'/0'")
    static let supportedSolanaDefaults = [
        try! DerivationPath("m/44'/501'/0'"),
        try! DerivationPath("m/44'/501'/0'/0'"),
        try! DerivationPath("m/44'/501'/1'/0'")
    ]

    let rawValue: String
    let components: [Component]

    var id: String {
        rawValue
    }

    var hardenedIndexes: [UInt32] {
        components.map(\.hardenedIndex)
    }

    init(_ rawValue: String) throws {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")

        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.first == "m", parts.count >= 4 else {
            throw DerivationPathError.invalidFormat
        }

        let componentStrings = Array(parts.dropFirst())
        guard componentStrings.count == 3 || componentStrings.count == 4 else {
            throw DerivationPathError.unsupportedPath
        }

        let components = try componentStrings.map(Self.parseHardenedComponent)
        guard components[0].index == 44, components[1].index == 501 else {
            throw DerivationPathError.unsupportedPath
        }

        self.rawValue = "m/" + components.map { "\($0.index)'" }.joined(separator: "/")
        self.components = components
    }

    static func solana(account: UInt32) -> DerivationPath {
        try! DerivationPath("m/44'/501'/\(account)'/0'")
    }

    private nonisolated static func parseHardenedComponent(_ raw: String) throws -> Component {
        guard raw.hasSuffix("'") || raw.hasSuffix("h") || raw.hasSuffix("H") else {
            throw DerivationPathError.nonHardenedComponent
        }

        let numeric = String(raw.dropLast())
        guard !numeric.isEmpty,
              numeric.allSatisfy(\.isNumber),
              let index = UInt32(numeric),
              index < 0x8000_0000 else {
            throw DerivationPathError.invalidFormat
        }

        return Component(index: index)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        try self.init(rawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum DerivationPathError: LocalizedError, Equatable {
    case invalidFormat
    case nonHardenedComponent
    case unsupportedPath

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Derivation path format is invalid."
        case .nonHardenedComponent:
            return "Solana derivation requires hardened Ed25519 path components."
        case .unsupportedPath:
            return "Only Solana paths under m/44'/501' are supported."
        }
    }
}
