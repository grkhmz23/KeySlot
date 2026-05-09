import Foundation

enum OrcaHelperCommand: String, Codable, CaseIterable {
    case health
    case envCheck = "env-check"
    case positions
    case harvestPlan = "harvest-plan"
}

enum OrcaHelperStatus: String, Codable, Equatable {
    case loaded
    case empty
    case partial
    case unavailable
    case error
    case rejected

    var lpStatus: LPAdapterStatus {
        switch self {
        case .loaded:
            return .loaded
        case .empty:
            return .empty
        case .partial:
            return .partial
        case .unavailable, .rejected:
            return .unavailable
        case .error:
            return .error
        }
    }
}

enum OrcaHelperError: LocalizedError, Equatable {
    case disabled
    case commandNotAllowlisted(OrcaHelperCommand)
    case projectRootMissing
    case disallowedHelperPath(String)
    case disallowedNodeExecutable(String)
    case nodeUnavailable
    case helperRejected(String)
    case responseRejected(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "Orca read-only helper invocation is disabled."
        case .commandNotAllowlisted(let command):
            return "Orca helper command is not allowlisted: \(command.rawValue)."
        case .projectRootMissing:
            return "Project root is required for Orca helper invocation."
        case .disallowedHelperPath(let path):
            return "Orca helper path is not allowlisted: \(path)."
        case .disallowedNodeExecutable(let path):
            return "Node executable path is not allowlisted: \(path)."
        case .nodeUnavailable:
            return "No allowlisted Node executable is available for Orca helper invocation."
        case .helperRejected(let message):
            return message
        case .responseRejected(let message):
            return "Orca helper response rejected: \(message)"
        }
    }
}

struct OrcaHelperInvocationPolicy: Equatable {
    let enabled: Bool
    let allowlistedHelperRelativePath: String
    let allowedNodeExecutablePaths: [String]
    let allowedCommands: Set<OrcaHelperCommand>

    static let disabled = OrcaHelperInvocationPolicy(
        enabled: false,
        allowlistedHelperRelativePath: "tools/orca-readonly/src/index.ts",
        allowedNodeExecutablePaths: [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node"
        ],
        allowedCommands: [.health, .envCheck, .positions, .harvestPlan]
    )

    static func readOnlyEnabledForDevelopment(
        allowedNodeExecutablePaths: [String] = OrcaHelperInvocationPolicy.disabled.allowedNodeExecutablePaths
    ) -> OrcaHelperInvocationPolicy {
        OrcaHelperInvocationPolicy(
            enabled: true,
            allowlistedHelperRelativePath: OrcaHelperInvocationPolicy.disabled.allowlistedHelperRelativePath,
            allowedNodeExecutablePaths: allowedNodeExecutablePaths,
            allowedCommands: OrcaHelperInvocationPolicy.disabled.allowedCommands
        )
    }
}

struct OrcaHelperRequest: Codable, Equatable {
    let requestID: String
    let command: OrcaHelperCommand
    let walletPublicAddress: String?
    let positionMint: String?
    let positionAddress: String?
    let network: WalletNetwork
    let rpcURL: String?
    let timestamp: Date

    init(
        requestID: String = UUID().uuidString,
        command: OrcaHelperCommand,
        walletPublicAddress: String? = nil,
        positionMint: String? = nil,
        positionAddress: String? = nil,
        network: WalletNetwork,
        rpcURL: String? = nil,
        timestamp: Date = Date()
    ) {
        self.requestID = requestID
        self.command = command
        self.walletPublicAddress = walletPublicAddress
        self.positionMint = positionMint
        self.positionAddress = positionAddress
        self.network = network
        self.rpcURL = rpcURL
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case requestID = "requestId"
        case command
        case walletPublicAddress
        case positionMint
        case positionAddress
        case network
        case rpcURL = "rpcUrl"
        case timestamp
    }
}

struct OrcaHelperSDKValidation: Codable, Equatable {
    let sdkInstalled: Bool
    let sdkImportOk: Bool
    let sdkVersion: String?
    let kitInstalled: Bool
    let kitImportOk: Bool
    let kitVersion: String?
    let readOnlyMethodAvailable: Bool
    var harvestInstructionMethodAvailable: Bool? = nil
}

struct OrcaHelperResponse: Codable, Equatable {
    let id: String
    let requestID: String?
    let command: OrcaHelperCommand
    let status: OrcaHelperStatus
    let errorCategory: String
    let message: String
    let sdkValidation: OrcaHelperSDKValidation?
    let positions: [OrcaHelperPosition]?
    var harvestPlan: OrcaHarvestPlan? = nil
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
        case harvestPlan
        case positionCount
        case timestamp
    }
}

