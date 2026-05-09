import Foundation

enum MarginFiHelperCommand: String, Codable, CaseIterable {
    case health
    case envCheck = "env-check"
    case positions
}

enum MarginFiHelperError: LocalizedError, Equatable {
    case disabled
    case commandNotAllowlisted(MarginFiHelperCommand)
    case projectRootMissing
    case disallowedHelperPath(String)
    case disallowedNodeExecutable(String)
    case nodeUnavailable
    case helperRejected(String)
    case responseRejected(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "MarginFi read-only helper invocation is disabled."
        case .commandNotAllowlisted(let command):
            return "MarginFi helper command is not allowlisted: \(command.rawValue)."
        case .projectRootMissing:
            return "Project root is required for MarginFi helper invocation."
        case .disallowedHelperPath(let path):
            return "MarginFi helper path is not allowlisted: \(path)."
        case .disallowedNodeExecutable(let path):
            return "Node executable path is not allowlisted: \(path)."
        case .nodeUnavailable:
            return "No allowlisted Node executable is available for MarginFi helper invocation."
        case .helperRejected(let message):
            return message
        case .responseRejected(let message):
            return "MarginFi helper response rejected: \(message)"
        }
    }
}

struct MarginFiHelperInvocationPolicy: Equatable {
    let enabled: Bool
    let allowlistedHelperRelativePath: String
    let allowedNodeExecutablePaths: [String]
    let allowedCommands: Set<MarginFiHelperCommand>

    static let disabled = MarginFiHelperInvocationPolicy(
        enabled: false,
        allowlistedHelperRelativePath: "tools/marginfi-readonly/src/index.ts",
        allowedNodeExecutablePaths: [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node"
        ],
        allowedCommands: [.health, .envCheck, .positions]
    )

    static func readOnlyEnabledForDevelopment(
        allowedNodeExecutablePaths: [String] = MarginFiHelperInvocationPolicy.disabled.allowedNodeExecutablePaths
    ) -> MarginFiHelperInvocationPolicy {
        MarginFiHelperInvocationPolicy(
            enabled: true,
            allowlistedHelperRelativePath: MarginFiHelperInvocationPolicy.disabled.allowlistedHelperRelativePath,
            allowedNodeExecutablePaths: allowedNodeExecutablePaths,
            allowedCommands: MarginFiHelperInvocationPolicy.disabled.allowedCommands
        )
    }
}

struct MarginFiHelperRequest: Codable, Equatable {
    let requestID: String
    let command: MarginFiHelperCommand
    let walletPublicAddress: String?
    let network: WalletNetwork
    let rpcURL: String?
    let timestamp: Date

    init(
        requestID: String = UUID().uuidString,
        command: MarginFiHelperCommand,
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

struct MarginFiHelperResponse: Codable, Equatable {
    let id: String
    let requestID: String?
    let command: MarginFiHelperCommand
    let status: LendingAdapterStatus
    let errorCategory: String
    let message: String
    let programID: String
    let groupID: String?
    let sdkValidation: MarginFiHelperSDKValidation?
    let positions: [MarginFiHelperPosition]?
    let accountCount: Int?
    let suppliedPositionCount: Int?
    let borrowedPositionCount: Int?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requestID = "requestId"
        case command
        case status
        case errorCategory
        case message
        case programID = "programId"
        case groupID = "groupId"
        case sdkValidation
        case positions
        case accountCount
        case suppliedPositionCount
        case borrowedPositionCount
        case timestamp
    }
}

struct MarginFiHelperSDKValidation: Codable, Equatable {
    let sdkInstalled: Bool
    let sdkImportOk: Bool
    let sdkVersion: String?
    let programID: String
    let expectedProgramID: String
    let programIDMatches: Bool
    let groupID: String?
    let groupIDSource: String
    let readOnlyWallet: Bool

    enum CodingKeys: String, CodingKey {
        case sdkInstalled
        case sdkImportOk
        case sdkVersion
        case programID = "programId"
        case expectedProgramID = "expectedProgramId"
        case programIDMatches = "programIdMatches"
        case groupID = "groupId"
        case groupIDSource = "groupIdSource"
        case readOnlyWallet
    }
}

struct MarginFiHelperPosition: Codable, Equatable {
    let walletPublicAddress: String
    let accountAddress: String
    let groupAddress: String?
    let suppliedAssets: [MarginFiHelperAsset]
    let borrowedAssets: [MarginFiHelperAsset]
    let suppliedPositionCount: Int
    let borrowedPositionCount: Int
    let suppliedValueUSD: String?
    let borrowedValueUSD: String?
    let netValueUSD: String?
    let healthFactor: String?
    let ltv: String?
    let riskLevel: LendingRiskLevel
    let status: LendingAdapterStatus
    let metadataStatus: String?

