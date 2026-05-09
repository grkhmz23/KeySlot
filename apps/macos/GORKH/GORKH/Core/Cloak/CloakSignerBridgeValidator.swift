import Foundation

enum CloakSignerBridgeValidationError: LocalizedError, Equatable {
    case forbiddenField(String)
    case programIDMismatch
    case unsupportedNetwork(WalletNetwork)
    case amountMissing
    case amountBelowMinimum(UInt64)
    case unsupportedAction(CloakActionKind)
    case missingDraftFingerprint
    case walletPublicKeyMismatch
    case executablePayloadForbidden(String)

    var errorDescription: String? {
        switch self {
        case .forbiddenField(let key):
            return "Signer request contains forbidden field: \(key)."
        case .programIDMismatch:
            return "Signer request program id does not match the Cloak program id."
        case .unsupportedNetwork(let network):
            return "Cloak signer bridge supports future execution review on mainnet only, not \(network.displayName)."
        case .amountMissing:
            return "Signer request amount is missing."
        case .amountBelowMinimum(let amount):
            return "Signer request amount \(amount) is below the Cloak minimum deposit."
        case .unsupportedAction(let action):
            return "Signer request action is not supported in Phase 2.4: \(action.title)."
        case .missingDraftFingerprint:
            return "Signer request draft fingerprint is missing."
        case .walletPublicKeyMismatch:
            return "Signer request wallet public key does not match the selected wallet."
        case .executablePayloadForbidden(let key):
            return "Signer request attempted to carry executable payload field: \(key)."
        }
    }
}

enum CloakSignerBridgeValidator {
    private static let executablePayloadTokens = [
        "rawtransaction",
        "fullrawtransaction",
        "serializedtransaction",
        "transactionpayload",
        "transactionbytes",
        "messagebytes",
        "rawmessage"
    ]

    static func validate(
        _ request: CloakSignerRequestSummary,
        expectedWalletPublicKey: String? = nil
    ) throws {
        do {
            try CloakBridgeContractValidator.validate(request)
        } catch CloakBridgeValidationError.forbiddenField(let key) {
            throw CloakSignerBridgeValidationError.forbiddenField(key)
        }

        guard request.programID == CloakConstants.programID else {
            throw CloakSignerBridgeValidationError.programIDMismatch
        }
        guard request.network.isMainnet else {
            throw CloakSignerBridgeValidationError.unsupportedNetwork(request.network)
        }
        guard request.actionKind == .deposit || request.actionKind == .fullWithdraw else {
            throw CloakSignerBridgeValidationError.unsupportedAction(request.actionKind)
        }
        guard let amountLamports = request.amountLamports else {
            throw CloakSignerBridgeValidationError.amountMissing
        }
        guard amountLamports >= CloakConstants.minimumDepositLamports else {
            throw CloakSignerBridgeValidationError.amountBelowMinimum(amountLamports)
        }
        guard !request.draftFingerprint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CloakSignerBridgeValidationError.missingDraftFingerprint
        }
        if let expectedWalletPublicKey,
           expectedWalletPublicKey != request.walletPublicKey {
            throw CloakSignerBridgeValidationError.walletPublicKeyMismatch
        }

        let encoded = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: encoded)
        try rejectExecutablePayloadFields(object)
    }

    private static func rejectExecutablePayloadFields(_ object: Any) throws {
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary {
                let normalized = key
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "_", with: "")
                if executablePayloadTokens.contains(where: { normalized.contains($0) }) {
                    throw CloakSignerBridgeValidationError.executablePayloadForbidden(key)
                }
                try rejectExecutablePayloadFields(value)
            }
            return
        }
        if let array = object as? [Any] {
            for value in array {
                try rejectExecutablePayloadFields(value)
            }
        }
    }
}
