import Foundation

enum WorkstationAnchorAccountDecoder {
    static func matchedAccount(in idl: WorkstationIDL, data: Data) -> WorkstationIDLAccount? {
        guard data.count >= 8 else {
            return nil
        }
        let discriminator = Array(data.prefix(8))
        return idl.accounts.first { account in
            (account.discriminator ?? WorkstationAnchorDiscriminator.account(name: account.name)) == discriminator
        }
    }

    static func decodeFields(account: WorkstationIDLAccount, data: Data) -> [WorkstationAccountDecodedField] {
        let payload = data.count >= 8 ? data.dropFirst(8) : data[...]
        var cursor = payload.startIndex
        return account.fields.map { field in
            let value = decode(type: field.type.lowercased(), data: payload, cursor: &cursor)
                ?? "Data unavailable for simple Borsh primitive decode."
            return WorkstationAccountDecodedField(name: field.name, type: field.type, value: value)
        }
    }

    private static func decode(type: String, data: Data.SubSequence, cursor: inout Data.Index) -> String? {
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
                  length <= 4_096 else {
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
            return nil
        }
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
