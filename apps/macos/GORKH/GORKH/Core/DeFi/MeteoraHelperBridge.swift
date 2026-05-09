import Foundation

enum MeteoraHelperCommand: String, Codable, CaseIterable {
    case health
    case envCheck = "env-check"
    case positions
}

enum MeteoraHelperError: LocalizedError, Equatable {
    case disabled
    case commandNotAllowlisted(MeteoraHelperCommand)
    case projectRootMissing
    case disallowedHelperPath(String)
    case disallowedNodeExecutable(String)
    case nodeUnavailable
    case helperRejected(String)
    case responseRejected(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "Meteora read-only helper invocation is disabled."
        case .commandNotAllowlisted(let command):
            return "Meteora helper command is not allowlisted: \(command.rawValue)."
        case .projectRootMissing:
            return "Project root is required for Meteora helper invocation."
        case .disallowedHelperPath(let path):
            return "Meteora helper path is not allowlisted: \(path)."
        case .disallowedNodeExecutable(let path):
            return "Node executable path is not allowlisted: \(path)."
        case .nodeUnavailable:
            return "No allowlisted Node executable is available for Meteora helper invocation."
        case .helperRejected(let message):
            return message
        case .responseRejected(let message):
            return "Meteora helper response rejected: \(message)"
        }
    }
}

struct MeteoraHelperInvocationPolicy: Equatable {
    let enabled: Bool
    let allowlistedHelperRelativePath: String
    let allowedNodeExecutablePaths: [String]
    let allowedCommands: Set<MeteoraHelperCommand>

    static let disabled = MeteoraHelperInvocationPolicy(
        enabled: false,
        allowlistedHelperRelativePath: "tools/meteora-readonly/src/index.ts",
        allowedNodeExecutablePaths: [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node"
        ],
        allowedCommands: [.health, .envCheck, .positions]
    )

    static func readOnlyEnabledForDevelopment(
        allowedNodeExecutablePaths: [String] = MeteoraHelperInvocationPolicy.disabled.allowedNodeExecutablePaths
    ) -> MeteoraHelperInvocationPolicy {
        MeteoraHelperInvocationPolicy(
            enabled: true,
            allowlistedHelperRelativePath: MeteoraHelperInvocationPolicy.disabled.allowlistedHelperRelativePath,
            allowedNodeExecutablePaths: allowedNodeExecutablePaths,
            allowedCommands: MeteoraHelperInvocationPolicy.disabled.allowedCommands
        )
    }
}

struct MeteoraHelperRequest: Codable, Equatable {
    let requestID: String
    let command: MeteoraHelperCommand
    let walletPublicAddress: String?
    let network: WalletNetwork
    let rpcURL: String?
    let timestamp: Date

    init(
        requestID: String = UUID().uuidString,
        command: MeteoraHelperCommand,
        walletPublicAddress: String? = nil,
        network: WalletNetwork,
        rpcURL: String? = nil,
        timestamp: Date = Date()
    ) {
        self.requestID = requestID
        self.command = command
        self.walletPublicAddress = walletPublicAddress
        self.network = network
        self.rpcURL = rpcURL
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case requestID = "requestId"
        case command
        case walletPublicAddress
        case network
        case rpcURL = "rpcUrl"
        case timestamp
    }
}

struct MeteoraHelperSDKValidation: Codable, Equatable {
    let sdkInstalled: Bool
    let sdkImportOk: Bool
    let sdkVersion: String?
    let readOnlyMethodAvailable: Bool
}

struct MeteoraHelperResponse: Codable, Equatable {
    let id: String
    let requestID: String?
    let command: MeteoraHelperCommand
    let status: LPAdapterStatus
    let errorCategory: String
    let message: String
    let sdkValidation: MeteoraHelperSDKValidation?
    let positions: [MeteoraHelperPosition]?
    let positionCount: Int?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requestID = "requestId"
        case command
        case status
        case errorCategory
        case message
        case sdkValidation
        case positions
        case positionCount
        case timestamp
    }
}

struct MeteoraHelperPosition: Codable, Equatable {
    let walletPublicAddress: String
    let poolAddress: String
    let positionAddress: String
    let tokenAMint: String?
    let tokenBMint: String?
    let tokenAAmountUI: String?
    let tokenBAmountUI: String?
    let tokenAFeesUI: String?
    let tokenBFeesUI: String?
    let lowerBinID: Int?
    let upperBinID: Int?
    let currentBinID: Int?
    let rangeState: LPRangeState
    let estimatedValueUSD: String?
    let status: LPAdapterStatus
    let metadataStatus: String?

