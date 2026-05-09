import Foundation

enum CloakAdapterStatus: String, Codable, CaseIterable, Equatable {
    case lockedInPhase20 = "locked_in_phase_2_0"
    case sdkUnavailable = "sdk_unavailable"
    case environmentUnsupported = "environment_unsupported"

    var title: String {
        switch self {
        case .lockedInPhase20:
            return "Execution Locked"
        case .sdkUnavailable:
            return "SDK Bridge Unavailable"
        case .environmentUnsupported:
            return "Environment Unsupported"
        }
    }
}

enum CloakPrivateWalletStatus: String, Codable, Equatable {
    case notInitialized = "not_initialized"
    case statusOnly = "status_only"
    case readyForFutureStorage = "ready_for_future_storage"

    var title: String {
        switch self {
        case .notInitialized:
            return "Not Initialized"
        case .statusOnly:
            return "Status Only"
        case .readyForFutureStorage:
            return "Ready for Future Storage"
        }
    }
}

enum CloakActionKind: String, Codable, CaseIterable, Identifiable, Equatable {
    case deposit = "deposit"
    case privateTransfer = "private_transfer"
    case fullWithdraw = "full_withdraw"
    case partialWithdraw = "partial_withdraw"
    case privateSwap = "private_swap"
    case complianceScan = "compliance_scan"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deposit:
            return "Execute Deposit"
        case .privateTransfer:
            return "Private Transfer"
        case .fullWithdraw:
            return "Full Withdraw"
        case .partialWithdraw:
            return "Partial Withdraw"
        case .privateSwap:
            return "Private Swap"
        case .complianceScan:
            return "Compliance Scan"
        }
    }
}

enum CloakActionState: String, Codable, Equatable {
    case draftOnly = "draft_only"
    case locked = "locked"
    case unavailable = "unavailable"
    case blocked = "blocked"

    var title: String {
        switch self {
        case .draftOnly:
            return "Draft Only"
        case .locked:
            return "Locked"
        case .unavailable:
            return "Unavailable"
        case .blocked:
            return "Blocked"
        }
    }
}

struct CloakFeeQuote: Codable, Equatable {
    let grossLamports: UInt64
    let fixedFeeLamports: UInt64
    let variableFeeLamports: UInt64
    let totalFeeLamports: UInt64
    let netLamports: UInt64
    let minimumDepositLamports: UInt64

    var grossSOLText: String { Self.solText(grossLamports) }
    var totalFeeSOLText: String { Self.solText(totalFeeLamports) }
    var netSOLText: String { Self.solText(netLamports) }

    private static func solText(_ lamports: UInt64) -> String {
        let sol = Decimal(lamports) / Decimal(SolanaConstants.lamportsPerSol)
        return "\(sol) SOL"
    }
}

struct CloakDepositDraft: Codable, Equatable, Identifiable {
    let id: UUID
    let network: WalletNetwork
    let sourceWalletAddress: String
    let mintAddress: String
    let grossLamports: UInt64
    let feeQuote: CloakFeeQuote
    let actionState: CloakActionState
    let createdAt: Date

    init(
        id: UUID = UUID(),
        network: WalletNetwork,
        sourceWalletAddress: String,
        grossLamports: UInt64,
        createdAt: Date = Date()
    ) throws {
        let quote = try CloakFeeModel.quote(grossLamports: grossLamports)
        self.id = id
        self.network = network
        self.sourceWalletAddress = sourceWalletAddress
        self.mintAddress = CloakConstants.nativeSolMint
        self.grossLamports = grossLamports
        self.feeQuote = quote
        self.actionState = .draftOnly
        self.createdAt = createdAt
    }

    var networkWarning: String? {
        network.isMainnet ? "Future Cloak deposits would use real mainnet SOL." : "Cloak is mainnet-oriented. Phase 2.0 does not create a fake devnet Cloak mode."
    }
}

struct CloakPrivateAuditSummary: Codable, Equatable {
    let actionKind: CloakActionKind
    let network: WalletNetwork
    let publicAddress: String
    let amountLamports: UInt64?
    let requestID: UUID?
    let transactionSignature: String?
    let commitmentPrefix: String?
    let leafIndex: Int?
}

struct CloakBridgeRequestSummary: Codable, Equatable, Identifiable {
    let id: UUID
    let actionKind: CloakActionKind
    let network: WalletNetwork
    let walletPublicAddress: String
    let grossLamports: UInt64?
    let programID: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        actionKind: CloakActionKind,
        network: WalletNetwork,
        walletPublicAddress: String,
        grossLamports: UInt64?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.actionKind = actionKind
        self.network = network
        self.walletPublicAddress = walletPublicAddress
        self.grossLamports = grossLamports
        self.programID = CloakConstants.programID
        self.createdAt = createdAt
    }
}

struct CloakBridgeResponseSummary: Codable, Equatable {
    let requestID: UUID?
    let actionKind: CloakActionKind?
    let status: CloakActionState
    let message: String
    let programID: String
    let createdAt: Date

    static func locked(request: CloakBridgeRequestSummary? = nil) -> CloakBridgeResponseSummary {
        CloakBridgeResponseSummary(
            requestID: request?.id,
            actionKind: request?.actionKind,
            status: .locked,
            message: CloakConstants.phaseLockMessage,
            programID: CloakConstants.programID,
            createdAt: Date()
        )
    }
}

enum CloakSecretKind: String, Codable, CaseIterable, Equatable {
    case viewingKeyReference = "viewing_key_reference"
    case encryptedUtxoReference = "encrypted_utxo_reference"
    case scanCacheReference = "scan_cache_reference"

    var title: String {
        switch self {
        case .viewingKeyReference:
            return "Viewing key reference"
        case .encryptedUtxoReference:
            return "Encrypted UTXO reference"
        case .scanCacheReference:
            return "Scan cache reference"
        }
    }
}

struct CloakVaultStatus: Codable, Equatable {
    let walletID: UUID?
    let privateWalletStatus: CloakPrivateWalletStatus
    let availableReferenceKinds: [CloakSecretKind]
    let storageDescription: String
    let canClearPrivateData: Bool

    var hasViewingKeyReference: Bool {
        availableReferenceKinds.contains(.viewingKeyReference)
    }

    var hasUtxoReference: Bool {
        availableReferenceKinds.contains(.encryptedUtxoReference)
    }

    var hasScanCacheReference: Bool {
        availableReferenceKinds.contains(.scanCacheReference)
    }

    static func statusOnly(walletID: UUID?) -> CloakVaultStatus {
        CloakVaultStatus(
            walletID: walletID,
            privateWalletStatus: .statusOnly,
            availableReferenceKinds: [],
            storageDescription: "Phase 2.0 stores no Cloak notes, UTXOs, viewing keys, nullifiers, proof inputs, or scan cache in UserDefaults.",
            canClearPrivateData: false
        )
    }
}
