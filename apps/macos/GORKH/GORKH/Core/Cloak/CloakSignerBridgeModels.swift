import CryptoKit
import Foundation

enum CloakSignerBridgeCapability: String, Codable, CaseIterable, Identifiable, Equatable {
    case signTransactionPreview = "sign_transaction_preview"
    case signMessagePreview = "sign_message_preview"
    case lockedFutureSigning = "locked_future_signing"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signTransactionPreview:
            return "Transaction signing preview"
        case .signMessagePreview:
            return "Message signing preview"
        case .lockedFutureSigning:
            return "Future signing locked"
        }
    }
}

enum CloakSignerRequestKind: String, Codable, CaseIterable, Identifiable, Equatable {
    case signTransactionPreview = "sign_transaction_preview"
    case signMessagePreview = "sign_message_preview"
    case futureSignTransactionLocked = "future_sign_transaction_locked"
    case futureSignMessageLocked = "future_sign_message_locked"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signTransactionPreview:
            return "Sign transaction preview"
        case .signMessagePreview:
            return "Sign message preview"
        case .futureSignTransactionLocked:
            return "Future transaction signing locked"
        case .futureSignMessageLocked:
            return "Future message signing locked"
        }
    }
}

enum CloakSignerApprovalRequirement: String, Codable, CaseIterable, Identifiable, Equatable {
    case walletUnlocked = "wallet_unlocked"
    case localAuthentication = "local_authentication"
    case signerPublicKeyMatch = "signer_public_key_match"
    case networkMatch = "network_match"
    case actionKindMatch = "action_kind_match"
    case amountMatch = "amount_match"
    case cloakProgramMatch = "cloak_program_match"
    case feeQuoteAcknowledged = "fee_quote_acknowledged"
    case shieldReviewCompleted = "shield_review_completed"
    case explicitUserApproval = "explicit_user_approval"
    case mainnetConfirmationPhrase = "mainnet_confirmation_phrase"
    case draftFingerprintMatch = "draft_fingerprint_match"
    case auditBeforeSigning = "audit_before_signing"
    case auditAfterSigning = "audit_after_signing"
    case executionLocked = "execution_locked"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walletUnlocked:
            return "Wallet unlocked"
        case .localAuthentication:
            return "LocalAuthentication passed"
        case .signerPublicKeyMatch:
            return "Signer public key matches wallet"
        case .networkMatch:
            return "Network matches approved draft"
        case .actionKindMatch:
            return "Cloak action matches approved draft"
        case .amountMatch:
            return "Amount matches approved draft"
        case .cloakProgramMatch:
            return "Cloak program id matches"
        case .feeQuoteAcknowledged:
            return "Fee quote acknowledged"
        case .shieldReviewCompleted:
            return "Shield review completed"
        case .explicitUserApproval:
            return "Explicit user approval"
        case .mainnetConfirmationPhrase:
            return "Exact mainnet confirmation phrase"
        case .draftFingerprintMatch:
            return "Draft fingerprint matches"
        case .auditBeforeSigning:
            return "Audit before signing"
        case .auditAfterSigning:
            return "Audit after signing"
        case .executionLocked:
            return "Execution locked in Phase 2.4"
        }
    }
}

enum CloakSignerBridgeState: String, Codable, Equatable {
    case locked
    case unavailable
    case rejected

    var title: String {
        switch self {
        case .locked:
            return "Signer bridge locked"
        case .unavailable:
            return "Signer bridge unavailable"
        case .rejected:
            return "Signer request rejected"
        }
    }
}

