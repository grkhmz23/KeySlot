import Foundation

struct JupiterQuoteClient {
    private let session: URLSession
    private let baseURL: URL
    private let timeout: TimeInterval
    private let configuration: JupiterAPIConfiguration

    init(
        session: URLSession = .shared,
        baseURL: URL? = nil,
        timeout: TimeInterval = 10,
        configuration: JupiterAPIConfiguration = JupiterAPIConfiguration()
    ) {
        self.session = session
        self.baseURL = baseURL ?? configuration.swapBaseURL
        self.timeout = timeout
        self.configuration = configuration
    }

    func fetchQuote(
        inputMint: String,
        outputMint: String,
        amountRaw: UInt64,
        slippageBps: Int,
        network: WalletNetwork
    ) async throws -> JupiterQuoteSummary {
        guard network == .mainnetBeta else {
            throw SwapError.unsupportedNetwork("Jupiter swap routing is available for mainnet assets only.")
        }
        try SwapValidation.validateSlippageBps(slippageBps)
        let url = try Self.quoteURL(
            baseURL: baseURL,
            inputMint: inputMint,
            outputMint: outputMint,
            amountRaw: amountRaw,
            slippageBps: slippageBps
        )
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        configuration.applyAuthentication(to: &request)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SwapError.transport("Jupiter quote did not return an HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SwapError.transport("Jupiter quote failed with HTTP \(httpResponse.statusCode).")
        }

        return try Self.decodeQuote(data: data, quotedAt: Date())
    }

    static func quoteURL(
        baseURL: URL,
        inputMint: String,
        outputMint: String,
        amountRaw: UInt64,
        slippageBps: Int
    ) throws -> URL {
        try validateBaseURL(baseURL)
        var components = URLComponents(url: baseURL.appendingPathComponent("quote"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "inputMint", value: inputMint),
            URLQueryItem(name: "outputMint", value: outputMint),
            URLQueryItem(name: "amount", value: "\(amountRaw)"),
            URLQueryItem(name: "slippageBps", value: "\(slippageBps)"),
            URLQueryItem(name: "swapMode", value: "ExactIn"),
            URLQueryItem(name: "asLegacyTransaction", value: "true"),
            URLQueryItem(name: "restrictIntermediateTokens", value: "true")
        ]
        guard let url = components?.url else {
            throw SwapError.invalidInput("Jupiter quote URL could not be built.")
        }
        return url
    }

    static func decodeQuote(data: Data, quotedAt: Date = Date()) throws -> JupiterQuoteSummary {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SwapError.invalidResponse
        }
        if let error = object["error"] as? String {
            throw SwapError.transport(error)
        }
        guard let inputMint = object["inputMint"] as? String,
              let outputMint = object["outputMint"] as? String,
              let inAmount = uint64Value(object["inAmount"]),
              let outAmount = uint64Value(object["outAmount"]),
              let otherAmountThreshold = uint64Value(object["otherAmountThreshold"]),
              let swapMode = object["swapMode"] as? String,
              let slippageBps = intValue(object["slippageBps"]) else {
            throw SwapError.invalidResponse
        }

        let routePlan = (object["routePlan"] as? [[String: Any]] ?? []).compactMap { Self.parseRouteLeg($0) }
        return JupiterQuoteSummary(
            inputMint: inputMint,
            outputMint: outputMint,
            inAmount: inAmount,
            outAmount: outAmount,
            otherAmountThreshold: otherAmountThreshold,
            swapMode: swapMode,
            slippageBps: slippageBps,
            priceImpactPct: decimalValue(object["priceImpactPct"]),
            routePlan: routePlan,
            contextSlot: uint64Value(object["contextSlot"]),
            timeTaken: decimalValue(object["timeTaken"]),
            quotedAt: quotedAt,
            rawQuoteJSON: data
        )
    }

    private static func validateBaseURL(_ url: URL) throws {
        let lowercased = url.absoluteString.lowercased()
        guard lowercased == "https://lite-api.jup.ag/swap/v1" ||
              lowercased == "https://api.jup.ag/swap/v1" else {
            throw SwapError.invalidInput("Jupiter quote endpoint is not allowlisted.")
        }
    }

    private static func parseRouteLeg(_ entry: [String: Any]) -> SwapRouteLeg? {
        guard let swapInfo = entry["swapInfo"] as? [String: Any],
              let ammKey = swapInfo["ammKey"] as? String,
              let inputMint = swapInfo["inputMint"] as? String,
              let outputMint = swapInfo["outputMint"] as? String,
              let inAmount = uint64Value(swapInfo["inAmount"]),
              let outAmount = uint64Value(swapInfo["outAmount"]),
              let percent = intValue(entry["percent"]) else {
            return nil
        }

        return SwapRouteLeg(
            ammKey: ammKey,
            label: swapInfo["label"] as? String ?? "Unknown route",
            inputMint: inputMint,
            outputMint: outputMint,
            inAmount: inAmount,
            outAmount: outAmount,
            feeAmount: uint64Value(swapInfo["feeAmount"]),
            feeMint: swapInfo["feeMint"] as? String,
            percent: percent,
            bps: intValue(entry["bps"])
        )
    }

    static func uint64Value(_ value: Any?) -> UInt64? {
        if let number = value as? NSNumber {
            return number.uint64Value
        }
        if let string = value as? String {
            return UInt64(string)
        }
        return nil
    }

    static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    static func decimalValue(_ value: Any?) -> Decimal? {
        if let number = value as? NSNumber {
            return number.decimalValue
        }
        if let string = value as? String {
            return Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))
        }
        return nil
    }
}
