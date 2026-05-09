import Foundation

enum RaydiumAPIClientError: LocalizedError, Equatable {
    case endpointBlocked(String)
    case invalidResponse(String)
    case badRequest(String)
    case rateLimited
    case server(String)
    case timeout
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .endpointBlocked(let message):
            return message
        case .invalidResponse(let message):
            return "Raydium read-only API returned an invalid response: \(message)"
        case .badRequest(let message):
            return "Raydium read-only API rejected the request: \(message)"
        case .rateLimited:
            return "Raydium read-only API rate limited this request."
        case .server(let message):
            return "Raydium read-only API is degraded: \(message)"
        case .timeout:
            return "Raydium read-only API request timed out."
        case .transport(let message):
            return "Raydium read-only API request failed: \(message)"
        }
    }
}

protocol RaydiumAPIClienting {
    func fetchOwnerStakePositions(owner: String, network: WalletNetwork) async throws -> RaydiumOwnerEndpointResult
    func fetchOwnerCLMMLockPositions(owner: String, network: WalletNetwork) async throws -> RaydiumOwnerEndpointResult
    func fetchPoolInfos(ids: [String], network: WalletNetwork) async throws -> [String: RaydiumPoolInfo]
    func fetchMintInfos(mints: [String], network: WalletNetwork) async throws -> [String: RaydiumMintInfo]
    func fetchMintPrices(mints: [String], network: WalletNetwork) async throws -> [String: Decimal]
    func fetchFarmInfos(lpMint: String, network: WalletNetwork) async throws -> [RaydiumFarmInfo]
}

struct RaydiumAPIClient: RaydiumAPIClienting {
    private let session: URLSession
    private let timeout: TimeInterval

    init(session: URLSession = .shared, timeout: TimeInterval = 8) {
        self.session = session
        self.timeout = timeout
    }

    func fetchOwnerStakePositions(owner: String, network: WalletNetwork) async throws -> RaydiumOwnerEndpointResult {
        let url = try ownerURL(network: network, path: "/position/stake/\(owner)")
        try RaydiumEndpointGuard.validate(url: url, kind: .ownerStake(owner: owner))
        let response = try await request(url: url, treatsNotFoundAsEmpty: true)
        return try Self.decodeOwnerEndpointResult(
            statusCode: response.statusCode,
            data: response.data,
            owner: owner,
            kind: .standardLP,
            sourceEndpoint: "/position/stake/{owner}",
            emptyMessage: "No Raydium AMM/CPMM LP positions returned for this wallet."
        )
    }

    func fetchOwnerCLMMLockPositions(owner: String, network: WalletNetwork) async throws -> RaydiumOwnerEndpointResult {
        let url = try ownerURL(network: network, path: "/position/clmm-lock/\(owner)")
        try RaydiumEndpointGuard.validate(url: url, kind: .ownerCLMMLock(owner: owner))
        let response = try await request(url: url, treatsNotFoundAsEmpty: true)
        return try Self.decodeOwnerEndpointResult(
            statusCode: response.statusCode,
            data: response.data,
            owner: owner,
            kind: .lockedCLMM,
            sourceEndpoint: "/position/clmm-lock/{owner}",
            emptyMessage: "No Raydium locked CLMM positions returned for this wallet."
        )
    }

    func fetchPoolInfos(ids: [String], network: WalletNetwork) async throws -> [String: RaydiumPoolInfo] {
        let uniqueIDs = Array(Set(ids)).sorted()
        guard !uniqueIDs.isEmpty else {
            return [:]
        }
        let url = try apiURL(network: network, path: "/pools/info/ids", queryItems: [
            URLQueryItem(name: "ids", value: uniqueIDs.joined(separator: ","))
        ])
        try RaydiumEndpointGuard.validate(url: url, kind: .poolsInfo(ids: uniqueIDs))
        let response = try await request(url: url, treatsNotFoundAsEmpty: false)
        return try Self.decodePoolInfos(data: response.data)
    }

    func fetchMintInfos(mints: [String], network: WalletNetwork) async throws -> [String: RaydiumMintInfo] {
        let uniqueMints = Array(Set(mints)).sorted()
        guard !uniqueMints.isEmpty else {
            return [:]
        }
        let url = try apiURL(network: network, path: "/mint/ids", queryItems: [
            URLQueryItem(name: "mints", value: uniqueMints.joined(separator: ","))
        ])
        try RaydiumEndpointGuard.validate(url: url, kind: .mintIDs(mints: uniqueMints))
        let response = try await request(url: url, treatsNotFoundAsEmpty: false)
        return try Self.decodeMintInfos(data: response.data)
    }

