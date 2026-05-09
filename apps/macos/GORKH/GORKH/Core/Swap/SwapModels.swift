import Foundation

enum SwapConstants {
    static let nativeSolMint = PortfolioConstants.nativeSolMint
    static let quoteSource = "jupiter-swap-v1"
    static let quoteMaxAgeSeconds: TimeInterval = 60
}

enum SwapError: LocalizedError, Equatable {
    case invalidInput(String)
    case quoteStale
    case missingQuote
    case missingBuiltTransaction
    case reviewFailed(String)
    case simulationRequired
    case simulationFailed(String)
    case signingBlocked(String)
    case unsupportedNetwork(String)
    case transport(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message),
             .reviewFailed(let message),
             .simulationFailed(let message),
             .signingBlocked(let message),
             .unsupportedNetwork(let message),
             .transport(let message):
            return message
        case .quoteStale:
            return "The Jupiter quote is stale. Request a fresh quote before building or signing."
        case .missingQuote:
            return "Request a Jupiter quote first."
        case .missingBuiltTransaction:
            return "Build and review the swap transaction first."
        case .simulationRequired:
            return "Simulate this swap transaction before approval."
        case .invalidResponse:
            return "Jupiter returned an invalid response."
        }
    }
}

struct SwapTokenOption: Equatable, Identifiable {
    var id: String { mintAddress }

    let mintAddress: String
    let symbol: String
    let name: String
    let decimals: UInt8?
    let balanceRaw: UInt64
    let uiAmountString: String
    let isNativeSOL: Bool
    let tokenProgramKind: TokenProgramKind?
    let warnings: [TokenWarning]

    var canUseAsInput: Bool {
        decimals != nil && balanceRaw > 0 && !warnings.contains { $0.blocksSend }
    }
}

struct SwapRouteLeg: Codable, Equatable, Identifiable {
    var id: String { "\(ammKey):\(inputMint):\(outputMint):\(percent)" }

    let ammKey: String
    let label: String
    let inputMint: String
    let outputMint: String
    let inAmount: UInt64
    let outAmount: UInt64
    let feeAmount: UInt64?
    let feeMint: String?
    let percent: Int
    let bps: Int?
}

struct JupiterQuoteSummary: Equatable, Identifiable {
    let id: UUID
    let inputMint: String
    let outputMint: String
    let inAmount: UInt64
    let outAmount: UInt64
    let otherAmountThreshold: UInt64
    let swapMode: String
    let slippageBps: Int
    let priceImpactPct: Decimal?
    let routePlan: [SwapRouteLeg]
    let contextSlot: UInt64?
    let timeTaken: Decimal?
    let quotedAt: Date
    let rawQuoteJSON: Data

    init(
        id: UUID = UUID(),
        inputMint: String,
        outputMint: String,
        inAmount: UInt64,
        outAmount: UInt64,
        otherAmountThreshold: UInt64,
        swapMode: String,
        slippageBps: Int,
        priceImpactPct: Decimal?,
        routePlan: [SwapRouteLeg],
        contextSlot: UInt64?,
        timeTaken: Decimal?,
        quotedAt: Date = Date(),
        rawQuoteJSON: Data
    ) {
        self.id = id
        self.inputMint = inputMint
        self.outputMint = outputMint
        self.inAmount = inAmount
        self.outAmount = outAmount
        self.otherAmountThreshold = otherAmountThreshold
        self.swapMode = swapMode
        self.slippageBps = slippageBps
        self.priceImpactPct = priceImpactPct
        self.routePlan = routePlan
        self.contextSlot = contextSlot
        self.timeTaken = timeTaken
        self.quotedAt = quotedAt
        self.rawQuoteJSON = rawQuoteJSON
    }

    func isStale(relativeTo date: Date = Date(), maxAgeSeconds: TimeInterval = SwapConstants.quoteMaxAgeSeconds) -> Bool {
        date.timeIntervalSince(quotedAt) > maxAgeSeconds
    }

    var routeLabel: String {
        guard !routePlan.isEmpty else {
            return "No route"
        }
        return routePlan.map { "\($0.label) \($0.percent)%" }.joined(separator: " -> ")
    }

    var safeSummary: JupiterQuoteSafeSummary {
        JupiterQuoteSafeSummary(
            quoteID: id,
            inputMint: inputMint,
            outputMint: outputMint,
            inAmount: inAmount,
            outAmount: outAmount,
            otherAmountThreshold: otherAmountThreshold,
            slippageBps: slippageBps,
            priceImpactPct: priceImpactPct,
            routeLabels: routePlan.map(\.label),
            quotedAt: quotedAt
        )
    }
}

struct JupiterQuoteSafeSummary: Codable, Equatable {
    let quoteID: UUID
    let inputMint: String
    let outputMint: String
    let inAmount: UInt64
    let outAmount: UInt64
    let otherAmountThreshold: UInt64
    let slippageBps: Int
    let priceImpactPct: Decimal?
    let routeLabels: [String]
    let quotedAt: Date
}

struct JupiterSwapTransactionBuild: Equatable {
    let quoteID: UUID
    let userPublicKey: String
    let swapTransactionBase64: String
    let lastValidBlockHeight: UInt64?
    let prioritizationFeeLamports: UInt64?
    let computeUnitLimit: UInt64?
    let builtAt: Date
    let transactionFingerprint: String
}

struct SwapApprovalContext: Equatable {
    let quote: JupiterQuoteSummary
    let build: JupiterSwapTransactionBuild
    let review: SwapTransactionReview
    let simulation: SimulationResult?
    let network: WalletNetwork
    let walletPublicKey: String
    let mainnetConfirmation: String
    let hasCompletedDevnetSmoke: Bool
    let vaultState: WalletVaultState
    let hasUnlockedSecret: Bool
    let currentFingerprint: String
    let preparedFingerprint: String?
}

enum SwapValidation {
    static func validateSlippageBps(_ slippageBps: Int) throws {
        guard (1...1_000).contains(slippageBps) else {
            throw SwapError.invalidInput("Use slippage between 1 and 1000 bps.")
        }
    }

    static func validateQuoteRequest(
        inputMint: String,
        outputMint: String,
        amountRaw: UInt64,
        availableRaw: UInt64,
        inputDecimals: UInt8?,
        slippageBps: Int
    ) throws {
        guard SolanaAddressValidator.isValidAddress(inputMint) else {
            throw SwapError.invalidInput("Input mint is invalid.")
        }
        guard SolanaAddressValidator.isValidAddress(outputMint) else {
            throw SwapError.invalidInput("Output mint is invalid.")
        }
        guard inputMint != outputMint else {
            throw SwapError.invalidInput("Input and output tokens must be different.")
        }
        guard inputDecimals != nil else {
            throw SwapError.invalidInput("Input token decimals are unavailable.")
        }
        guard amountRaw > 0 else {
            throw SwapError.invalidInput("Enter an amount greater than 0.")
        }
        guard amountRaw <= availableRaw else {
            throw SwapError.invalidInput("Amount exceeds available input balance.")
        }
        try validateSlippageBps(slippageBps)
    }
}