    enum CodingKeys: String, CodingKey {
        case walletPublicAddress
        case poolAddress
        case positionAddress
        case tokenAMint = "tokenAMint"
        case tokenBMint = "tokenBMint"
        case tokenAAmountUI = "tokenAAmountUi"
        case tokenBAmountUI = "tokenBAmountUi"
        case tokenAFeesUI = "tokenAFeesUi"
        case tokenBFeesUI = "tokenBFeesUi"
        case lowerBinID = "lowerBinId"
        case upperBinID = "upperBinId"
        case currentBinID = "currentBinId"
        case rangeState
        case estimatedValueUSD = "estimatedValueUsd"
        case status
        case metadataStatus
    }
}

protocol MeteoraHelperBridging {
    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LPAdapterResult?
}

struct MeteoraHelperBridge: MeteoraHelperBridging {
    let policy: MeteoraHelperInvocationPolicy
    let projectRoot: URL?
    let pathResolver: any MeteoraHelperPathResolving
    let processRunner: any MeteoraHelperProcessRunning

    static func disabled() -> MeteoraHelperBridge {
        MeteoraHelperBridge(
            policy: .disabled,
            projectRoot: nil,
            pathResolver: MeteoraHelperPathResolver(),
            processRunner: MeteoraHelperDirectProcessRunner()
        )
    }

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LPAdapterResult? {
        guard policy.enabled else {
            return nil
        }

        let updatedAt = Date()
        var positions: [LPPositionSummary] = []
        var messages: [String] = []
        var sawEmpty = false

        for profile in profiles {
            let request = MeteoraHelperRequest(
                command: .positions,
                walletPublicAddress: profile.publicAddress,
                network: network,
                rpcURL: network.rpcURL.absoluteString
            )
            do {
                let response = try await invoke(request)
                switch response.status {
                case .loaded, .partial:
                    positions.append(contentsOf: (response.positions ?? []).map {
                        normalize(position: $0, profile: profile, network: network, prices: prices, updatedAt: updatedAt)
                    })
                    if let message = safeMessage(response.message) {
                        messages.append(message)
                    }
                case .empty:
                    sawEmpty = true
                case .unavailable, .error, .stale, .idle:
                    if let message = safeMessage(response.message) {
                        messages.append("\(profile.label): \(message)")
                    }
                }
            } catch {
                messages.append("\(profile.label): \(error.localizedDescription)")
            }
        }

        if !positions.isEmpty {
            let status: LPAdapterStatus = positions.contains { $0.status == .partial } ? .partial : .loaded
            return LPAdapterResult(
                protocolKind: .meteora,
                status: status,
                positions: positions,
                source: .sdkReadOnly,
                updatedAt: updatedAt,
                errorMessage: messages.isEmpty ? nil : messages.joined(separator: " ")
            )
        }

        if sawEmpty && messages.isEmpty {
            return LPAdapterResult(
                protocolKind: .meteora,
                status: .empty,
                positions: [],
                source: .sdkReadOnly,
                updatedAt: updatedAt,
                errorMessage: "No Meteora DLMM positions returned for the selected public wallet scope."
            )
        }

        return LPAdapterResult(
            protocolKind: .meteora,
            status: .unavailable,
            positions: [],
            source: .sdkReadOnly,
            updatedAt: updatedAt,
            errorMessage: messages.isEmpty ? "Meteora read-only helper did not return positions." : messages.joined(separator: " ")
        )
    }

    private func invoke(_ request: MeteoraHelperRequest) async throws -> MeteoraHelperResponse {
        try validate(request)
        let path = try pathResolver.resolve(policy: policy, projectRoot: projectRoot)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let input = try encoder.encode(request)
        let result = try await processRunner.run(resolvedPath: path, command: request.command, stdin: input)
        guard result.exitCode == 0 else {
            throw MeteoraHelperError.helperRejected(result.stderr)
        }
        try validateNoForbiddenJSONFields(result.stdout)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(MeteoraHelperResponse.self, from: result.stdout)
        try validate(response, for: request)
        return response
    }

    private func validate(_ request: MeteoraHelperRequest) throws {
        guard policy.enabled else {
            throw MeteoraHelperError.disabled
        }
        guard policy.allowedCommands.contains(request.command) else {
            throw MeteoraHelperError.commandNotAllowlisted(request.command)
        }
        if let walletPublicAddress = request.walletPublicAddress {
            guard SolanaAddressValidator.isValidAddress(walletPublicAddress) else {
                throw MeteoraHelperError.responseRejected("invalid public wallet address")
            }
        }
    }