    func fetchMintPrices(mints: [String], network: WalletNetwork) async throws -> [String: Decimal] {
        let uniqueMints = Array(Set(mints)).sorted()
        guard !uniqueMints.isEmpty else {
            return [:]
        }
        let url = try apiURL(network: network, path: "/mint/price", queryItems: [
            URLQueryItem(name: "mints", value: uniqueMints.joined(separator: ","))
        ])
        try RaydiumEndpointGuard.validate(url: url, kind: .mintPrice(mints: uniqueMints))
        let response = try await request(url: url, treatsNotFoundAsEmpty: false)
        return try Self.decodeMintPrices(data: response.data)
    }

    func fetchFarmInfos(lpMint: String, network: WalletNetwork) async throws -> [RaydiumFarmInfo] {
        let url = try apiURL(network: network, path: "/farms/info/lp", queryItems: [
            URLQueryItem(name: "lp", value: lpMint),
            URLQueryItem(name: "pageSize", value: "10"),
            URLQueryItem(name: "page", value: "1")
        ])
        try RaydiumEndpointGuard.validate(url: url, kind: .farmsInfoLP(lpMint: lpMint))
        let response = try await request(url: url, treatsNotFoundAsEmpty: false)
        return try Self.decodeFarmInfos(data: response.data, lpMint: lpMint)
    }

    static func decodeOwnerPositions(
        data: Data,
        owner: String,
        kind: RaydiumPositionKind,
        sourceEndpoint: String
    ) throws -> [RaydiumPositionRecord] {
        let root = try JSONSerialization.jsonObject(with: data)
        let objects = extractArray(from: root)
        return objects.enumerated().compactMap { index, object in
            normalizeOwnerPosition(
                object,
                owner: owner,
                kind: inferredKind(from: object, fallback: kind),
                sourceEndpoint: sourceEndpoint,
                fallbackIndex: index
            )
        }
    }

    static func decodeOwnerEndpointResult(
        statusCode: Int,
        data: Data,
        owner: String,
        kind: RaydiumPositionKind,
        sourceEndpoint: String,
        emptyMessage: String
    ) throws -> RaydiumOwnerEndpointResult {
        if statusCode == 404 {
            return RaydiumOwnerEndpointResult(status: .empty, positions: [], message: emptyMessage)
        }
        let positions = try decodeOwnerPositions(
            data: data,
            owner: owner,
            kind: kind,
            sourceEndpoint: sourceEndpoint
        )
        return RaydiumOwnerEndpointResult(
            status: positions.isEmpty ? .empty : .loaded,
            positions: positions,
            message: positions.isEmpty ? "Raydium Owner API returned no positions for \(sourceEndpoint)." : nil
        )
    }

    static func decodePoolInfos(data: Data) throws -> [String: RaydiumPoolInfo] {
        let root = try JSONSerialization.jsonObject(with: data)
        let objects = extractArray(from: root)
        let pairs = objects.compactMap(normalizePoolInfo).map { ($0.poolAddress, $0) }
        return Dictionary(uniqueKeysWithValues: pairs)
    }

    static func decodeMintInfos(data: Data) throws -> [String: RaydiumMintInfo] {
        let root = try JSONSerialization.jsonObject(with: data)
        let objects = extractArray(from: root)
        let pairs = objects.compactMap(normalizeMintInfo).map { ($0.mintAddress, $0) }
        return Dictionary(uniqueKeysWithValues: pairs)
    }

    static func decodeMintPrices(data: Data) throws -> [String: Decimal] {
        let root = try JSONSerialization.jsonObject(with: data)
        let payload = unwrapData(root)
        if let dictionary = payload as? [String: Any] {
            return dictionary.reduce(into: [String: Decimal]()) { result, pair in
                guard SolanaAddressValidator.isValidAddress(pair.key),
                      let value = decimal(pair.value) else {
                    return
                }
                result[pair.key] = value
            }
        }

        let objects = extractArray(from: root)
        return objects.reduce(into: [String: Decimal]()) { result, object in
            guard let mint = string(object, keys: ["mint", "address", "mintAddress"]),
                  let value = decimal(firstValue(object, keys: ["price", "usd", "usdPrice"])) else {
                return
            }
            result[mint] = value
        }
    }

