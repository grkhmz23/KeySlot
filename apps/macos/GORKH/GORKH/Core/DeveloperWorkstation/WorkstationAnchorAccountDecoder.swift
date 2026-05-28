import Foundation

enum WorkstationAnchorAccountDecoder {
    private static let maxStringLength = 4_096
    private static let maxVectorLength = 128
    private static let maxRecursionDepth = 4

    static func matchedAccount(in idl: WorkstationIDL, data: Data) -> WorkstationIDLAccount? {
        guard data.count >= 8 else {
            return nil
        }
        let discriminator = Array(data.prefix(8))
        return idl.accounts.first { account in
            (account.discriminator ?? WorkstationAnchorDiscriminator.account(name: account.name)) == discriminator
        }
    }

    static func decodeFields(account: WorkstationIDLAccount, data: Data, idl: WorkstationIDL? = nil) -> [WorkstationAccountDecodedField] {
        let payload = data.count >= 8 ? data.dropFirst(8) : data[...]
        var cursor = payload.startIndex
        return account.fields.map { field in
            let value = decode(type: field.type, data: payload, cursor: &cursor, idl: idl, depth: 0)
                ?? "Data unavailable for bounded Anchor decode."
            return WorkstationAccountDecodedField(name: field.name, type: field.type, value: value)
        }
    }

    private static func decode(type rawType: String, data: Data.SubSequence, cursor: inout Data.Index, idl: WorkstationIDL?, depth: Int) -> String? {
        guard depth <= maxRecursionDepth else {
            return "Unsupported: nested type depth exceeds safety limit."
        }
        let type = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch type {
        case "bool":
            guard let byte = readBytes(count: 1, data: data, cursor: &cursor).first else { return nil }
            return byte == 0 ? "false" : "true"
        case "u8":
            return readInteger(UInt8.self, data: data, cursor: &cursor).map(String.init)
        case "i8":
            return readInteger(Int8.self, data: data, cursor: &cursor).map(String.init)
        case "u16":
            return readInteger(UInt16.self, data: data, cursor: &cursor).map(String.init)
        case "i16":
            return readInteger(Int16.self, data: data, cursor: &cursor).map(String.init)
        case "u32":
            return readInteger(UInt32.self, data: data, cursor: &cursor).map(String.init)
        case "i32":
            return readInteger(Int32.self, data: data, cursor: &cursor).map(String.init)
        case "u64":
            return readInteger(UInt64.self, data: data, cursor: &cursor).map(String.init)
        case "i64":
            return readInteger(Int64.self, data: data, cursor: &cursor).map(String.init)
        case "string":
            guard let length = readInteger(UInt32.self, data: data, cursor: &cursor),
                  length <= maxStringLength else {
                return nil
            }
            let bytes = readBytes(count: Int(length), data: data, cursor: &cursor)
            guard bytes.count == Int(length), let value = String(data: Data(bytes), encoding: .utf8) else {
                return nil
            }
            return value
        case "publickey", "pubkey":
            let bytes = readBytes(count: 32, data: data, cursor: &cursor)
            guard bytes.count == 32 else {
                return nil
            }
            return Base58.encode(Data(bytes))
        default:
            if type.hasPrefix("vec<"), type.hasSuffix(">") {
                let inner = String(rawType.dropFirst(4).dropLast())
                guard let count = readInteger(UInt32.self, data: data, cursor: &cursor),
                      count <= maxVectorLength else {
                    return "Unsupported: vector length is unavailable or exceeds \(maxVectorLength)."
                }
                var values: [String] = []
                for _ in 0..<count {
                    guard let decoded = decode(type: inner, data: data, cursor: &cursor, idl: idl, depth: depth + 1) else {
                        return "Unsupported: vector element could not be decoded."
                    }
                    guard !decoded.hasPrefix("Unsupported") else {
                        return decoded
                    }
                    values.append(decoded)
                }
                return "[\(values.joined(separator: ", "))]"
            }
            if type.hasPrefix("option<"), type.hasSuffix(">") {
                let inner = String(rawType.dropFirst(7).dropLast())
                guard let flag = readBytes(count: 1, data: data, cursor: &cursor).first else {
                    return nil
                }
                if flag == 0 {
                    return "none"
                }
                guard flag == 1 else {
                    return "Unsupported: invalid option tag \(flag)."
                }
                return decode(type: inner, data: data, cursor: &cursor, idl: idl, depth: depth + 1).map { "some(\($0))" }
            }
            if type.hasPrefix("array<"), type.hasSuffix(">") {
                let body = String(rawType.dropFirst(6).dropLast())
                let parts = splitTopLevel(body)
                guard parts.count == 2,
                      let count = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)),
                      count <= maxVectorLength else {
                    return "Unsupported: fixed array metadata is unavailable or exceeds \(maxVectorLength)."
                }
                var values: [String] = []
                for _ in 0..<count {
                    guard let decoded = decode(type: parts[0], data: data, cursor: &cursor, idl: idl, depth: depth + 1) else {
                        return "Unsupported: array element could not be decoded."
                    }
                    guard !decoded.hasPrefix("Unsupported") else {
                        return decoded
                    }
                    values.append(decoded)
                }
                return "[\(values.joined(separator: ", "))]"
            }
            if let named = idl?.types.first(where: { $0.name.lowercased() == type }) {
                var values: [String] = []
                for field in named.fields {
                    guard let decoded = decode(type: field.type, data: data, cursor: &cursor, idl: idl, depth: depth + 1) else {
                        return "Unsupported: nested struct field could not be decoded."
                    }
                    guard !decoded.hasPrefix("Unsupported") else {
                        return decoded
                    }
                    values.append("\(field.name): \(decoded)")
                }
                return "{\(values.joined(separator: ", "))}"
            }
            return "Unsupported: \(rawType)"
        }
    }

    private static func splitTopLevel(_ value: String) -> [String] {
        var output: [String] = []
        var current = ""
        var depth = 0
        for character in value {
            if character == "<" {
                depth += 1
            } else if character == ">" {
                depth = max(0, depth - 1)
            }
            if character == "," && depth == 0 {
                output.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty {
            output.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }

    private static func readInteger<T: FixedWidthInteger>(
        _ type: T.Type,
        data: Data.SubSequence,
        cursor: inout Data.Index
    ) -> T? {
        let bytes = readBytes(count: MemoryLayout<T>.size, data: data, cursor: &cursor)
        guard bytes.count == MemoryLayout<T>.size else {
            return nil
        }
        let unsigned = bytes.enumerated().reduce(UInt64.zero) { partial, pair in
            partial | (UInt64(pair.element) << UInt64(pair.offset * 8))
        }
        return T(truncatingIfNeeded: unsigned)
    }

    private static func readBytes(count: Int, data: Data.SubSequence, cursor: inout Data.Index) -> [UInt8] {
        guard count >= 0 else {
            return []
        }
        let end = data.index(cursor, offsetBy: count, limitedBy: data.endIndex) ?? data.endIndex
        guard data.distance(from: cursor, to: end) == count else {
            return []
        }
        defer { cursor = end }
        return Array(data[cursor..<end])
    }
}
