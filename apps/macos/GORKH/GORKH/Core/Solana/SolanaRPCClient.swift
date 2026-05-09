import Foundation

struct SolanaRPCClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
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

    private func request(method: String, params: [Any], network: WalletNetwork) async throws -> Any {
        var urlRequest = URLRequest(url: network.rpcURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": UUID().uuidString,
            "method": method,
            "params": params
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SolanaRPCError.transport("Solana RPC did not return an HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No response body."
            throw SolanaRPCError.transport("HTTP \(httpResponse.statusCode): \(body.prefix(500))")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SolanaRPCError.invalidResponse
        }

        if let error = json["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Solana RPC error"
            throw SolanaRPCError.rpc(message)
        }

        guard let result = json["result"] else {
            throw SolanaRPCError.invalidResponse
        }

        return result
    }
}

enum SolanaRPCError: LocalizedError, Equatable {
    case invalidResponse
    case transport(String)
    case rpc(String)
    case devnetOnly(String)

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
