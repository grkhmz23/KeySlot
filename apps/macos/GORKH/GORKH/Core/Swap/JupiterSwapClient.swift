import CryptoKit
import Foundation

struct JupiterSwapClient {
    private let session: URLSession
    private let baseURL: URL
    private let timeout: TimeInterval
    private let configuration: JupiterAPIConfiguration

    init(
        session: URLSession = .shared,
        baseURL: URL? = nil,
        timeout: TimeInterval = 12,
        configuration: JupiterAPIConfiguration = JupiterAPIConfiguration()
    ) {
        self.session = session
        self.baseURL = baseURL ?? configuration.swapBaseURL
        self.timeout = timeout
        self.configuration = configuration
    }

    func buildSwapTransaction(
        quote: JupiterQuoteSummary,
        userPublicKey: String,
        network: WalletNetwork
    ) async throws -> JupiterSwapTransactionBuild {
        guard network == .mainnetBeta else {
            throw SwapError.unsupportedNetwork("Jupiter swap transaction building is available for mainnet assets only.")
        }
        guard !quote.isStale() else {
            throw SwapError.quoteStale
        }
        guard SolanaAddressValidator.isValidAddress(userPublicKey) else {
            throw SwapError.invalidInput("Swap user public key is invalid.")
        }
        try Self.validateBaseURL(baseURL)
        let quoteObject = try Self.quoteObject(from: quote.rawQuoteJSON)
        let body: [String: Any] = [
            "userPublicKey": userPublicKey,
            "quoteResponse": quoteObject,
            "wrapAndUnwrapSol": true,
            "asLegacyTransaction": true,
            "dynamicComputeUnitLimit": true
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: baseURL.appendingPathComponent("swap"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        configuration.applyAuthentication(to: &request)
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SwapError.transport("Jupiter swap did not return an HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SwapError.transport("Jupiter swap failed with HTTP \(httpResponse.statusCode).")
        }

        return try Self.decodeSwapResponse(
            data: responseData,
            quoteID: quote.id,
            userPublicKey: userPublicKey,
            builtAt: Date()
        )
    }

    static func decodeSwapResponse(
        data: Data,
        quoteID: UUID,
        userPublicKey: String,
        builtAt: Date = Date()
    ) throws -> JupiterSwapTransactionBuild {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SwapError.invalidResponse
        }
        if let error = object["error"] as? String {
            throw SwapError.transport(error)
        }
        guard let swapTransaction = object["swapTransaction"] as? String,
              !swapTransaction.isEmpty else {
            throw SwapError.invalidResponse
        }
        return JupiterSwapTransactionBuild(
            quoteID: quoteID,
            userPublicKey: userPublicKey,
            swapTransactionBase64: swapTransaction,
            lastValidBlockHeight: JupiterQuoteClient.uint64Value(object["lastValidBlockHeight"]),
            prioritizationFeeLamports: JupiterQuoteClient.uint64Value(object["prioritizationFeeLamports"]),
            computeUnitLimit: JupiterQuoteClient.uint64Value(object["computeUnitLimit"]),
            builtAt: builtAt,
            transactionFingerprint: SwapFingerprint.transactionFingerprint(base64: swapTransaction)
        )
    }

    static func quoteObject(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SwapError.invalidResponse
        }
        return object
    }

    private static func validateBaseURL(_ url: URL) throws {
        let lowercased = url.absoluteString.lowercased()
        guard lowercased == "https://lite-api.jup.ag/swap/v1" ||
              lowercased == "https://api.jup.ag/swap/v1" else {
            throw SwapError.invalidInput("Jupiter swap endpoint is not allowlisted.")
        }
    }
}

enum SwapFingerprint {
    static func quoteFingerprint(_ quote: JupiterQuoteSummary) -> String {
        hash([
            "quote",
            quote.id.uuidString,
            quote.inputMint,
            quote.outputMint,
            "\(quote.inAmount)",
            "\(quote.outAmount)",
            "\(quote.otherAmountThreshold)",
            "\(quote.slippageBps)",
            quote.routeLabel
        ])
    }

    static func transactionFingerprint(base64: String) -> String {
        hash(["transaction", base64])
    }

    static func approvalFingerprint(quote: JupiterQuoteSummary, build: JupiterSwapTransactionBuild) -> String {
        hash([
            "swap-approval",
            quoteFingerprint(quote),
            build.transactionFingerprint,
            build.userPublicKey
        ])
    }

    private static func hash(_ parts: [String]) -> String {
        let canonical = parts.joined(separator: "\u{1f}")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
