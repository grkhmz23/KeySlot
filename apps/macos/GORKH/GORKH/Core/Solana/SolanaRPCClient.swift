import Foundation

struct SolanaRPCClient {
    private let session: URLSession
    let configuration: RPCFastConfiguration

    init(session: URLSession = .shared, configuration: RPCFastConfiguration = RPCFastConfiguration()) {
        self.session = session
        self.configuration = configuration
    }

    func getBalance(address: String, network: WalletNetwork) async throws -> UInt64 {
        let result = try await request(method: "getBalance", params: [address], network: network)
        guard let dictionary = result as? [String: Any],
              let value = dictionary["value"] as? NSNumber else {
            throw SolanaRPCError.invalidResponse
        }
        return value.uint64Value
    }

    func getTokenBalances(ownerAddress: String, network: WalletNetwork) async throws -> [TokenBalance] {
        var balances: [TokenBalance] = []
        let fetchedAt = Date()

        for programKind in TokenProgramKind.allCases {
            let result = try await request(
                method: "getTokenAccountsByOwner",
                params: [
                    ownerAddress,
                    ["programId": programKind.programID],
                    [
                        "encoding": "jsonParsed",
                        "commitment": "confirmed"
                    ]
                ],
                network: network
            )
            balances.append(contentsOf: try SplTokenParser.parseTokenAccounts(
                result: result,
                programKind: programKind,
                fetchedAt: fetchedAt
            ))
        }

        return balances.sorted {
            if $0.mintAddress == $1.mintAddress {
                return $0.tokenAccountAddress < $1.tokenAccountAddress
            }
            return $0.mintAddress < $1.mintAddress
        }
    }

    func getCurrentEpoch(network: WalletNetwork) async throws -> UInt64 {
        let result = try await request(
            method: "getEpochInfo",
            params: [["commitment": "confirmed"]],
            network: network
        )

        guard let dictionary = result as? [String: Any],
              let epoch = dictionary["epoch"] as? NSNumber else {
            throw SolanaRPCError.invalidResponse
        }
        return epoch.uint64Value
    }

    func getStakeAccounts(profile: WalletProfile, network: WalletNetwork) async throws -> [StakeAccountSummary] {
        let currentEpoch = try? await getCurrentEpoch(network: network)
        let fetchedAt = Date()
        var merged: [String: StakeAccountSummary] = [:]

        for authorityOffset in [12, 44] {
            let result = try await request(
                method: "getProgramAccounts",
                params: [
                    StakeConstants.stakeProgramID,
                    [
                        "encoding": "jsonParsed",
                        "commitment": "confirmed",
                        "filters": [
                            ["dataSize": 200],
                            [
                                "memcmp": [
                                    "offset": authorityOffset,
                                    "bytes": profile.publicAddress
                                ]
                            ]
                        ]
                    ]
                ],
                network: network
            )

            let accounts = try StakeAccountParser.parseStakeAccounts(
                result: result,
                profile: profile,
                network: network,
                currentEpoch: currentEpoch,
                fetchedAt: fetchedAt
            )
            accounts.forEach { merged[$0.stakeAccountAddress] = $0 }
        }

        return merged.values.sorted { $0.stakeAccountAddress < $1.stakeAccountAddress }
    }

    func getTokenAccounts(
        ownerAddress: String,
        mintAddress: String,
        programKind: TokenProgramKind,
        network: WalletNetwork
    ) async throws -> [TokenBalance] {
        let result = try await request(
            method: "getTokenAccountsByOwner",
            params: [
                ownerAddress,
                ["mint": mintAddress],
                [
                    "encoding": "jsonParsed",
                    "commitment": "confirmed"
                ]
            ],
            network: network
        )

        return try SplTokenParser.parseTokenAccounts(
            result: result,
            programKind: programKind,
            fetchedAt: Date()
        )
        .filter { $0.programKind == programKind }
    }

    func getAccountExists(address: String, network: WalletNetwork) async throws -> Bool {
        let result = try await request(
            method: "getAccountInfo",
            params: [
                address,
                [
                    "encoding": "base64",
                    "commitment": "confirmed"
                ]
            ],
            network: network
        )

        guard let dictionary = result as? [String: Any] else {
            throw SolanaRPCError.invalidResponse
        }

        return !(dictionary["value"] is NSNull) && dictionary["value"] != nil
    }