    static func decodeFarmInfos(data: Data, lpMint: String) throws -> [RaydiumFarmInfo] {
        let root = try JSONSerialization.jsonObject(with: data)
        return extractArray(from: root).compactMap { object in
            let farmID = string(object, keys: ["id", "farmId", "farmID", "address"]) ?? lpMint
            return RaydiumFarmInfo(
                farmID: farmID,
                lpMintAddress: string(object, keys: ["lpMint", "lpMintAddress", "lp"]) ?? lpMint,
                poolAddress: string(object, keys: ["poolId", "poolID", "poolAddress", "ammId"])
            )
        }
    }

    private struct HTTPPayload {
        let data: Data
        let statusCode: Int
    }

    private func request(url: URL, treatsNotFoundAsEmpty: Bool) async throws -> HTTPPayload {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RaydiumAPIClientError.transport("Raydium did not return an HTTP response.")
            }
            switch httpResponse.statusCode {
            case 200..<300:
                return HTTPPayload(data: data, statusCode: httpResponse.statusCode)
            case 404 where treatsNotFoundAsEmpty:
                return HTTPPayload(data: Data(), statusCode: httpResponse.statusCode)
            case 400:
                throw RaydiumAPIClientError.badRequest("HTTP 400")
            case 429:
                throw RaydiumAPIClientError.rateLimited
            case 500...599:
                throw RaydiumAPIClientError.server("HTTP \(httpResponse.statusCode)")
            default:
                throw RaydiumAPIClientError.transport("HTTP \(httpResponse.statusCode)")
            }
        } catch let error as RaydiumAPIClientError {
            throw error
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                throw RaydiumAPIClientError.timeout
            }
            throw RaydiumAPIClientError.transport(error.localizedDescription)
        }
    }

    private func ownerURL(network: WalletNetwork, path: String) throws -> URL {
        try url(baseURL: RaydiumConstants.ownerBaseURL(network: network), path: path, queryItems: [])
    }

    private func apiURL(network: WalletNetwork, path: String, queryItems: [URLQueryItem]) throws -> URL {
        try url(baseURL: RaydiumConstants.apiBaseURL(network: network), path: path, queryItems: queryItems)
    }

    private func url(baseURL: URL, path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else {
            throw RaydiumAPIClientError.endpointBlocked("Raydium read-only endpoint could not be built.")
        }
        return url
    }
}

