import Foundation

protocol PortfolioPriceClient {
    func fetchPrices(mintAddresses: [String]) async throws -> [String: PortfolioPriceQuote]
}

enum PortfolioPriceClientError: LocalizedError, Equatable {
    case invalidEndpoint(String)
    case invalidResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let path):
            return "Portfolio price endpoint is not allowed: \(path)."
        case .invalidResponse:
            return "Portfolio price service returned an invalid response."
        case .transport(let message):
            return "Portfolio price request failed: \(message)"
        }
    }
}

struct JupiterPriceClient: PortfolioPriceClient {
    private let session: URLSession
    private let baseURL: URL
    private let timeout: TimeInterval

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://lite-api.jup.ag/price/v3")!,
        timeout: TimeInterval = 8
    ) {
        self.session = session
        self.baseURL = baseURL
        self.timeout = timeout
    }

    func fetchPrices(mintAddresses: [String]) async throws -> [String: PortfolioPriceQuote] {
        let ids = Array(Set(mintAddresses)).sorted()
        guard !ids.isEmpty else {
            return [:]
        }
        let url = try Self.priceURL(baseURL: baseURL, mintAddresses: ids)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PortfolioPriceClientError.transport("Jupiter did not return an HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PortfolioPriceClientError.transport("HTTP \(httpResponse.statusCode)")
        }
        return try Self.decodePriceResponse(data: data, fetchedAt: Date())
    }

    static func priceURL(baseURL: URL, mintAddresses: [String]) throws -> URL {
        try validatePriceEndpoint(baseURL)
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "ids", value: mintAddresses.joined(separator: ","))
        ]
        guard let url = components?.url else {
            throw PortfolioPriceClientError.invalidEndpoint(baseURL.path)
        }
        return url
    }

    static func validatePriceEndpoint(_ url: URL) throws {
        let path = url.path.lowercased()
        let forbidden = ["swap", "quote", "transaction", "limit", "order"]
        guard path == "/price/v3",
              forbidden.allSatisfy({ !path.contains($0) }) else {
            throw PortfolioPriceClientError.invalidEndpoint(url.path)
        }
    }

    static func decodePriceResponse(data: Data, fetchedAt: Date = Date()) throws -> [String: PortfolioPriceQuote] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PortfolioPriceClientError.invalidResponse
        }

        var quotes: [String: PortfolioPriceQuote] = [:]
        for (mint, value) in object {
            guard let entry = value as? [String: Any] else {
                continue
            }
            quotes[mint] = PortfolioPriceQuote(
                mintAddress: mint,
                usdPrice: decimalValue(entry["usdPrice"]),
                source: PortfolioConstants.priceSource,
                blockID: uint64Value(entry["blockId"]),
                priceChange24h: decimalValue(entry["priceChange24h"]),
                fetchedAt: fetchedAt,
                errorMessage: nil
            )
        }
        return quotes
    }

    private static func decimalValue(_ value: Any?) -> Decimal? {
        if let decimal = value as? Decimal {
            return decimal
        }
        if let number = value as? NSNumber {
            return number.decimalValue
        }
        if let string = value as? String {
            return Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))
        }
        return nil
    }

    private static func uint64Value(_ value: Any?) -> UInt64? {
        if let number = value as? NSNumber {
            return number.uint64Value
        }
        if let string = value as? String {
            return UInt64(string)
        }
        return nil
    }
}