    func getFilteredProgramAccountsBase64(
        programID: String,
        dataSize: Int,
        memcmpOffset: Int,
        memcmpBytes: String,
        network: WalletNetwork
    ) async throws -> [SolanaProgramAccountData] {
        guard SolanaAddressValidator.isValidAddress(programID),
              SolanaAddressValidator.isValidAddress(memcmpBytes),
              dataSize > 0,
              memcmpOffset >= 0 else {
            throw SolanaRPCError.invalidResponse
        }

        let result = try await request(
            method: "getProgramAccounts",
            params: [
                programID,
                [
                    "encoding": "base64",
                    "commitment": "confirmed",
                    "filters": [
                        ["dataSize": dataSize],
                        [
                            "memcmp": [
                                "offset": memcmpOffset,
                                "bytes": memcmpBytes
                            ]
                        ]
                    ]
                ]
            ],
            network: network
        )

        guard let accounts = result as? [[String: Any]] else {
            throw SolanaRPCError.invalidResponse
        }

        return try accounts.map { item in
            guard let publicKey = item["pubkey"] as? String,
                  let account = item["account"] as? [String: Any],
                  let owner = account["owner"] as? String else {
                throw SolanaRPCError.invalidResponse
            }

            let space: Int?
            if let number = account["space"] as? NSNumber {
                space = number.intValue
            } else {
                space = account["space"] as? Int
            }
            let base64: String?
            if let dataArray = account["data"] as? [Any] {
                base64 = dataArray.first as? String
            } else {
                base64 = account["data"] as? String
            }

            guard let base64,
                  let data = Data(base64Encoded: base64) else {
                throw SolanaRPCError.invalidResponse
            }

            return SolanaProgramAccountData(
                publicKey: publicKey,
                owner: owner,
                data: data,
                space: space
            )
        }
    }

    func getMintDecimals(
        mintAddress: String,
        programKind: TokenProgramKind,
        network: WalletNetwork
    ) async throws -> UInt8? {
        let result = try await request(
            method: "getParsedAccountInfo",
            params: [
                mintAddress,
                [
                    "encoding": "jsonParsed",
                    "commitment": "confirmed"
                ]
            ],
            network: network
        )

        guard let dictionary = result as? [String: Any] else {
            throw SolanaRPCError.invalidResponse
        }
        if dictionary["value"] is NSNull || dictionary["value"] == nil {
            return nil
        }
        guard let value = dictionary["value"] as? [String: Any] else {
            throw SolanaRPCError.invalidResponse
        }
        if let owner = value["owner"] as? String, owner != programKind.programID {
            return nil
        }
        guard let data = value["data"] as? [String: Any],
              let parsed = data["parsed"] as? [String: Any],
              let info = parsed["info"] as? [String: Any] else {
            return nil
        }

        if let decimals = info["decimals"] as? NSNumber {
            return UInt8(clamping: decimals.intValue)
        }
        if let decimals = info["decimals"] as? Int {
            return UInt8(clamping: decimals)
        }
        return nil
    }

    func getMinimumBalanceForRentExemption(byteCount: Int, network: WalletNetwork) async throws -> UInt64 {
        let result = try await request(
            method: "getMinimumBalanceForRentExemption",
            params: [byteCount],
            network: network
        )

        guard let value = result as? NSNumber else {
            throw SolanaRPCError.invalidResponse
        }

        return value.uint64Value
    }

    func getLatestBlockhash(network: WalletNetwork) async throws -> String {
        let result = try await request(method: "getLatestBlockhash", params: [], network: network)
        guard let dictionary = result as? [String: Any],
              let value = dictionary["value"] as? [String: Any],
              let blockhash = value["blockhash"] as? String else {
            throw SolanaRPCError.invalidResponse
        }
        return blockhash
    }

    func getHealth(network: WalletNetwork) async throws -> String {
        let result = try await request(method: "getHealth", params: [], network: network)
        guard let status = result as? String else {
            throw SolanaRPCError.invalidResponse
        }
        return status
    }