struct CloakSignerRequestSummary: Codable, Equatable, Identifiable {
    let id: UUID
    let requestKind: CloakSignerRequestKind
    let walletPublicKey: String
    let network: WalletNetwork
    let actionKind: CloakActionKind
    let amountLamports: UInt64?
    let mintAddress: String
    let programID: String
    let feeQuote: CloakFeeQuote?
    let humanReadableSummary: String
    let expectedTransactionPurpose: String?
    let expectedMessagePurpose: String?
    let draftFingerprint: String
    let approvalState: CloakActionState
    let bridgeState: CloakSignerBridgeState
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requestKind
        case walletPublicKey
        case network
        case actionKind
        case amountLamports
        case mintAddress
        case programID = "programId"
        case feeQuote
        case humanReadableSummary
        case expectedTransactionPurpose
        case expectedMessagePurpose
        case draftFingerprint
        case approvalState
        case bridgeState
        case createdAt = "timestamp"
    }

    init(
        id: UUID = UUID(),
        requestKind: CloakSignerRequestKind,
        walletPublicKey: String,
        network: WalletNetwork,
        actionKind: CloakActionKind,
        amountLamports: UInt64?,
        mintAddress: String,
        programID: String = CloakConstants.programID,
        feeQuote: CloakFeeQuote?,
        humanReadableSummary: String,
        expectedTransactionPurpose: String?,
        expectedMessagePurpose: String?,
        draftFingerprint: String,
        approvalState: CloakActionState = .locked,
        bridgeState: CloakSignerBridgeState = .locked,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.requestKind = requestKind
        self.walletPublicKey = walletPublicKey
        self.network = network
        self.actionKind = actionKind
        self.amountLamports = amountLamports
        self.mintAddress = mintAddress
        self.programID = programID
        self.feeQuote = feeQuote
        self.humanReadableSummary = humanReadableSummary
        self.expectedTransactionPurpose = expectedTransactionPurpose
        self.expectedMessagePurpose = expectedMessagePurpose
        self.draftFingerprint = draftFingerprint
        self.approvalState = approvalState
        self.bridgeState = bridgeState
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        requestKind = try container.decode(CloakSignerRequestKind.self, forKey: .requestKind)
        walletPublicKey = try container.decode(String.self, forKey: .walletPublicKey)
        network = try container.decode(WalletNetwork.self, forKey: .network)
        actionKind = try container.decode(CloakActionKind.self, forKey: .actionKind)
        amountLamports = try container.decodeFlexibleOptionalUInt64(forKey: .amountLamports)
        mintAddress = try container.decode(String.self, forKey: .mintAddress)
        programID = try container.decode(String.self, forKey: .programID)
        feeQuote = try container.decodeIfPresent(CloakFeeQuote.self, forKey: .feeQuote)
        humanReadableSummary = try container.decode(String.self, forKey: .humanReadableSummary)
        expectedTransactionPurpose = try container.decodeIfPresent(String.self, forKey: .expectedTransactionPurpose)
        expectedMessagePurpose = try container.decodeIfPresent(String.self, forKey: .expectedMessagePurpose)
        draftFingerprint = try container.decode(String.self, forKey: .draftFingerprint)
        approvalState = try container.decode(CloakActionState.self, forKey: .approvalState)
        bridgeState = try container.decode(CloakSignerBridgeState.self, forKey: .bridgeState)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(requestKind, forKey: .requestKind)
        try container.encode(walletPublicKey, forKey: .walletPublicKey)
        try container.encode(network, forKey: .network)
        try container.encode(actionKind, forKey: .actionKind)
        try container.encodeIfPresent(amountLamports, forKey: .amountLamports)
        try container.encode(mintAddress, forKey: .mintAddress)
        try container.encode(programID, forKey: .programID)
        try container.encodeIfPresent(feeQuote, forKey: .feeQuote)
        try container.encode(humanReadableSummary, forKey: .humanReadableSummary)
        try container.encodeIfPresent(expectedTransactionPurpose, forKey: .expectedTransactionPurpose)
        try container.encodeIfPresent(expectedMessagePurpose, forKey: .expectedMessagePurpose)
        try container.encode(draftFingerprint, forKey: .draftFingerprint)
        try container.encode(approvalState, forKey: .approvalState)
        try container.encode(bridgeState, forKey: .bridgeState)
        try container.encode(createdAt, forKey: .createdAt)
    }

    static func depositPreview(draft: CloakDepositDraft) -> CloakSignerRequestSummary {
        let fingerprint = Self.fingerprint(
            walletPublicKey: draft.sourceWalletAddress,
            network: draft.network,
            actionKind: .deposit,
            amountLamports: draft.grossLamports,
            mintAddress: draft.mintAddress,
            programID: CloakConstants.programID,
            feeQuote: draft.feeQuote
        )

        return CloakSignerRequestSummary(
            requestKind: .signTransactionPreview,
            walletPublicKey: draft.sourceWalletAddress,
            network: draft.network,
            actionKind: .deposit,
            amountLamports: draft.grossLamports,
            mintAddress: draft.mintAddress,
            feeQuote: draft.feeQuote,
            humanReadableSummary: "Future Cloak SOL deposit review for \(draft.feeQuote.grossSOLText).",
            expectedTransactionPurpose: "Create a reviewed Cloak public deposit into a shielded balance.",
            expectedMessagePurpose: "Future viewing-key registration may require a separately reviewed message signature.",
            draftFingerprint: fingerprint
        )
    }

    static func fingerprint(
        walletPublicKey: String,
        network: WalletNetwork,
        actionKind: CloakActionKind,
        amountLamports: UInt64?,
        mintAddress: String,
        programID: String,
        feeQuote: CloakFeeQuote?
    ) -> String {
        let source = [
            walletPublicKey,
            network.rawValue,
            actionKind.rawValue,
            amountLamports.map(String.init) ?? "nil",
            mintAddress,
            programID,
            feeQuote.map { "\($0.grossLamports):\($0.totalFeeLamports):\($0.netLamports)" } ?? "nil"
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(source.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct CloakSignerPreflightResult: Codable, Equatable {
    let requestID: UUID?
    let state: CloakSignerBridgeState
    let requirements: [CloakSignerApprovalRequirement]
    let failures: [String]
    let message: String
    let createdAt: Date

    var isLocked: Bool { state == .locked }
}

struct CloakSignerBridgeAuditSummary: Codable, Equatable {
    let requestID: UUID
    let requestKind: CloakSignerRequestKind
    let network: WalletNetwork
    let walletPublicKey: String
    let actionKind: CloakActionKind
    let amountLamports: UInt64?
    let mintAddress: String
    let programID: String
    let draftFingerprint: String
    let bridgeState: CloakSignerBridgeState
}

private extension KeyedDecodingContainer {
    func decodeFlexibleOptionalUInt64(forKey key: Key) throws -> UInt64? {
        guard contains(key) else {
            return nil
        }
        if try decodeNil(forKey: key) {
            return nil
        }
        if let value = try? decode(UInt64.self, forKey: key) {
            return value
        }
        if let stringValue = try? decode(String.self, forKey: key) {
            guard let value = UInt64(stringValue) else {
                throw DecodingError.dataCorruptedError(
                    forKey: key,
                    in: self,
                    debugDescription: "Expected UInt64 or base-10 UInt64 string."
                )
            }
            return value
        }
        return nil
    }
}