    private func validate(_ response: MeteoraHelperResponse, for request: MeteoraHelperRequest) throws {
        guard response.command == request.command else {
            throw MeteoraHelperError.responseRejected("command mismatch")
        }
        guard response.sdkValidation?.readOnlyMethodAvailable != false else {
            throw MeteoraHelperError.responseRejected("Meteora SDK read-only method unavailable")
        }
    }

    private func validateNoForbiddenJSONFields(_ data: Data) throws {
        let object = try JSONSerialization.jsonObject(with: data)
        if containsForbiddenField(object) {
            throw MeteoraHelperError.responseRejected("forbidden field in response")
        }
    }

    private func containsForbiddenField(_ value: Any) -> Bool {
        if let dictionary = value as? [String: Any] {
            for (key, nested) in dictionary {
                let normalized = key.replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "").lowercased()
                if Redaction.isSensitiveKey(key)
                    || normalized.contains("transactionpayload")
                    || normalized.contains("serializedtransaction")
                    || normalized.contains("instructionpayload") {
                    return true
                }
                if containsForbiddenField(nested) {
                    return true
                }
            }
        } else if let array = value as? [Any] {
            return array.contains(where: containsForbiddenField)
        }
        return false
    }

    private func normalize(
        position: MeteoraHelperPosition,
        profile: WalletProfile,
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote],
        updatedAt: Date
    ) -> LPPositionSummary {
        let tokenA = asset(
            mint: position.tokenAMint,
            uiAmount: position.tokenAAmountUI,
            network: network,
            prices: prices
        )
        let tokenB = asset(
            mint: position.tokenBMint,
            uiAmount: position.tokenBAmountUI,
            network: network,
            prices: prices
        )
        let estimatedValue = decimal(position.estimatedValueUSD) ?? totalValue(tokenA: tokenA, tokenB: tokenB)
        let status: LPAdapterStatus = estimatedValue == nil || tokenA == nil || tokenB == nil ? .partial : position.status
        let range = LPRangeSummary(
            lowerBinID: position.lowerBinID,
            upperBinID: position.upperBinID,
            currentBinID: position.currentBinID,
            state: position.rangeState,
            unavailableReason: position.lowerBinID == nil && position.upperBinID == nil ? "Meteora helper did not expose complete range metadata." : nil
        )

        return LPPositionSummary(
            walletID: profile.id,
            walletLabel: profile.label,
            walletPublicAddress: profile.publicAddress,
            network: network,
            protocolKind: .meteora,
            poolAddress: position.poolAddress,
            positionAddress: position.positionAddress,
            positionMintAddress: nil,
            tokenA: tokenA,
            tokenB: tokenB,
            estimatedValueUSD: estimatedValue,
            feeSummary: feeSummary(position: position, network: network, prices: prices),
            rangeSummary: range,
            impermanentLoss: .unavailable,
            source: .sdkReadOnly,
            updatedAt: updatedAt,
            status: status,
            metadataStatus: position.metadataStatus ?? "Official Meteora DLMM read-only helper; no transaction or signing path used.",
            errorMessage: status == .partial ? "Meteora position returned partial value or metadata coverage." : nil
        )
    }

    private func asset(
        mint: String?,
        uiAmount: String?,
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) -> LPPositionAssetAmount? {
        guard let mint else {
            return nil
        }
        let metadata = TokenMetadataRegistry.lookup(mintAddress: mint, network: network)
        let amount = decimal(uiAmount)
        let price = prices[mint]
        let usdValue = amount.flatMap { amount in price?.usdPrice.map { amount * $0 } }
        return LPPositionAssetAmount(
            mintAddress: mint,
            symbol: metadata?.symbol ?? "UNKNOWN",
            name: metadata?.name ?? "Unknown Token",
            amountRaw: nil,
            decimals: metadata?.decimals,
            uiAmountString: uiAmount,
            usdValue: usdValue,
            priceQuote: price,
            source: .sdkReadOnly
        )
    }

    private func feeSummary(
        position: MeteoraHelperPosition,
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) -> LPFeeSummary {
        let tokenAFees = asset(mint: position.tokenAMint, uiAmount: position.tokenAFeesUI, network: network, prices: prices)
        let tokenBFees = asset(mint: position.tokenBMint, uiAmount: position.tokenBFeesUI, network: network, prices: prices)
        let total = [tokenAFees?.usdValue, tokenBFees?.usdValue].compactMap { $0 }
        return LPFeeSummary(
            tokenAFees: tokenAFees,
            tokenBFees: tokenBFees,
            totalUSD: total.isEmpty ? nil : total.reduce(Decimal(0), +),
            unavailableReason: tokenAFees == nil && tokenBFees == nil ? "Fee amounts are unavailable from the read-only adapter." : nil
        )
    }

    private func totalValue(tokenA: LPPositionAssetAmount?, tokenB: LPPositionAssetAmount?) -> Decimal? {
        let values = [tokenA?.usdValue, tokenB?.usdValue].compactMap { $0 }
        guard values.count == [tokenA, tokenB].compactMap({ $0 }).count, !values.isEmpty else {
            return nil
        }
        return values.reduce(Decimal(0), +)
    }

    private func decimal(_ value: String?) -> Decimal? {
        guard let value else {
            return nil
        }
        return Decimal(string: value)
    }

    private func safeMessage(_ value: String) -> String? {
        guard !value.isEmpty else {
            return nil
        }
        if Redaction.containsSensitiveMaterial(value) {
            return "[redacted meteora helper message]"
        }
        return value
    }
}