    func getVersion(network: WalletNetwork) async throws -> String? {
        let result = try await request(method: "getVersion", params: [], network: network)
        guard let dictionary = result as? [String: Any] else {
            throw SolanaRPCError.invalidResponse
        }
        return dictionary["solana-core"] as? String
    }

    func getSlot(network: WalletNetwork) async throws -> UInt64 {
        let result = try await request(method: "getSlot", params: [["commitment": "confirmed"]], network: network)
        guard let value = result as? NSNumber else {
            throw SolanaRPCError.invalidResponse
        }
        return value.uint64Value
    }

    func getBlockHeight(network: WalletNetwork) async throws -> UInt64 {
        let result = try await request(method: "getBlockHeight", params: [["commitment": "confirmed"]], network: network)
        guard let value = result as? NSNumber else {
            throw SolanaRPCError.invalidResponse
        }
        return value.uint64Value
    }

    func getFeeForMessage(messageBase64: String, network: WalletNetwork) async throws -> UInt64? {
        let result = try await request(
            method: "getFeeForMessage",
            params: [messageBase64, ["encoding": "base64"]],
            network: network
        )

        guard let dictionary = result as? [String: Any] else {
            throw SolanaRPCError.invalidResponse
        }

        if dictionary["value"] is NSNull {
            return nil
        }

        guard let value = dictionary["value"] as? NSNumber else {
            throw SolanaRPCError.invalidResponse
        }

        return value.uint64Value
    }

    func simulateTransaction(transactionBase64: String, network: WalletNetwork) async throws -> SimulationResult {
        let result = try await request(
            method: "simulateTransaction",
            params: [
                transactionBase64,
                [
                    "encoding": "base64",
                    "sigVerify": false,
                    "replaceRecentBlockhash": false,
                    "commitment": "processed"
                ]
            ],
            network: network
        )

        guard let dictionary = result as? [String: Any],
              let value = dictionary["value"] as? [String: Any] else {
            throw SolanaRPCError.invalidResponse
        }

        let logs = value["logs"] as? [String] ?? []
        let errorValue = value["err"]
        let hasError = !(errorValue is NSNull) && errorValue != nil

        return SimulationResult(
            status: hasError ? .failed : .success,
            logs: logs,
            estimatedFeeLamports: nil,
            errorMessage: hasError ? String(describing: errorValue ?? "Simulation failed") : nil,
            simulatedAt: Date()
        )
    }

    func sendTransaction(transactionBase64: String, network: WalletNetwork) async throws -> String {
        let result = try await request(
            method: "sendTransaction",
            params: [
                transactionBase64,
                [
                    "encoding": "base64",
                    "skipPreflight": false,
                    "preflightCommitment": "processed",
                    "maxRetries": 3
                ]
            ],
            network: network
        )

        guard let signature = result as? String else {
            throw SolanaRPCError.invalidResponse
        }

        return signature
    }

    func requestAirdrop(address: String, lamports: UInt64, network: WalletNetwork) async throws -> String {
        guard network == .devnet else {
            throw SolanaRPCError.devnetOnly("requestAirdrop is available only on devnet.")
        }
        guard SolanaAddressValidator.isValidAddress(address), lamports > 0 else {
            throw SolanaRPCError.invalidResponse
        }

        let result = try await request(
            method: "requestAirdrop",
            params: [address, lamports],
            network: network
        )

        guard let signature = result as? String else {
            throw SolanaRPCError.invalidResponse
        }

        return signature
    }

    func getSignatureStatus(signature: String, network: WalletNetwork) async throws -> String? {
        try await getSignatureStatusInfo(signature: signature, network: network)?.confirmationStatus
    }

    func getSignatureStatusInfo(signature: String, network: WalletNetwork) async throws -> SolanaSignatureStatus? {
        let result = try await request(
            method: "getSignatureStatuses",
            params: [[signature]],
            network: network
        )

        guard let dictionary = result as? [String: Any],
              let values = dictionary["value"] as? [Any],
              let first = values.first else {
            throw SolanaRPCError.invalidResponse
        }

        if first is NSNull {
            return nil
        }

        guard let status = first as? [String: Any] else {
            return nil
        }

        let errorValue = status["err"]
        let errorDescription: String?
        if errorValue == nil || errorValue is NSNull {
            errorDescription = nil
        } else {
            errorDescription = String(describing: errorValue ?? "Unknown transaction error")
        }

        return SolanaSignatureStatus(
            confirmationStatus: status["confirmationStatus"] as? String,
            errorDescription: errorDescription
        )
    }

