import Foundation

enum PUSDCirculationClientError: LocalizedError, Equatable {
    case invalidResponse
    case rateLimited
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Palm USD circulation response could not be normalized."
        case .rateLimited:
            return "Palm USD circulation API rate limit reached."
        case .unavailable(let message):
            return message
        }
    }
}

final class PUSDCirculationClient {
    private let baseURL: URL
    private let session: URLSession
    private let cacheTTL: TimeInterval
    private var cachedSnapshot: PUSDCirculationSnapshot?

    init(
        baseURL: URL = PUSDConstants.circulationAPIBaseURL,
        session: URLSession = .shared,
        cacheTTL: TimeInterval = 60
    ) {
        self.baseURL = baseURL
        self.session = session
        self.cacheTTL = cacheTTL
    }

    func fetchCirculation(forceRefresh: Bool = false, now: Date = Date()) async -> PUSDCirculationSnapshot {
        if !forceRefresh,
           let cachedSnapshot,
           now.timeIntervalSince(cachedSnapshot.fetchedAt) < cacheTTL,
           cachedSnapshot.status == .loaded {
            return cachedSnapshot
        }

        let url = baseURL.appendingPathComponent("v1/circulation")
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PUSDCirculationClientError.invalidResponse
            }
            let snapshot = try Self.normalize(data: data, statusCode: httpResponse.statusCode, source: url.absoluteString, fetchedAt: now)
            cachedSnapshot = snapshot
            return snapshot
        } catch let error as PUSDCirculationClientError {
            let status: PUSDCirculationStatus = error == .rateLimited ? .rateLimited : .unavailable
            return PUSDCirculationSnapshot(
                status: status,
                totalCirculating: nil,
                solanaCirculating: nil,
                chainTotals: [],
                updatedAt: nil,
                fetchedAt: now,
                source: url.absoluteString,
                errorMessage: error.localizedDescription
            )
        } catch {
            return PUSDCirculationSnapshot(
                status: .error,
                totalCirculating: nil,
                solanaCirculating: nil,
                chainTotals: [],
                updatedAt: nil,
                fetchedAt: now,
                source: url.absoluteString,
                errorMessage: error.localizedDescription
            )
        }
    }

    static func normalize(
        data: Data,
        statusCode: Int,
        source: String = "\(PUSDConstants.circulationAPIBaseURL.absoluteString)\(PUSDConstants.circulationEndpointPath)",
        fetchedAt: Date = Date()
    ) throws -> PUSDCirculationSnapshot {
        if statusCode == 429 {
            throw PUSDCirculationClientError.rateLimited
        }
        guard (200..<300).contains(statusCode) else {
            throw PUSDCirculationClientError.unavailable("Palm USD circulation API returned HTTP \(statusCode).")
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PUSDCirculationClientError.invalidResponse
        }

        let root = unwrapDataObject(object)
        let chainTotals = parseChainTotals(root)
        let total = decimalValue(
            forKeys: ["totalCirculating", "total_circulating", "circulatingSupply", "circulating_supply", "totalSupply", "total_supply", "circulating", "total"],
            in: root
        ) ?? (chainTotals.isEmpty ? nil : chainTotals.map(\.amount).reduce(Decimal(0), +))
        let solana = decimalValue(
            forKeys: ["solanaCirculating", "solana_circulating", "solana", "sol"],
            in: root
        ) ?? chainTotals.first { $0.chain.lowercased().contains("solana") }?.amount
        let updatedAt = dateValue(
            forKeys: ["updatedAt", "updated_at", "timestamp", "asOf", "as_of"],
            in: root
        )

        return PUSDCirculationSnapshot(
            status: .loaded,
            totalCirculating: total,
            solanaCirculating: solana,
            chainTotals: chainTotals,
            updatedAt: updatedAt,
            fetchedAt: fetchedAt,
            source: source,
            errorMessage: nil
        )
    }

    private static func unwrapDataObject(_ object: [String: Any]) -> [String: Any] {
        if let data = object["data"] as? [String: Any] {
            return data
        }
        if let data = object["data"] as? [[String: Any]], let first = data.first {
            return first
        }
        if let result = object["result"] as? [String: Any] {
            return result
        }
        return object
    }

    private static func parseChainTotals(_ root: [String: Any]) -> [PUSDChainCirculation] {
        let dictionaryKeys = ["chains", "byChain", "by_chain", "circulationByChain", "circulation_by_chain", "chainTotals", "chain_totals"]
        for key in dictionaryKeys {
            if let dictionary = root[key] as? [String: Any] {
                return dictionary.compactMap { chain, value in
                    decimal(from: value).map { PUSDChainCirculation(chain: chain, amount: $0) }
                }
                .sorted { $0.chain < $1.chain }
            }
            if let array = root[key] as? [[String: Any]] {
                return array.compactMap { item in
                    guard let chain = stringValue(forKeys: ["chain", "network", "name"], in: item),
                          let amount = decimalValue(forKeys: ["amount", "circulating", "circulatingSupply", "circulating_supply", "total"], in: item) else {
                        return nil
                    }
                    return PUSDChainCirculation(chain: chain, amount: amount)
                }
                .sorted { $0.chain < $1.chain }
            }
        }
        return []
    }

    private static func decimalValue(forKeys keys: [String], in object: [String: Any]) -> Decimal? {
        for key in keys {
            if let value = object[key], let decimal = decimal(from: value) {
                return decimal
            }
        }
        return nil
    }

    private static func decimal(from value: Any) -> Decimal? {
        if let decimal = value as? Decimal {
            return decimal
        }
        if let number = value as? NSNumber {
            return number.decimalValue
        }
        if let string = value as? String {
            let normalized = string
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
        }
        if let object = value as? [String: Any] {
            return decimalValue(forKeys: ["amount", "value", "circulating", "total"], in: object)
        }
        return nil
    }

    private static func stringValue(forKeys keys: [String], in object: [String: Any]) -> String? {
        for key in keys {
            if let value = object[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func dateValue(forKeys keys: [String], in object: [String: Any]) -> Date? {
        for key in keys {
            guard let value = object[key] else {
                continue
            }
            if let string = value as? String {
                if let date = ISO8601DateFormatter().date(from: string) {
                    return date
                }
                if let seconds = TimeInterval(string) {
                    return Date(timeIntervalSince1970: seconds)
                }
            }
            if let number = value as? NSNumber {
                return Date(timeIntervalSince1970: number.doubleValue)
            }
        }
        return nil
    }
}