struct MeteoraHelperResolvedPath: Equatable {
    let nodeExecutable: URL
    let helperScript: URL
    let helperRelativePath: String
}

protocol MeteoraHelperPathResolving {
    func resolve(policy: MeteoraHelperInvocationPolicy, projectRoot: URL?) throws -> MeteoraHelperResolvedPath
}

struct MeteoraHelperPathResolver: MeteoraHelperPathResolving {
    static let allowedRelativePath = "tools/meteora-readonly/src/index.ts"

    func resolve(policy: MeteoraHelperInvocationPolicy, projectRoot: URL?) throws -> MeteoraHelperResolvedPath {
        guard policy.enabled else {
            throw MeteoraHelperError.disabled
        }
        guard policy.allowlistedHelperRelativePath == Self.allowedRelativePath,
              isSafeRelativePath(policy.allowlistedHelperRelativePath) else {
            throw MeteoraHelperError.disallowedHelperPath(policy.allowlistedHelperRelativePath)
        }
        guard let projectRoot else {
            throw MeteoraHelperError.projectRootMissing
        }
        let node = try resolveNode(candidates: policy.allowedNodeExecutablePaths)
        return MeteoraHelperResolvedPath(
            nodeExecutable: node,
            helperScript: projectRoot.appendingPathComponent(policy.allowlistedHelperRelativePath),
            helperRelativePath: policy.allowlistedHelperRelativePath
        )
    }

    private func resolveNode(candidates: [String]) throws -> URL {
        for candidate in candidates {
            guard MeteoraHelperInvocationPolicy.disabled.allowedNodeExecutablePaths.contains(candidate) else {
                throw MeteoraHelperError.disallowedNodeExecutable(candidate)
            }
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        throw MeteoraHelperError.nodeUnavailable
    }

    private func isSafeRelativePath(_ path: String) -> Bool {
        !path.hasPrefix("/")
            && !path.contains("..")
            && !path.contains("\\")
            && !path.contains(";")
            && !path.contains("\n")
            && path == Self.allowedRelativePath
    }
}

struct MeteoraHelperProcessResult: Equatable {
    let exitCode: Int32
    let stdout: Data
    let stderr: String
}

protocol MeteoraHelperProcessRunning {
    func run(
        resolvedPath: MeteoraHelperResolvedPath,
        command: MeteoraHelperCommand,
        stdin: Data
    ) async throws -> MeteoraHelperProcessResult
}

struct MeteoraHelperDirectProcessRunner: MeteoraHelperProcessRunning {
    func run(
        resolvedPath: MeteoraHelperResolvedPath,
        command: MeteoraHelperCommand,
        stdin: Data
    ) async throws -> MeteoraHelperProcessResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let input = Pipe()

        process.executableURL = resolvedPath.nodeExecutable
        process.arguments = [resolvedPath.helperScript.path, command.rawValue]
        process.standardInput = input
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = [:]

        try process.run()
        try input.fileHandleForWriting.write(contentsOf: stdin)
        try input.fileHandleForWriting.close()
        process.waitUntilExit()

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return MeteoraHelperProcessResult(
            exitCode: process.terminationStatus,
            stdout: stdoutData,
            stderr: redact(stderrText)
        )
    }

    private func redact(_ value: String) -> String {
        guard !value.isEmpty else {
            return ""
        }
        if Redaction.containsSensitiveMaterial(value) {
            return "[redacted meteora helper stderr]"
        }
        return String(value.prefix(500))
    }
}
