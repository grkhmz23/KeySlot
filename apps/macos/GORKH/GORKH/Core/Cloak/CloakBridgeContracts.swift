import Foundation

enum CloakBridgeCommand: String, Codable, CaseIterable, Identifiable, Equatable {
    case health
    case environmentCheck = "env_check"
    case depositPlan = "deposit_plan"
    case executeDeposit = "execute_deposit"
    case fullWithdraw = "full_withdraw"
    case partialWithdraw = "partial_withdraw"
    case scan = "scan"

    var id: String { rawValue }

    var isHelperCommandAllowedInPhase21: Bool {
        switch self {
        case .health, .environmentCheck, .depositPlan:
            return true
        case .executeDeposit, .fullWithdraw, .partialWithdraw, .scan:
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
    case lockedInPhase21 = "locked_in_phase_2_1"
    case forbiddenField = "forbidden_field"
    case invalidRequest = "invalid_request"
    case unsupportedCommand = "unsupported_command"
    case helperUnavailable = "helper_unavailable"
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
            errorCategory: .lockedInPhase21,
            message: message,
            feeQuote: request.feeQuote
        )
    }
}

struct CloakBridgeExecutionPolicy: Equatable {
    let helperExecutionEnabled: Bool
    let allowlistedHelperRelativePath: String
    let allowedCommands: Set<CloakBridgeCommand>

    static let disabled = CloakBridgeExecutionPolicy(
        helperExecutionEnabled: false,
        allowlistedHelperRelativePath: "tools/cloak-bridge/src/index.ts",
        allowedCommands: [.health, .environmentCheck, .depositPlan]
    )

    func canInvokeHelper(command: CloakBridgeCommand, relativePath: String) -> Bool {
        helperExecutionEnabled
            && relativePath == allowlistedHelperRelativePath
            && allowedCommands.contains(command)
            && command.isHelperCommandAllowedInPhase21
    }
}