struct OrcaHelperPosition: Codable, Equatable {
    let walletPublicAddress: String
    let poolAddress: String
    let positionAddress: String
    var positionMint: String? = nil
    let tokenAMint: String?
    let tokenBMint: String?
    let tokenAAmountUI: String?
    let tokenBAmountUI: String?
    let tokenAFeesUI: String?
    let tokenBFeesUI: String?
    let tickLowerIndex: Int?
    let tickUpperIndex: Int?
    let tickCurrentIndex: Int?
    let rangeState: LPRangeState
    let estimatedValueUSD: String?
    let status: OrcaHelperStatus
    let metadataStatus: String?

    enum CodingKeys: String, CodingKey {
        case walletPublicAddress
        case poolAddress
        case positionAddress
        case positionMint
        case tokenAMint = "tokenAMint"
        case tokenBMint = "tokenBMint"
        case tokenAAmountUI = "tokenAAmountUi"
        case tokenBAmountUI = "tokenBAmountUi"
        case tokenAFeesUI = "tokenAFeesUi"
        case tokenBFeesUI = "tokenBFeesUi"
        case tickLowerIndex
        case tickUpperIndex
        case tickCurrentIndex
        case rangeState
        case estimatedValueUSD = "estimatedValueUsd"
        case status
        case metadataStatus
    }
}

struct OrcaHarvestInstructionAccount: Codable, Equatable, Identifiable {
    var id: String { "\(address):\(isSigner):\(isWritable)" }

    let address: String
    let isSigner: Bool
    let isWritable: Bool
}

struct OrcaHarvestInstruction: Codable, Equatable, Identifiable {
    var id: String { "\(programID):\(accounts.count):\(dataBase64.count)" }

    let programID: String
    let accounts: [OrcaHarvestInstructionAccount]
    let dataBase64: String

    enum CodingKeys: String, CodingKey {
        case programID = "programId"
        case accounts
        case dataBase64
    }
}

struct OrcaHarvestTokenAmount: Codable, Equatable {
    let mintAddress: String?
    let amountRaw: String
    let amountUI: String?

    enum CodingKeys: String, CodingKey {
        case mintAddress
        case amountRaw
        case amountUI = "amountUi"
    }
}

struct OrcaHarvestPlan: Codable, Equatable, Identifiable {
    var id: String { "\(walletPublicAddress):\(positionMint):\(expiresAt.timeIntervalSince1970)" }

    let walletPublicAddress: String
    let positionMint: String
    let positionAddress: String?
    let poolAddress: String?
    let tokenAMint: String?
    let tokenBMint: String?
    let feeOwedA: OrcaHarvestTokenAmount?
    let feeOwedB: OrcaHarvestTokenAmount?
    let rewardOwed: [OrcaHarvestTokenAmount]?
    let instructionCount: Int
    let writableAccountCount: Int
    let signerAccounts: [String]
    let programIDs: [String]
    let instructions: [OrcaHarvestInstruction]
    let source: String
    let expiresAt: Date
    let warning: String?

    enum CodingKeys: String, CodingKey {
        case walletPublicAddress
        case positionMint
        case positionAddress
        case poolAddress
        case tokenAMint = "tokenAMint"
        case tokenBMint = "tokenBMint"
        case feeOwedA
        case feeOwedB
        case rewardOwed
        case instructionCount
        case writableAccountCount
        case signerAccounts
        case programIDs = "programIds"
        case instructions
        case source
        case expiresAt
        case warning
    }

    func isExpired(relativeTo date: Date = Date()) -> Bool {
        date >= expiresAt
    }
}

protocol OrcaHelperBridging {
    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LPAdapterResult?

    func buildHarvestPlan(
        position: LPPositionSummary,
        network: WalletNetwork
    ) async throws -> OrcaHarvestPlan
}

struct OrcaHelperBridge: OrcaHelperBridging {
    let policy: OrcaHelperInvocationPolicy
    let projectRoot: URL?
    let pathResolver: any OrcaHelperPathResolving
    let processRunner: any OrcaHelperProcessRunning

    static func disabled() -> OrcaHelperBridge {
        OrcaHelperBridge(
            policy: .disabled,
            projectRoot: nil,
            pathResolver: OrcaHelperPathResolver(),
            processRunner: OrcaHelperDirectProcessRunner()
        )
    }

    static func liveDefault() -> OrcaHelperBridge {
        OrcaHelperBridge(
            policy: .readOnlyEnabledForDevelopment(),
            projectRoot: OrcaHelperProjectRootResolver.resolve(),
            pathResolver: OrcaHelperPathResolver(),
            processRunner: OrcaHelperDirectProcessRunner()
        )
    }