    func makeRequest(method: String, params: [Any], network: WalletNetwork) throws -> URLRequest {
        guard configuration.tokenStatus(for: network) == .present else {
            throw SolanaRPCError.tokenMissing(configuration.missingTokenMessage(for: network))
        }
        let availability = RPCMethodAvailability.evaluate(method: method, programID: Self.programIDParameter(from: params))
        switch availability {
        case .unsupported:
            throw SolanaRPCError.methodBlocked("Solana RPC method is not allowlisted for GORKH Wallet.")
        case .blocked:
            throw SolanaRPCError.methodBlocked("RPC Fast blocks this RPC method or program for the current plan.")
        case .allowed, .expensive, .planLimited:
            break
        }
        var urlRequest = URLRequest(url: configuration.httpURL(for: network))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        configuration.applyAuthentication(to: &urlRequest, network: network)
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": UUID().uuidString,
            "method": method,
            "params": params
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    private static func programIDParameter(from params: [Any]) -> String? {
        params.first as? String
    }

    private func request(method: String, params: [Any], network: WalletNetwork) async throws -> Any {
        let urlRequest = try makeRequest(method: method, params: params, network: network)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError where error.code == .timedOut {
            throw SolanaRPCError.timeout("RPC Fast endpoint timed out.")
        } catch {
            throw SolanaRPCError.transport(configuration.redact(error.localizedDescription))
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SolanaRPCError.transport("Solana RPC did not return an HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No response body."
            let normalized = RPCErrorNormalizer.normalize(
                statusCode: httpResponse.statusCode,
                message: "HTTP \(httpResponse.statusCode): \(body.prefix(500))",
                configuration: configuration
            )
            throw SolanaRPCError.from(normalized)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SolanaRPCError.invalidResponse
        }

        if let error = json["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Solana RPC error"
            throw SolanaRPCError.from(RPCErrorNormalizer.normalize(message: message, configuration: configuration))
        }

        guard let result = json["result"] else {
            throw SolanaRPCError.invalidResponse
        }

        return result
    }
}

struct SolanaProgramAccountData: Equatable {
    let publicKey: String
    let owner: String
    let data: Data
    let space: Int?
}

enum SolanaRPCError: LocalizedError, Equatable {
    case invalidResponse
    case transport(String)
    case rpc(String)
    case devnetOnly(String)
    case tokenMissing(String)
    case unauthorized(String)
    case rateLimited(String)
    case planUpgradeRequired(String)
    case methodBlocked(String)
    case timeout(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Solana RPC returned an invalid response."
        case .transport(let message):
            return "Solana RPC transport failed: \(message)"
        case .rpc(let message):
            return message
        case .devnetOnly(let message):
            return message
        case .tokenMissing(let message),
             .unauthorized(let message),
             .rateLimited(let message),
             .planUpgradeRequired(let message),
             .methodBlocked(let message),
             .timeout(let message):
            return message
        }
    }

    static func from(_ normalized: RPCNormalizedError) -> SolanaRPCError {
        switch normalized.category {
        case .tokenMissing:
            return .tokenMissing(normalized.message)
        case .unauthorized:
            return .unauthorized(normalized.message)
        case .rateLimited:
            return .rateLimited(normalized.message)
        case .planUpgradeRequired:
            return .planUpgradeRequired(normalized.message)
        case .methodBlocked:
            return .methodBlocked(normalized.message)
        case .timeout:
            return .timeout(normalized.message)
        case .invalidResponse:
            return .invalidResponse
        case .endpointUnavailable:
            return .transport(normalized.message)
        case .unknown:
            return .rpc(normalized.message)
        }
    }
}

struct SolanaSignatureStatus: Equatable {
    let confirmationStatus: String?
    let errorDescription: String?

    var isConfirmedOrFinalized: Bool {
        confirmationStatus == "confirmed" || confirmationStatus == "finalized"
    }
}
