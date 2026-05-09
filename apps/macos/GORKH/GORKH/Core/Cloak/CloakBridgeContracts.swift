import Foundation

enum CloakBridgeCommand: String, Codable, CaseIterable, Identifiable, Equatable {
    case health
    case environmentCheck = "env-check"
    case depositPlan = "deposit-plan"
    case executeDeposit = "execute-deposit"
    case fullWithdraw = "full-withdraw"
    case partialWithdraw = "partial-withdraw"
    case privateTransfer = "private-transfer"
    case swap
    case scan
    case complianceExport = "compliance-export"

    var id: String { rawValue }

    var isHelperCommandAllowedInPhase23: Bool {
        switch self {
        case .health, .environmentCheck, .depositPlan:
            return true
        case .executeDeposit, .fullWithdraw, .partialWithdraw, .privateTransfer, .swap, .scan, .complianceExport:
            return false
        }
    }

    var isHelperCommandAllowedInPhase25: Bool {
        switch self {
        case .health, .environmentCheck, .depositPlan, .executeDeposit, .fullWithdraw:
            return true
        case .partialWithdraw, .privateTransfer, .swap, .scan, .complianceExport:
            return false
        }
    }
}

enum CloakBridgeStatus: String, Codable, Equatable {
    case ok
    case locked
    case unavailable
    case rejected
    case error
}

enum CloakBridgeErrorCategory: String, Codable, Equatable {
    case none
    case lockedInPhase23 = "locked-in-phase-2-3"
    case forbiddenField = "forbidden-field"
    case invalidRequest = "invalid-request"
    case unsupportedCommand = "unsupported-command"
    case helperUnavailable = "helper-unavailable"
}

struct CloakBridgeRequest: Codable, Equatable, Identifiable {
    let id: UUID
    let command: CloakBridgeCommand
    let actionKind: CloakActionKind?
    let network: WalletNetwork
    let walletPublicAddress: String?
    let amountLamports: UInt64?
    let mintAddress: String?
    let programID: String
    let feeQuote: CloakFeeQuote?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "requestId"
        case command
        case actionKind
        case network
        case walletPublicAddress
        case amountLamports
        case mintAddress
        case programID = "programId"
        case feeQuote
        case createdAt = "timestamp"
    }

    init(
        id: UUID = UUID(),
        command: CloakBridgeCommand,
        actionKind: CloakActionKind? = nil,
        network: WalletNetwork,
        walletPublicAddress: String? = nil,
        amountLamports: UInt64? = nil,
        mintAddress: String? = nil,
        programID: String = CloakConstants.programID,
        feeQuote: CloakFeeQuote? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.command = command
        self.actionKind = actionKind
        self.network = network
        self.walletPublicAddress = walletPublicAddress
        self.amountLamports = amountLamports
        self.mintAddress = mintAddress
        self.programID = programID
        self.feeQuote = feeQuote
        self.createdAt = createdAt
    }
}

struct CloakSDKValidation: Codable, Equatable {
    let sdkInstalled: Bool
    let sdkImportOk: Bool
    let sdkVersion: String?
    let cloakProgramID: String?
    let expectedProgramID: String
    let programIDMatches: Bool
    let nativeSOLMint: String?
    let feeHelpersAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case sdkInstalled
        case sdkImportOk
        case sdkVersion
        case cloakProgramID = "cloakProgramId"
        case expectedProgramID = "expectedProgramId"
        case programIDMatches = "programIdMatches"
        case nativeSOLMint = "nativeSolMint"
        case feeHelpersAvailable
    }
}

struct CloakFeeValidationSample: Codable, Equatable {
    let grossLamports: String
    let gorkhFeeLamports: String
    let gorkhNetLamports: String
    let sdkFeeLamports: String?
    let sdkNetLamports: String?
    let matches: Bool?
}

enum CloakFeeValidationSource: String, Codable, Equatable {
    case sdk
    case gorkhLocal = "gorkh-local"
    case unavailable
}

struct CloakFeeValidation: Codable, Equatable {
    let available: Bool
    let source: CloakFeeValidationSource
    let samples: [CloakFeeValidationSample]
    let message: String

    var allSamplesMatch: Bool? {
        guard available else { return nil }
        return samples.allSatisfy { $0.matches == true }
    }
}

enum CloakRPCURLStatus: String, Codable, Equatable {
    case missing
    case presentRedacted = "present-redacted"
}

enum CloakHelperMode: String, Codable, Equatable {
    case dryRunNonExecuting = "dry-run-non-executing"
}

struct CloakEnvironmentValidation: Codable, Equatable {
    let solanaRPCURLStatus: CloakRPCURLStatus
    let rpcURLRedacted: String?
    let requestedNetwork: WalletNetwork?
    let networkSupportedForFutureExecution: Bool
    let helperMode: CloakHelperMode
    let executionCommandsLocked: Bool
    let keypairPathRequired: Bool
    let walletSecretEnvAccepted: Bool
    let suspiciousEnvVarNames: [String]

    enum CodingKeys: String, CodingKey {
        case solanaRPCURLStatus = "solanaRpcUrlStatus"
        case rpcURLRedacted = "rpcUrlRedacted"
        case requestedNetwork
        case networkSupportedForFutureExecution
        case helperMode
        case executionCommandsLocked
        case keypairPathRequired
        case walletSecretEnvAccepted
        case suspiciousEnvVarNames
    }
}

