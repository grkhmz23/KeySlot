import Foundation

struct WorkstationIDLParser {
    static func parse(data: Data) throws -> WorkstationIDL {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WorkstationIDLParserError.invalidJSON
        }
        guard let name = object["name"] as? String, !name.isEmpty else {
            throw WorkstationIDLParserError.missingName
        }

        let instructions = (object["instructions"] as? [[String: Any]] ?? []).map(parseInstruction)
        let accounts = (object["accounts"] as? [[String: Any]] ?? []).map(parseAccount)
        let types = (object["types"] as? [[String: Any]] ?? []).map(parseNamedType)
        let events = (object["events"] as? [[String: Any]] ?? []).map(parseNamedType)
        let errors = (object["errors"] as? [[String: Any]] ?? []).map(parseError)

        return WorkstationIDL(
            name: name,
            version: object["version"] as? String,
            instructions: instructions,
            accounts: accounts,
            types: types,
            errors: errors,
            events: events
        )
    }

    static func parse(string: String) throws -> WorkstationIDL {
        try parse(data: Data(string.utf8))
    }

    private static func parseInstruction(_ object: [String: Any]) -> WorkstationIDLInstruction {
        WorkstationIDLInstruction(
            name: object["name"] as? String ?? "unknown",
            accounts: (object["accounts"] as? [[String: Any]] ?? []).map(parseInstructionAccount),
            args: (object["args"] as? [[String: Any]] ?? []).map(parseField)
        )
    }

    private static func parseInstructionAccount(_ object: [String: Any]) -> WorkstationIDLInstructionAccount {
        WorkstationIDLInstructionAccount(
            name: object["name"] as? String ?? "unknown",
            isMut: object["isMut"] as? Bool ?? object["writable"] as? Bool ?? false,
            isSigner: object["isSigner"] as? Bool ?? object["signer"] as? Bool ?? false
        )
    }

    private static func parseAccount(_ object: [String: Any]) -> WorkstationIDLAccount {
        let type = object["type"] as? [String: Any]
        return WorkstationIDLAccount(
            name: object["name"] as? String ?? "unknown",
            discriminator: parseDiscriminator(object["discriminator"]),
            fields: (type?["fields"] as? [[String: Any]] ?? object["fields"] as? [[String: Any]] ?? []).map(parseField)
        )
    }

    private static func parseNamedType(_ object: [String: Any]) -> WorkstationIDLNamedType {
        let type = object["type"] as? [String: Any]
        return WorkstationIDLNamedType(
            name: object["name"] as? String ?? "unknown",
            fields: (type?["fields"] as? [[String: Any]] ?? object["fields"] as? [[String: Any]] ?? []).map(parseField)
        )
    }

    private static func parseField(_ object: [String: Any]) -> WorkstationIDLField {
        WorkstationIDLField(
            name: object["name"] as? String ?? "unknown",
            type: stringifyType(object["type"] ?? "unknown")
        )
    }

    private static func parseError(_ object: [String: Any]) -> WorkstationIDLError {
        WorkstationIDLError(
            code: object["code"] as? Int ?? -1,
            name: object["name"] as? String ?? "unknown",
            message: object["msg"] as? String ?? object["message"] as? String
        )
    }

    private static func stringifyType(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let array = value as? [Any] {
            return array.map(stringifyType).joined(separator: ", ")
        }
        if let dictionary = value as? [String: Any] {
            if let defined = dictionary["defined"] as? String {
                return defined
            }
            if let option = dictionary["option"] {
                return "option<\(stringifyType(option))>"
            }
            if let vector = dictionary["vec"] {
                return "vec<\(stringifyType(vector))>"
            }
            if let array = dictionary["array"] as? [Any] {
                return "array<\(array.map(stringifyType).joined(separator: ", "))>"
            }
            return dictionary.keys.sorted().joined(separator: "|")
        }
        return String(describing: value)
    }

    private static func parseDiscriminator(_ value: Any?) -> [UInt8]? {
        guard let values = value as? [Any] else {
            return nil
        }
        let bytes = values.compactMap { entry -> UInt8? in
            if let int = entry as? Int, int >= 0, int <= 255 {
                return UInt8(int)
            }
            return nil
        }
        return bytes.count == values.count ? bytes : nil
    }
}
