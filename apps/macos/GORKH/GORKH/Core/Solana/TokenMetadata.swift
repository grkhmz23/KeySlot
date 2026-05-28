import Foundation

enum TokenMetadataSource: String, Codable, Equatable {
    case knownRegistry = "known_registry"
    case parsedAccount = "parsed_account"
    case mintAccount = "mint_account"
    case unknown = "unknown"
}

enum TokenCategory: String, Codable, Equatable {
    case stablecoin
    case liquidStakingToken = "liquid_staking_token"
    case wrappedNative = "wrapped_native"
    case meme
    case unknown
}

struct TokenMetadataFlags: Codable, Equatable {
    let nonFreezable: Bool
    let noBlacklist: Bool
    let noPause: Bool
    let standardSPL: Bool

    static let none = TokenMetadataFlags(
        nonFreezable: false,
        noBlacklist: false,
        noPause: false,
        standardSPL: false
    )
}

struct TokenMetadata: Codable, Equatable, Identifiable {
    var id: String { "\(network?.rawValue ?? "all"):\(mintAddress)" }

    let mintAddress: String
    let symbol: String
    let name: String
    let decimals: UInt8?
    let network: WalletNetwork?
    let warning: String?
    let category: TokenCategory
    let flags: TokenMetadataFlags

    init(
        mintAddress: String,
        symbol: String,
        name: String,
        decimals: UInt8?,
        network: WalletNetwork?,
        warning: String?,
        category: TokenCategory = .unknown,
        flags: TokenMetadataFlags = .none
    ) {
        self.mintAddress = mintAddress
        self.symbol = symbol
        self.name = name
        self.decimals = decimals
        self.network = network
        self.warning = warning
        self.category = category
        self.flags = flags
    }
}

struct ResolvedTokenMetadata: Codable, Equatable {
    let mintAddress: String
    let symbol: String
    let name: String
    let decimals: UInt8?
    let network: WalletNetwork
    let source: TokenMetadataSource
    let decimalsSource: TokenMetadataSource
    let warning: String?
    let category: TokenCategory
    let flags: TokenMetadataFlags

    var isKnown: Bool {
        source == .knownRegistry
    }

    var displayTitle: String {
        isKnown ? "\(symbol) - \(name)" : "Unknown Token"
    }

    var displaySubtitle: String {
        isKnown ? mintAddress.shortAddress : "Mint \(mintAddress.shortAddress)"
    }
}

enum TokenWarning: String, Codable, Equatable, CaseIterable, Identifiable {
    case unknownToken = "unknown_token"
    case devnetToken = "devnet_token"
    case frozenAccount = "frozen_account"
    case delegatedAccount = "delegated_account"
    case closeAuthorityPresent = "close_authority_present"
    case zeroBalance = "zero_balance"
    case decimalsUnavailable = "decimals_unavailable"
    case token2022Unsupported = "token_2022_unsupported"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unknownToken:
            return "Unknown token"
        case .devnetToken:
            return "Devnet token"
        case .frozenAccount:
            return "Frozen account"
        case .delegatedAccount:
            return "Delegated account"
        case .closeAuthorityPresent:
            return "Close authority"
        case .zeroBalance:
            return "Zero balance"
        case .decimalsUnavailable:
            return "Decimals unavailable"
        case .token2022Unsupported:
            return "Token-2022 locked"
        }
    }

    var message: String {
        switch self {
        case .unknownToken:
            return "This mint is not in KeySlot's local known-token registry. Verify the mint before sending."
        case .devnetToken:
            return "This appears on devnet and may be a temporary test token."
        case .frozenAccount:
            return "This token account is frozen and cannot send tokens."
        case .delegatedAccount:
            return "This token account has a delegate. Review the account before approving."
        case .closeAuthorityPresent:
            return "This token account has a close authority configured."
        case .zeroBalance:
            return "This token account has a zero raw balance."
        case .decimalsUnavailable:
            return "Token decimals could not be resolved. Sending is blocked."
        case .token2022Unsupported:
            return "Token-2022 sending remains locked until extension-aware handling is implemented."
        }
    }

    var blocksSend: Bool {
        switch self {
        case .frozenAccount, .decimalsUnavailable, .token2022Unsupported:
            return true
        case .unknownToken, .devnetToken, .delegatedAccount, .closeAuthorityPresent, .zeroBalance:
            return false
        }
    }
}
