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

    var isHelperCommandAllowedInPhase22: Bool {
        switch self {
        case .health, .environmentCheck, .depositPlan:
            return true
        case .executeDeposit, .fullWithdraw, .partialWithdraw, .privateTransfer, .swap, .scan, .complianceExport:
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
    case lockedInPhase22 = "locked-in-phase-2-2"
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
            errorCategory: .lockedInPhase22,
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

    func canInvokeHelper(command: CloakBridgeCommand, relativePath: String) -> Bool {
        helperExecutionEnabled
            && relativePath == allowlistedHelperRelativePath
            && allowedCommands.contains(command)
            && command.isHelperCommandAllowedInPhase22
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