private extension RaydiumAPIClient {
    static func normalizeOwnerPosition(
        _ object: [String: Any],
        owner: String,
        kind: RaydiumPositionKind,
        sourceEndpoint: String,
        fallbackIndex: Int
    ) -> RaydiumPositionRecord? {
        let pool = string(object, keys: ["poolId", "poolID", "poolAddress", "ammId", "ammID", "id"])
            ?? nestedString(object, keys: ["pool"], nestedKeys: ["id", "address", "poolId"])
        let lpMint = string(object, keys: ["lpMint", "lpMintAddress", "lpMintId", "mint", "mintAddress"])
            ?? nestedString(object, keys: ["lp"], nestedKeys: ["mint", "address"])
        let position = string(object, keys: ["positionId", "positionAddress", "account", "accountId", "pubkey", "publicKey", "stakeAccount"])
            ?? string(object, keys: ["id"]).flatMap { $0 == pool ? nil : $0 }
            ?? [sourceEndpoint, pool, lpMint, String(fallbackIndex)].compactMap { $0 }.joined(separator: ":")

        guard pool != nil || lpMint != nil || position.isEmpty == false else {
            return nil
        }

        let tokenAMint = string(object, keys: ["tokenAMint", "mintA", "baseMint", "token0Mint", "coinMint"])
            ?? nestedString(object, keys: ["mintA", "tokenA", "base"], nestedKeys: ["address", "mint"])
        let tokenBMint = string(object, keys: ["tokenBMint", "mintB", "quoteMint", "token1Mint", "pcMint"])
            ?? nestedString(object, keys: ["mintB", "tokenB", "quote"], nestedKeys: ["address", "mint"])
        let lockDate = dateFromFlexibleValue(firstValue(object, keys: ["lockEndTime", "endTime", "unlockTime", "lockEndTimestamp"]))

        let rewardObjects = array(object, keys: ["rewards", "rewardInfos", "pendingRewards", "rewardInfo"])
        let partialReason = partialReason(
            pool: pool,
            lpMint: lpMint,
            tokenAMint: tokenAMint,
            tokenBMint: tokenBMint,
            tokenAAmount: string(object, keys: ["tokenAAmount", "amountA", "baseAmount", "amount0", "coinAmount"]),
            tokenBAmount: string(object, keys: ["tokenBAmount", "amountB", "quoteAmount", "amount1", "pcAmount"])
        )

        return RaydiumPositionRecord(
            walletPublicAddress: owner,
            kind: kind,
            sourceEndpoint: sourceEndpoint,
            positionAddress: position,
            poolAddress: pool,
            lpMintAddress: lpMint,
            lpAmountRaw: decimalString(object, keys: ["lpAmountRaw", "lpRawAmount", "amountRaw"]),
            lpAmountUI: decimalString(object, keys: ["lpAmount", "amount", "balance", "deposited", "depositAmount"]),
            tokenAMint: tokenAMint,
            tokenBMint: tokenBMint,
            tokenAAmountRaw: decimalString(object, keys: ["tokenAAmountRaw", "amountARaw", "baseAmountRaw", "amount0Raw"]),
            tokenBAmountRaw: decimalString(object, keys: ["tokenBAmountRaw", "amountBRaw", "quoteAmountRaw", "amount1Raw"]),
            tokenAAmountUI: decimalString(object, keys: ["tokenAAmount", "amountA", "baseAmount", "amount0", "coinAmount"]),
            tokenBAmountUI: decimalString(object, keys: ["tokenBAmount", "amountB", "quoteAmount", "amount1", "pcAmount"]),
            feeAAmountRaw: decimalString(object, keys: ["feeAAmountRaw", "feeOwedARaw", "feeAmountARaw"]),
            feeBAmountRaw: decimalString(object, keys: ["feeBAmountRaw", "feeOwedBRaw", "feeAmountBRaw"]),
            feeAAmountUI: decimalString(object, keys: ["feeAAmount", "feeOwedA", "feeAmountA", "tokenAFees"]),
            feeBAmountUI: decimalString(object, keys: ["feeBAmount", "feeOwedB", "feeAmountB", "tokenBFees"]),
            pendingRewardCount: rewardObjects.count,
            lockEndTime: lockDate,
            rawStatus: string(object, keys: ["status", "state"]),
            partialReason: partialReason
        )
    }

    static func normalizePoolInfo(_ object: [String: Any]) -> RaydiumPoolInfo? {
        guard let pool = string(object, keys: ["id", "poolId", "poolID", "address", "ammId"]) else {
            return nil
        }
        let lpMint = string(object, keys: ["lpMint", "lpMintAddress", "lpMintId"])
            ?? nestedString(object, keys: ["lp"], nestedKeys: ["mint", "address"])
        let tokenA = string(object, keys: ["tokenAMint", "mintA", "baseMint"])
            ?? nestedString(object, keys: ["mintA", "tokenA", "base"], nestedKeys: ["address", "mint"])
        let tokenB = string(object, keys: ["tokenBMint", "mintB", "quoteMint"])
            ?? nestedString(object, keys: ["mintB", "tokenB", "quote"], nestedKeys: ["address", "mint"])
        return RaydiumPoolInfo(
            poolAddress: pool,
            poolType: inferredKind(from: object, fallback: .unknown),
            lpMintAddress: lpMint,
            tokenAMint: tokenA,
            tokenBMint: tokenB,
            tvlUSD: decimal(firstValue(object, keys: ["tvl", "tvlUsd", "tvlUSD"]))
        )
    }

    static func normalizeMintInfo(_ object: [String: Any]) -> RaydiumMintInfo? {
        guard let mint = string(object, keys: ["address", "mint", "mintAddress"]) else {
            return nil
        }
        return RaydiumMintInfo(
            mintAddress: mint,
            symbol: string(object, keys: ["symbol", "ticker"]),
            name: string(object, keys: ["name"]),
            decimals: uint8(object, keys: ["decimals"])
        )
    }

    static func extractArray(from root: Any) -> [[String: Any]] {
        if let array = root as? [[String: Any]] {
            return array
        }
        if let dictionary = root as? [String: Any] {
            for key in ["data", "rows", "list", "items", "positions"] {
                if let array = dictionary[key] as? [[String: Any]] {
                    return array
                }
                if let nested = dictionary[key] as? [String: Any] {
                    let extracted = extractArray(from: nested)
                    if !extracted.isEmpty {
                        return extracted
                    }
                    if key == "data" && !nested.isEmpty {
                        return [nested]
                    }
                }
            }
        }
        return []
    }

