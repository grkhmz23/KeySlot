import Foundation

enum TokenProgramKind: String, Codable, CaseIterable, Identifiable {
    case splToken = "spl_token"
    case token2022 = "token_2022"

    var id: String { rawValue }

    var programID: String {
        switch self {
        case .splToken:
            return SolanaConstants.splTokenProgramID
        case .token2022:
            return SolanaConstants.token2022ProgramID
        }
    }

    var displayName: String {
        switch self {
        case .splToken:
            return "SPL Token"
        case .token2022:
            return "Token-2022"
        }
    }

    var shortName: String {
        switch self {
        case .splToken:
            return "SPL"
        case .token2022:
            return "Token-2022"
        }
    }
}

enum TokenAccountState: String, Codable, Equatable {
    case initialized
    case frozen
    case uninitialized
    case unknown

    init(rawRPCValue: String?) {
        switch rawRPCValue?.lowercased() {
        case "initialized":
            self = .initialized
        case "frozen":
            self = .frozen
        case "uninitialized":
            self = .uninitialized
        default:
            self = .unknown
        }
    }
}

struct TokenMint: Codable, Equatable, Identifiable {
    var id: String { address }

    let address: String
    let decimals: UInt8
    let programKind: TokenProgramKind
}

struct TokenBalance: Codable, Equatable, Identifiable {
    var id: String { tokenAccountAddress }

    let tokenAccountAddress: String
    let ownerAddress: String
    let mintAddress: String
    let amountRaw: UInt64
    let decimals: UInt8
    let uiAmountString: String
    let programKind: TokenProgramKind
    let state: TokenAccountState
    let delegateAddress: String?
    let closeAuthorityAddress: String?
    let fetchedAt: Date

    var displayLabel: String {
        "Mint \(mintAddress.shortAddress)"
    }

    var canSend: Bool {
        programKind == .splToken && state == .initialized && amountRaw > 0
    }
}

struct AssociatedTokenAccountPlan: Codable, Equatable {
    let recipientOwnerAddress: String
    let mintAddress: String
    let tokenProgramKind: TokenProgramKind
    let associatedTokenAddress: String?
    let recipientTokenAccountExists: Bool
    let shouldCreateAssociatedTokenAccount: Bool
    let creationSupported: Bool
    let rentExemptLamports: UInt64?
    let message: String
}

struct TokenTransferDraft: Codable, Equatable, Identifiable {
    let id: UUID
    let network: WalletNetwork
    let ownerAddress: String
    let sourceTokenAccount: String
    let mintAddress: String
    let tokenProgramKind: TokenProgramKind
    let recipientOwnerAddress: String
    let recipientTokenAccount: String?
    let amountRaw: UInt64
    let amountText: String
    let decimals: UInt8
    let availableAmountRaw: UInt64
    let ataPlan: AssociatedTokenAccountPlan
    let createdAt: Date

    init(
        id: UUID = UUID(),
        network: WalletNetwork,
        ownerAddress: String,
        sourceTokenAccount: String,
        mintAddress: String,
        tokenProgramKind: TokenProgramKind,
        recipientOwnerAddress: String,
        recipientTokenAccount: String?,
        amountRaw: UInt64,
        amountText: String,
        decimals: UInt8,
        availableAmountRaw: UInt64,
        ataPlan: AssociatedTokenAccountPlan,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.network = network
        self.ownerAddress = ownerAddress
        self.sourceTokenAccount = sourceTokenAccount
        self.mintAddress = mintAddress
        self.tokenProgramKind = tokenProgramKind
        self.recipientOwnerAddress = recipientOwnerAddress
        self.recipientTokenAccount = recipientTokenAccount
        self.amountRaw = amountRaw
        self.amountText = amountText
        self.decimals = decimals
        self.availableAmountRaw = availableAmountRaw
        self.ataPlan = ataPlan
        self.createdAt = createdAt
    }

    var formattedAmount: String {
        TokenAmountFormatter.format(rawAmount: amountRaw, decimals: decimals)
    }
}

enum TokenTransferValidationError: LocalizedError, Equatable {
    case unsupportedTokenProgram(String)
    case tokenAccountUnavailable(String)
    case associatedTokenAccountCreationUnavailable(String)
    case insufficientBalance(String)
    case invalidDecimals(String)
    case invalidTokenAccount(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedTokenProgram(let message),
             .tokenAccountUnavailable(let message),
             .associatedTokenAccountCreationUnavailable(let message),
             .insufficientBalance(let message),
             .invalidDecimals(let message),
             .invalidTokenAccount(let message):
            return message
        }
    }
}

extension String {
    var shortAddress: String {
        guard count > 12 else {
            return self
        }

        return "\(prefix(4))...\(suffix(4))"
    }
}
