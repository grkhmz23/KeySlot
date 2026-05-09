import Foundation

enum CloakBridgeValidationError: LocalizedError, Equatable {
    case forbiddenField(String)
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .forbiddenField(let key):
            return "Cloak bridge payload contains forbidden field: \(key)."
        case .invalidJSON:
            return "Cloak bridge payload is not valid JSON."
        }
    }
}

enum CloakBridgeContractValidator {
    static let forbiddenFieldTokens = [
        "privatekey",
        "secretkey",
        "signingseed",
        "seedphrase",
        "mnemonic",
        "walletjson",
        "wallet_json",
        "utxoprivatekey",
        "utxo_private_key",
        "fullutxo",
        "note",
        "notesecret",
        "viewingkey",
        "nullifier",
        "nullifiersecret",
        "proofinput",
        "rawtransaction",
        "fullrawtransaction",
        "rawmessage",
        "serializedtransaction",
        "transactionpayload",
        "transactionbytes",
        "messagebytes",
        "rawsignerbytes"
    ]

    static func validate<T: Encodable>(_ value: T) throws {
        let data = try JSONEncoder().encode(value)
        try validate(jsonData: data)
    }

    static func validate(jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw CloakBridgeValidationError.invalidJSON
        }
        try validate(jsonData: data)
    }

    static func validate(jsonData: Data) throws {
        let object = try JSONSerialization.jsonObject(with: jsonData)
        try validateJSONObject(object)
    }

    private static func validateJSONObject(_ object: Any) throws {
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary {
                if isForbiddenField(key) {
                    throw CloakBridgeValidationError.forbiddenField(key)
                }
                try validateJSONObject(value)
            }
            return
        }

        if let array = object as? [Any] {
            for value in array {
                try validateJSONObject(value)
            }
        }
    }

    static func isForbiddenField(_ key: String) -> Bool {
        let normalized = key
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")

        return forbiddenFieldTokens.contains { normalized.contains($0) }
    }
}