    static func unwrapData(_ root: Any) -> Any {
        guard let dictionary = root as? [String: Any],
              let data = dictionary["data"] else {
            return root
        }
        return data
    }

    static func inferredKind(from object: [String: Any], fallback: RaydiumPositionKind) -> RaydiumPositionKind {
        let text = [
            string(object, keys: ["poolType", "type", "programType", "category"]),
            string(object, keys: ["programId", "programID"])
        ].compactMap { $0?.lowercased() }.joined(separator: " ")
        if text.contains("clmm") || text.contains(RaydiumConstants.mainnetCLMMProgramID.lowercased()) || text.contains(RaydiumConstants.devnetCLMMProgramID.lowercased()) {
            return .lockedCLMM
        }
        if text.contains("cpmm") || text.contains(RaydiumConstants.mainnetCPMMProgramID.lowercased()) || text.contains(RaydiumConstants.devnetCPMMProgramID.lowercased()) {
            return .standardLP
        }
        if text.contains("farm") || text.contains(RaydiumConstants.mainnetFarmV3ProgramID.lowercased()) || text.contains(RaydiumConstants.mainnetFarmV5ProgramID.lowercased()) || text.contains(RaydiumConstants.mainnetFarmV6ProgramID.lowercased()) {
            return .farm
        }
        if text.contains("amm") || text.contains(RaydiumConstants.mainnetAMMv4ProgramID.lowercased()) || text.contains(RaydiumConstants.devnetAMMv4ProgramID.lowercased()) {
            return .standardLP
        }
        return fallback
    }

    static func partialReason(
        pool: String?,
        lpMint: String?,
        tokenAMint: String?,
        tokenBMint: String?,
        tokenAAmount: String?,
        tokenBAmount: String?
    ) -> String? {
        var missing: [String] = []
        if pool == nil { missing.append("pool") }
        if lpMint == nil { missing.append("LP mint") }
        if tokenAMint == nil || tokenBMint == nil { missing.append("token mints") }
        if tokenAAmount == nil || tokenBAmount == nil { missing.append("token amounts") }
        return missing.isEmpty ? nil : "Raydium response did not include complete \(missing.joined(separator: ", "))."
    }

    static func string(_ object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let value = object[key] else { continue }
            if let string = value as? String, !string.isEmpty {
                return string
            }
            if let number = value as? NSNumber {
                return number.stringValue
            }
        }
        return nil
    }

    static func nestedString(_ object: [String: Any], keys: [String], nestedKeys: [String]) -> String? {
        for key in keys {
            if let nested = object[key] as? [String: Any],
               let value = string(nested, keys: nestedKeys) {
                return value
            }
        }
        return nil
    }

    static func array(_ object: [String: Any], keys: [String]) -> [[String: Any]] {
        for key in keys {
            if let array = object[key] as? [[String: Any]] {
                return array
            }
        }
        return []
    }

    static func decimalString(_ object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let value = object[key],
                  let decimal = decimal(value) else {
                continue
            }
            return NSDecimalNumber(decimal: decimal).stringValue
        }
        return nil
    }

    static func decimal(_ value: Any?) -> Decimal? {
        switch value {
        case let decimal as Decimal:
            return decimal
        case let number as NSNumber:
            return number.decimalValue
        case let string as String:
            return Decimal(string: string)
        default:
            return nil
        }
    }

    static func firstValue(_ object: [String: Any], keys: [String]) -> Any? {
        keys.compactMap { object[$0] }.first
    }

    static func uint8(_ object: [String: Any], keys: [String]) -> UInt8? {
        guard let decimal = decimal(firstValue(object, keys: keys)) else {
            return nil
        }
        return UInt8(NSDecimalNumber(decimal: decimal).uint8Value)
    }

    static func dateFromFlexibleValue(_ value: Any?) -> Date? {
        guard let decimal = decimal(value) else {
            return nil
        }
        let seconds = NSDecimalNumber(decimal: decimal).doubleValue
        guard seconds > 0 else {
            return nil
        }
        if seconds > 10_000_000_000 {
            return Date(timeIntervalSince1970: seconds / 1000)
        }
        return Date(timeIntervalSince1970: seconds)
    }
}
