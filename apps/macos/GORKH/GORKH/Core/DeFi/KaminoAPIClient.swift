import Foundation

enum KaminoAPIClientError: LocalizedError, Equatable {
    case unsupportedNetwork(String)
    case endpointBlocked(String)
    case invalidResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedNetwork(let message):
            return message
        case .endpointBlocked(let message):
            return message
        case .invalidResponse:
            return "Kamino public API returned an invalid read-only response."
        case .transport(let message):
            return "Kamino public API request failed: \(message)"
        }
    }
}

struct KaminoAPIClient {
    private let session: URLSession
    private let baseURL: URL
    private let timeout: TimeInterval

    init(
        session: URLSession = .shared,
        baseURL: URL = KaminoConstants.baseURL,
        timeout: TimeInterval = 8
    ) {
        self.session = session
        self.baseURL = baseURL
        self.timeout = timeout
    }

    func fetchMarketConfigs(network: WalletNetwork) async throws -> [KaminoMarketConfig] {
        try validateNetwork(network)
        let url = try url(path: "/v2/kamino-market", queryItems: [])
        try KaminoEndpointGuard.validate(url: url, kind: .marketList)
        let data = try await request(url: url)
        return try JSONDecoder().decode([KaminoMarketConfig].self, from: data)
    }

    func fetchReserveMetrics(market: KaminoMarketConfig, network: WalletNetwork) async throws -> [KaminoReserveMetric] {
        try validateNetwork(network)
        let url = try url(
            path: "/kamino-market/\(market.lendingMarket)/reserves/metrics",
            queryItems: [URLQueryItem(name: "env", value: KaminoConstants.mainnetEnv)]
        )
        try KaminoEndpointGuard.validate(url: url, kind: .reserveMetrics)
        let data = try await request(url: url)
        return try JSONDecoder().decode([KaminoReserveMetric].self, from: data)
    }

    func fetchUserObligations(
        market: KaminoMarketConfig,
        walletAddress: String,
        network: WalletNetwork
    ) async throws -> [KaminoUserObligation] {
        try validateNetwork(network)
        let url = try url(
            path: "/kamino-market/\(market.lendingMarket)/users/\(walletAddress)/obligations",
            queryItems: [URLQueryItem(name: "env", value: KaminoConstants.mainnetEnv)]
        )
        try KaminoEndpointGuard.validate(url: url, kind: .userObligations)
        let data = try await request(url: url)
        return try Self.decodeUserObligations(data: data)
    }

    nonisolated static func decodeUserObligations(data: Data) throws -> [KaminoUserObligation] {
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw KaminoAPIClientError.invalidResponse
        }
        return array.compactMap(Self.normalizeObligation)
    }

    nonisolated static func normalizeObligation(_ object: [String: Any]) -> KaminoUserObligation? {
        guard let obligationAddress = object["obligationAddress"] as? String else {
            return nil
        }
        let state = object["state"] as? [String: Any]
        let marketAddress = state?["lendingMarket"] as? String ?? object["lendingMarket"] as? String ?? ""
        let refreshedStats = object["refreshedStats"] as? [String: Any]

        return KaminoUserObligation(
            obligationAddress: obligationAddress,
            marketAddress: marketAddress,
            deposits: normalizeAssets(
                side: .deposit,
                entries: state?["deposits"] as? [[String: Any]] ?? object["deposits"] as? [[String: Any]] ?? []
            ),
            borrows: normalizeAssets(
                side: .borrow,
                entries: state?["borrows"] as? [[String: Any]] ?? object["borrows"] as? [[String: Any]] ?? []
            ),
            userTotalDepositUSD: KaminoDecimalParser.decimal(refreshedStats?["userTotalDeposit"]),
            userTotalBorrowUSD: KaminoDecimalParser.decimal(refreshedStats?["userTotalBorrow"]),
            netAccountValueUSD: KaminoDecimalParser.decimal(refreshedStats?["netAccountValue"]),
            loanToValue: KaminoDecimalParser.decimal(refreshedStats?["loanToValue"]),
            borrowUtilization: KaminoDecimalParser.decimal(refreshedStats?["borrowUtilization"])
        )
    }

    private nonisolated static func normalizeAssets(
        side: KaminoObligationAsset.Side,
        entries: [[String: Any]]
    ) -> [KaminoObligationAsset] {
        entries.compactMap { entry in
            let reserveKey: String
            let amountKey: String
            switch side {
            case .deposit:
                reserveKey = "depositReserve"
                amountKey = "depositedAmount"
            case .borrow:
                reserveKey = "borrowReserve"
                amountKey = "borrowedAmountSf"
            }
            guard let reserve = entry[reserveKey] as? String,
                  reserve != "11111111111111111111111111111111" else {
                return nil
            }

            let rawAmount = KaminoDecimalParser.uint64(entry[amountKey])
            let amountText = (entry[amountKey] as? String) ?? rawAmount.map(String.init) ?? "Unavailable"
            guard rawAmount != 0 || amountText != "0" else {
                return nil
            }

            return KaminoObligationAsset(
                side: side,
                reserveAddress: reserve,
                rawAmount: rawAmount,
                uiAmountString: amountText,
                usdValue: KaminoDecimalParser.decimal(entry["marketValue"])
                    ?? KaminoDecimalParser.decimal(entry["marketValueUsd"])
                    ?? KaminoDecimalParser.decimal(entry["valueUsd"])
                    ?? KaminoDecimalParser.decimal(entry["usdValue"])
            )
        }
    }

    private func request(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KaminoAPIClientError.transport("Kamino did not return an HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw KaminoAPIClientError.transport("HTTP \(httpResponse.statusCode)")
        }
        return data
    }

    private func validateNetwork(_ network: WalletNetwork) throws {
        guard network == .mainnetBeta else {
            throw KaminoAPIClientError.unsupportedNetwork("Kamino public lending API integration is mainnet-beta read-only only.")
        }
    }

    private func url(path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else {
            throw KaminoAPIClientError.endpointBlocked("Kamino read-only endpoint could not be built.")
        }
        return url
    }
}