    func buildHarvestPlan(
        position: LPPositionSummary,
        network: WalletNetwork
    ) async throws -> OrcaHarvestPlan {
        guard policy.enabled else {
            throw OrcaHelperError.disabled
        }
        guard position.protocolKind == .orca else {
            throw OrcaHelperError.responseRejected("harvest plan requires an Orca LP position")
        }
        guard let positionMint = position.positionMintAddress ?? (SolanaAddressValidator.isValidAddress(position.positionAddress) ? position.positionAddress : nil) else {
            throw OrcaHelperError.responseRejected("Orca LP position mint is unavailable")
        }

        let request = OrcaHelperRequest(
            command: .harvestPlan,
            walletPublicAddress: position.walletPublicAddress,
            positionMint: positionMint,
            positionAddress: position.positionAddress,
            network: network,
            rpcURL: network.rpcURL.absoluteString
        )
        let response = try await invoke(request)
        guard response.status == .loaded || response.status == .empty,
              let plan = response.harvestPlan else {
            throw OrcaHelperError.helperRejected(response.message)
        }
        return plan
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
            let request = OrcaHelperRequest(
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
                case .unavailable, .error, .rejected:
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
                protocolKind: .orca,
                status: status,
                positions: positions,
                source: .sdkReadOnly,
                updatedAt: updatedAt,
                errorMessage: messages.isEmpty ? nil : messages.joined(separator: " ")
            )
        }

        if sawEmpty && messages.isEmpty {
            return LPAdapterResult(
                protocolKind: .orca,
                status: .empty,
                positions: [],
                source: .sdkReadOnly,
                updatedAt: updatedAt,
                errorMessage: "No Orca Whirlpools positions returned for the selected public wallet scope."
            )
        }

        return LPAdapterResult(
            protocolKind: .orca,
            status: .unavailable,
            positions: [],
            source: .sdkReadOnly,
            updatedAt: updatedAt,
            errorMessage: messages.isEmpty ? "Orca read-only helper did not return positions." : messages.joined(separator: " ")
        )
    }

    private func invoke(_ request: OrcaHelperRequest) async throws -> OrcaHelperResponse {
        try validate(request)
        let path = try pathResolver.resolve(policy: policy, projectRoot: projectRoot)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let input = try encoder.encode(request)
        let result = try await processRunner.run(resolvedPath: path, command: request.command, stdin: input)
        guard result.exitCode == 0 else {
            throw OrcaHelperError.helperRejected(result.stderr)
        }
        try validateNoForbiddenJSONFields(result.stdout)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(OrcaHelperResponse.self, from: result.stdout)
        try validate(response, for: request)
        return response
    }

    private func validate(_ request: OrcaHelperRequest) throws {
        guard policy.enabled else {
            throw OrcaHelperError.disabled
        }
        guard policy.allowedCommands.contains(request.command) else {
            throw OrcaHelperError.commandNotAllowlisted(request.command)
        }
        if let walletPublicAddress = request.walletPublicAddress {
            guard SolanaAddressValidator.isValidAddress(walletPublicAddress) else {
                throw OrcaHelperError.responseRejected("invalid public wallet address")
            }
        }
        if let positionMint = request.positionMint {
            guard SolanaAddressValidator.isValidAddress(positionMint) else {
                throw OrcaHelperError.responseRejected("invalid Orca LP position mint")
            }
        }
    }

    private func validate(_ response: OrcaHelperResponse, for request: OrcaHelperRequest) throws {
        guard response.command == request.command else {
            throw OrcaHelperError.responseRejected("command mismatch")
        }
        guard response.sdkValidation?.readOnlyMethodAvailable != false else {
            throw OrcaHelperError.responseRejected("Orca SDK read-only method unavailable")
        }
    }

    private func validateNoForbiddenJSONFields(_ data: Data) throws {
        let object = try JSONSerialization.jsonObject(with: data)
        if containsForbiddenField(object) {
            throw OrcaHelperError.responseRejected("forbidden field in response")
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
        position: OrcaHelperPosition,
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
        let status: LPAdapterStatus = estimatedValue == nil || tokenA == nil || tokenB == nil ? .partial : position.status.lpStatus
        let range = LPRangeSummary(
            lowerBinID: position.tickLowerIndex,
            upperBinID: position.tickUpperIndex,
            currentBinID: position.tickCurrentIndex,
            state: position.rangeState,
            unavailableReason: position.tickLowerIndex == nil && position.tickUpperIndex == nil ? "Orca helper did not expose complete tick range metadata." : nil
        )

        return LPPositionSummary(
            walletID: profile.id,
            walletLabel: profile.label,
            walletPublicAddress: profile.publicAddress,
            network: network,
            protocolKind: .orca,
            poolAddress: position.poolAddress,
            positionAddress: position.positionAddress,
            positionMintAddress: position.positionMint,
            tokenA: tokenA,
            tokenB: tokenB,
            estimatedValueUSD: estimatedValue,
            feeSummary: feeSummary(position: position, network: network, prices: prices),
            rangeSummary: range,
            impermanentLoss: .unavailable,
            source: .sdkReadOnly,
            updatedAt: updatedAt,
            status: status,
            metadataStatus: position.metadataStatus ?? "Official Orca Whirlpools read-only helper; no transaction or signing path used.",
            errorMessage: status == .partial ? "Orca position returned partial value or metadata coverage." : nil
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
        position: OrcaHelperPosition,
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
            return "[redacted orca helper message]"
        }
        return value
    }
}

