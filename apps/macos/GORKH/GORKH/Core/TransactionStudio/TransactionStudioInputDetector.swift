import Foundation

enum TransactionStudioInputDetector {
    static let maxRawTransactionBytes = 128_000

    static func detect(_ input: String) throws -> TransactionStudioInput {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw TransactionStudioDecodeError.emptyInput
        }
        if let forbidden = firstForbiddenMatch(in: trimmed) {
            throw TransactionStudioDecodeError.forbiddenField(forbidden)
        }

        if SolanaAddressValidator.decodeAddress(trimmed) != nil {
            return TransactionStudioInput(rawValue: trimmed, kind: .address, encoding: .base58)
        }

        if let decoded = Base58.decode(trimmed) {
            if decoded.count == 64 {
                return TransactionStudioInput(rawValue: trimmed, kind: .signature, encoding: .base58)
            }
            if decoded.count > 64 && decoded.count <= maxRawTransactionBytes {
                return TransactionStudioInput(rawValue: trimmed, kind: .rawTransaction, encoding: .base58)
            }
        }

        if let data = Data(base64Encoded: trimmed), data.count > 64, data.count <= maxRawTransactionBytes {
            return TransactionStudioInput(rawValue: trimmed, kind: .rawTransaction, encoding: .base64)
        }

        throw TransactionStudioDecodeError.unsupportedInput
    }

    static func rawTransactionData(from input: TransactionStudioInput) throws -> Data {
        guard input.kind == .rawTransaction else {
            throw TransactionStudioDecodeError.invalidRawTransaction("Input is not a raw transaction.")
        }
        switch input.encoding {
        case .base64:
            guard let data = Data(base64Encoded: input.rawValue) else {
                throw TransactionStudioDecodeError.invalidRawTransaction("Raw transaction is not valid base64.")
            }
            return data
        case .base58:
            guard let bytes = Base58.decode(input.rawValue) else {
                throw TransactionStudioDecodeError.invalidRawTransaction("Raw transaction is not valid base58.")
            }
            return Data(bytes)
        case .plain, .unknown:
            throw TransactionStudioDecodeError.invalidRawTransaction("Raw transaction encoding is unknown.")
        }
    }

    static func firstForbiddenMatch(in text: String) -> String? {
        let normalized = text.lowercased()
        for forbidden in [
            "mnemonic",
            "seed phrase",
            "privatekey",
            "private key",
            "secretkey",
            "secret key",
            "wallet json",
            "wallet_json",
            "signingseed",
            "signing seed",
            "zerion_api_key",
            "agent token"
        ] where normalized.contains(forbidden) {
            return forbidden
        }
        return nil
    }
}