    enum CodingKeys: String, CodingKey {
        case walletPublicAddress
        case accountAddress
        case groupAddress
        case suppliedAssets
        case borrowedAssets
        case suppliedPositionCount
        case borrowedPositionCount
        case suppliedValueUSD = "suppliedValueUsd"
        case borrowedValueUSD = "borrowedValueUsd"
        case netValueUSD = "netValueUsd"
        case healthFactor
        case ltv
        case riskLevel
        case status
        case metadataStatus
    }
}

struct MarginFiHelperAsset: Codable, Equatable {
    let side: String
    let bankAddress: String?
    let mintAddress: String?
    let symbol: String?
    let quantityUI: String?
    let usdValue: String?

    enum CodingKeys: String, CodingKey {
        case side
        case bankAddress
        case mintAddress
        case symbol
        case quantityUI = "quantityUi"
        case usdValue
    }
}

protocol MarginFiHelperBridging {
    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LendingAdapterResult?
}

struct MarginFiHelperBridge: MarginFiHelperBridging {
    let policy: MarginFiHelperInvocationPolicy
    let projectRoot: URL?
    let pathResolver: any MarginFiHelperPathResolving
    let processRunner: any MarginFiHelperProcessRunning

    static func disabled() -> MarginFiHelperBridge {
        MarginFiHelperBridge(
            policy: .disabled,
            projectRoot: nil,
            pathResolver: MarginFiHelperPathResolver(),
            processRunner: MarginFiHelperDirectProcessRunner()
        )
    }

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LendingAdapterResult? {
        guard policy.enabled else {
            return nil
        }

        let updatedAt = Date()
        var positions: [LendingPositionSummary] = []
        var messages: [String] = []
        var sawEmpty = false

        for profile in profiles {
            let request = MarginFiHelperRequest(
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
                        normalize(position: $0, profile: profile, network: network, updatedAt: updatedAt)
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
            let status: LendingAdapterStatus = positions.contains { $0.status == .partial } ? .partial : .loaded
            return LendingAdapterResult(
                protocolKind: .marginFi,
                status: status,
                positions: positions,
                source: .sdkReadOnly,
                updatedAt: updatedAt,
                errorMessage: messages.isEmpty ? nil : messages.joined(separator: " "),
                marketReserves: []
            )
        }

        if sawEmpty && messages.isEmpty {
            return LendingAdapterResult(
                protocolKind: .marginFi,
                status: .empty,
                positions: [],
                source: .sdkReadOnly,
                updatedAt: updatedAt,
                errorMessage: "No MarginFi accounts returned by the official SDK read-only helper.",
                marketReserves: []
            )
        }

        return LendingAdapterResult(
            protocolKind: .marginFi,
            status: .unavailable,
            positions: [],
            source: .sdkReadOnly,
            updatedAt: updatedAt,
            errorMessage: messages.isEmpty ? "MarginFi SDK read-only helper did not return positions." : messages.joined(separator: " "),
            marketReserves: []
        )
    }

    private func invoke(_ request: MarginFiHelperRequest) async throws -> MarginFiHelperResponse {
        try validate(request)
        let path = try pathResolver.resolve(policy: policy, projectRoot: projectRoot)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let input = try encoder.encode(request)
        let result = try await processRunner.run(resolvedPath: path, command: request.command, stdin: input)
        guard result.exitCode == 0 else {
            throw MarginFiHelperError.helperRejected(result.stderr)
        }
        try validateNoForbiddenJSONFields(result.stdout)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(MarginFiHelperResponse.self, from: result.stdout)
        try validate(response, for: request)
        return response
    }

    private func validate(_ request: MarginFiHelperRequest) throws {
        guard policy.enabled else {
            throw MarginFiHelperError.disabled
        }
        guard policy.allowedCommands.contains(request.command) else {
            throw MarginFiHelperError.commandNotAllowlisted(request.command)
        }
        guard request.network == .mainnetBeta else {
            return
        }
        if let walletPublicAddress = request.walletPublicAddress {
            guard SolanaAddressValidator.isValidAddress(walletPublicAddress) else {
                throw MarginFiHelperError.responseRejected("invalid public wallet address")
            }
        }
    }

    private func validate(_ response: MarginFiHelperResponse, for request: MarginFiHelperRequest) throws {
        guard response.command == request.command else {
            throw MarginFiHelperError.responseRejected("command mismatch")
        }
        guard response.programID == MarginFiConstants.programID else {
            throw MarginFiHelperError.responseRejected("program id mismatch")
        }
        guard response.sdkValidation?.readOnlyWallet != false else {
            throw MarginFiHelperError.responseRejected("helper did not report a read-only wallet")
        }
        guard response.sdkValidation?.programIDMatches != false else {
            throw MarginFiHelperError.responseRejected("SDK program id mismatch")
        }
    }

    private func validateNoForbiddenJSONFields(_ data: Data) throws {
        let object = try JSONSerialization.jsonObject(with: data)
        if containsForbiddenField(object) {
            throw MarginFiHelperError.responseRejected("forbidden field in response")
        }
    }

    private func containsForbiddenField(_ value: Any) -> Bool {
        if let dictionary = value as? [String: Any] {
            for (key, nested) in dictionary {
                if Redaction.isSensitiveKey(key) || key.lowercased().contains("instructionpayload") {
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
        position: MarginFiHelperPosition,
        profile: WalletProfile,
        network: WalletNetwork,
        updatedAt: Date
    ) -> LendingPositionSummary {
        let supplied = position.suppliedPositionCount
        let borrowed = position.borrowedPositionCount
        let suppliedValue = decimal(position.suppliedValueUSD)
        let borrowedValue = decimal(position.borrowedValueUSD)
        let netValue = decimal(position.netValueUSD)
        let healthFactor = decimal(position.healthFactor)
        let ltv = decimal(position.ltv)
        let status: LendingAdapterStatus = position.status == .loaded && netValue != nil ? .loaded : .partial

        return LendingPositionSummary(
            walletID: profile.id,
            walletLabel: profile.label,
            walletPublicAddress: profile.publicAddress,
            network: network,
            protocolKind: .marginFi,
            suppliedAssets: [],
            borrowedAssets: [],
            netValueUSD: netValue,
            health: LendingHealthSummary(
                ltv: ltv,
                liquidationThreshold: nil,
                healthFactor: healthFactor,
                riskLevel: LendingHealthSummary.riskLevel(healthFactor: healthFactor, ltv: ltv),
                unavailableReason: healthFactor == nil && ltv == nil ? "MarginFi SDK read-only helper did not expose health or LTV." : nil
            ),
            source: .sdkReadOnly,
            updatedAt: updatedAt,
            status: status,
            errorMessage: "MarginFi SDK read-only account \(position.accountAddress) returned \(supplied) supplied and \(borrowed) borrowed position(s).",
            suppliedValueUSDOverride: suppliedValue,
            borrowedValueUSDOverride: borrowedValue,
            unvaluedSuppliedPositionCount: suppliedValue == nil ? supplied : 0,
            unvaluedBorrowedPositionCount: borrowedValue == nil ? borrowed : 0,
            metadataStatus: position.metadataStatus ?? "Official SDK read-only helper; no transaction or signing path used."
        )
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
            return "[redacted marginfi helper message]"
        }
        return value
    }
}

struct MarginFiHelperResolvedPath: Equatable {
    let nodeExecutable: URL
    let helperScript: URL
    let helperRelativePath: String
}

protocol MarginFiHelperPathResolving {
    func resolve(policy: MarginFiHelperInvocationPolicy, projectRoot: URL?) throws -> MarginFiHelperResolvedPath
}

struct MarginFiHelperPathResolver: MarginFiHelperPathResolving {
    static let allowedRelativePath = "tools/marginfi-readonly/src/index.ts"

    func resolve(policy: MarginFiHelperInvocationPolicy, projectRoot: URL?) throws -> MarginFiHelperResolvedPath {
        guard policy.enabled else {
            throw MarginFiHelperError.disabled
        }
        guard policy.allowlistedHelperRelativePath == Self.allowedRelativePath,
              isSafeRelativePath(policy.allowlistedHelperRelativePath) else {
            throw MarginFiHelperError.disallowedHelperPath(policy.allowlistedHelperRelativePath)
        }
        guard let projectRoot else {
            throw MarginFiHelperError.projectRootMissing
        }
        let node = try resolveNode(candidates: policy.allowedNodeExecutablePaths)
        return MarginFiHelperResolvedPath(
            nodeExecutable: node,
            helperScript: projectRoot.appendingPathComponent(policy.allowlistedHelperRelativePath),
            helperRelativePath: policy.allowlistedHelperRelativePath
        )
    }

    private func resolveNode(candidates: [String]) throws -> URL {
        for candidate in candidates {
            guard MarginFiHelperInvocationPolicy.disabled.allowedNodeExecutablePaths.contains(candidate) else {
                throw MarginFiHelperError.disallowedNodeExecutable(candidate)
            }
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        throw MarginFiHelperError.nodeUnavailable
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

struct MarginFiHelperProcessResult: Equatable {
    let exitCode: Int32
    let stdout: Data
    let stderr: String
}

protocol MarginFiHelperProcessRunning {
    func run(
        resolvedPath: MarginFiHelperResolvedPath,
        command: MarginFiHelperCommand,
        stdin: Data
    ) async throws -> MarginFiHelperProcessResult
}

struct MarginFiHelperDirectProcessRunner: MarginFiHelperProcessRunning {
    func run(
        resolvedPath: MarginFiHelperResolvedPath,
        command: MarginFiHelperCommand,
        stdin: Data
    ) async throws -> MarginFiHelperProcessResult {
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
        return MarginFiHelperProcessResult(
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
            return "[redacted marginfi helper stderr]"
        }
        return String(value.prefix(500))
    }
}