enum OrcaHelperProjectRootResolver {
    static func resolve() -> URL? {
        let env = ProcessInfo.processInfo.environment
        if let explicit = env["GORKH_PROJECT_ROOT"], !explicit.isEmpty {
            return URL(fileURLWithPath: explicit)
        }
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return firstProjectRoot(startingAt: current)
    }

    private static func firstProjectRoot(startingAt url: URL) -> URL? {
        var candidate = url.standardizedFileURL
        for _ in 0..<8 {
            let helper = candidate.appendingPathComponent(OrcaHelperPathResolver.allowedRelativePath)
            if FileManager.default.fileExists(atPath: helper.path) {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path {
                return nil
            }
            candidate = parent
        }
        return nil
    }
}

struct OrcaHelperResolvedPath: Equatable {
    let nodeExecutable: URL
    let helperScript: URL
    let helperRelativePath: String
}

protocol OrcaHelperPathResolving {
    func resolve(policy: OrcaHelperInvocationPolicy, projectRoot: URL?) throws -> OrcaHelperResolvedPath
}

struct OrcaHelperPathResolver: OrcaHelperPathResolving {
    static let allowedRelativePath = "tools/orca-readonly/src/index.ts"

    func resolve(policy: OrcaHelperInvocationPolicy, projectRoot: URL?) throws -> OrcaHelperResolvedPath {
        guard policy.enabled else {
            throw OrcaHelperError.disabled
        }
        guard policy.allowlistedHelperRelativePath == Self.allowedRelativePath,
              isSafeRelativePath(policy.allowlistedHelperRelativePath) else {
            throw OrcaHelperError.disallowedHelperPath(policy.allowlistedHelperRelativePath)
        }
        guard let projectRoot else {
            throw OrcaHelperError.projectRootMissing
        }
        let node = try resolveNode(candidates: policy.allowedNodeExecutablePaths)
        return OrcaHelperResolvedPath(
            nodeExecutable: node,
            helperScript: projectRoot.appendingPathComponent(policy.allowlistedHelperRelativePath),
            helperRelativePath: policy.allowlistedHelperRelativePath
        )
    }

    private func resolveNode(candidates: [String]) throws -> URL {
        for candidate in candidates {
            guard OrcaHelperInvocationPolicy.disabled.allowedNodeExecutablePaths.contains(candidate) else {
                throw OrcaHelperError.disallowedNodeExecutable(candidate)
            }
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        throw OrcaHelperError.nodeUnavailable
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

struct OrcaHelperProcessResult: Equatable {
    let exitCode: Int32
    let stdout: Data
    let stderr: String
}

protocol OrcaHelperProcessRunning {
    func run(
        resolvedPath: OrcaHelperResolvedPath,
        command: OrcaHelperCommand,
        stdin: Data
    ) async throws -> OrcaHelperProcessResult
}

struct OrcaHelperDirectProcessRunner: OrcaHelperProcessRunning {
    func run(
        resolvedPath: OrcaHelperResolvedPath,
        command: OrcaHelperCommand,
        stdin: Data
    ) async throws -> OrcaHelperProcessResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let input = Pipe()

        process.executableURL = resolvedPath.nodeExecutable
        process.arguments = [resolvedPath.helperScript.path, command.rawValue]
        process.standardInput = input
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = rpcFastEnvironment()

        try process.run()
        try input.fileHandleForWriting.write(contentsOf: stdin)
        try input.fileHandleForWriting.close()
        process.waitUntilExit()

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return OrcaHelperProcessResult(
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
            return "[redacted orca helper stderr]"
        }
        return String(value.prefix(500))
    }

    private func rpcFastEnvironment() -> [String: String] {
        let env = ProcessInfo.processInfo.environment
        return [
            RPCFastConfiguration.mainnetTokenEnvironmentName,
            RPCFastConfiguration.fallbackMainnetTokenEnvironmentName
        ].reduce(into: [String: String]()) { partial, key in
            if let value = env[key], !value.isEmpty {
                partial[key] = value
            }
        }
    }
}