struct CloakBridgeResponse: Codable, Equatable, Identifiable {
    let id: UUID
    let requestID: UUID?
    let command: CloakBridgeCommand
    let actionKind: CloakActionKind?
    let status: CloakBridgeStatus
    let errorCategory: CloakBridgeErrorCategory
    let message: String
    let programID: String
    let feeQuote: CloakFeeQuote?
    let sdkValidation: CloakSDKValidation?
    let feeValidation: CloakFeeValidation?
    let environmentValidation: CloakEnvironmentValidation?
    let signerRequestSummary: CloakSignerRequestSummary?
    let nextRequiredGates: [String]?
    let transactionSignature: String?
    let commitmentPrefix: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requestID = "requestId"
        case command
        case actionKind
        case status
        case errorCategory
        case message
        case programID = "programId"
        case feeQuote
        case sdkValidation
        case feeValidation
        case environmentValidation
        case signerRequestSummary
        case nextRequiredGates
        case transactionSignature = "txSignature"
        case commitmentPrefix
        case createdAt = "timestamp"
    }

    init(
        id: UUID = UUID(),
        requestID: UUID?,
        command: CloakBridgeCommand,
        actionKind: CloakActionKind? = nil,
        status: CloakBridgeStatus,
        errorCategory: CloakBridgeErrorCategory = .none,
        message: String,
        programID: String = CloakConstants.programID,
        feeQuote: CloakFeeQuote? = nil,
        sdkValidation: CloakSDKValidation? = nil,
        feeValidation: CloakFeeValidation? = nil,
        environmentValidation: CloakEnvironmentValidation? = nil,
        signerRequestSummary: CloakSignerRequestSummary? = nil,
        nextRequiredGates: [String]? = nil,
        transactionSignature: String? = nil,
        commitmentPrefix: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.requestID = requestID
        self.command = command
        self.actionKind = actionKind
        self.status = status
        self.errorCategory = errorCategory
        self.message = message
        self.programID = programID
        self.feeQuote = feeQuote
        self.sdkValidation = sdkValidation
        self.feeValidation = feeValidation
        self.environmentValidation = environmentValidation
        self.signerRequestSummary = signerRequestSummary
        self.nextRequiredGates = nextRequiredGates
        self.transactionSignature = transactionSignature
        self.commitmentPrefix = commitmentPrefix
        self.createdAt = createdAt
    }

    static func locked(request: CloakBridgeRequest, message: String = CloakConstants.phaseLockMessage) -> CloakBridgeResponse {
        CloakBridgeResponse(
            requestID: request.id,
            command: request.command,
            actionKind: request.actionKind,
            status: .locked,
            errorCategory: .lockedInPhase23,
            message: message,
            feeQuote: request.feeQuote
        )
    }
}

struct CloakBridgeExecutionPolicy: Equatable {
    let helperExecutionEnabled: Bool
    let allowlistedHelperRelativePath: String
    let allowedNodeExecutablePaths: [String]
    let allowedCommands: Set<CloakBridgeCommand>

    static let disabled = CloakBridgeExecutionPolicy(
        helperExecutionEnabled: false,
        allowlistedHelperRelativePath: "tools/cloak-bridge/src/index.ts",
        allowedNodeExecutablePaths: [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node"
        ],
        allowedCommands: [.health, .environmentCheck, .depositPlan]
    )

    static func dryRunEnabledForDevelopment(
        allowedNodeExecutablePaths: [String] = CloakBridgeExecutionPolicy.disabled.allowedNodeExecutablePaths
    ) -> CloakBridgeExecutionPolicy {
        CloakBridgeExecutionPolicy(
            helperExecutionEnabled: true,
            allowlistedHelperRelativePath: CloakBridgeExecutionPolicy.disabled.allowlistedHelperRelativePath,
            allowedNodeExecutablePaths: allowedNodeExecutablePaths,
            allowedCommands: CloakBridgeExecutionPolicy.disabled.allowedCommands
        )
    }

    static func phase25Enabled(
        allowedNodeExecutablePaths: [String] = CloakBridgeExecutionPolicy.disabled.allowedNodeExecutablePaths
    ) -> CloakBridgeExecutionPolicy {
        CloakBridgeExecutionPolicy(
            helperExecutionEnabled: true,
            allowlistedHelperRelativePath: CloakBridgeExecutionPolicy.disabled.allowlistedHelperRelativePath,
            allowedNodeExecutablePaths: allowedNodeExecutablePaths,
            allowedCommands: [.health, .environmentCheck, .depositPlan, .executeDeposit, .fullWithdraw]
        )
    }

    func canInvokeHelper(command: CloakBridgeCommand, relativePath: String) -> Bool {
        helperExecutionEnabled
            && relativePath == allowlistedHelperRelativePath
            && allowedCommands.contains(command)
            && command.isHelperCommandAllowedInPhase25
    }
}

enum CloakHelperInvocationStatus: String, Codable, Equatable {
    case disabled
    case dryRunEnabled = "dry_run_enabled"
    case unavailable
    case error

    var title: String {
        switch self {
        case .disabled:
            return "Helper disabled"
        case .dryRunEnabled:
            return "Dry-run helper enabled"
        case .unavailable:
            return "Helper unavailable"
        case .error:
            return "Helper error"
        }
    }
}
