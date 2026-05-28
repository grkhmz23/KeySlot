import Foundation

struct WorkstationIDL: Codable, Equatable, Identifiable {
    var id: String { name }

    let name: String
    let version: String?
    let address: String?
    let instructions: [WorkstationIDLInstruction]
    let accounts: [WorkstationIDLAccount]
    let types: [WorkstationIDLNamedType]
    let errors: [WorkstationIDLError]
    let events: [WorkstationIDLNamedType]

    var summary: String {
        "\(instructions.count) instructions, \(accounts.count) accounts, \(types.count) types"
    }
}

struct WorkstationIDLInstruction: Codable, Equatable, Identifiable {
    var id: String { name }

    let name: String
    let accounts: [WorkstationIDLInstructionAccount]
    let args: [WorkstationIDLField]
}

struct WorkstationIDLInstructionAccount: Codable, Equatable, Identifiable {
    var id: String { name }

    let name: String
    let isMut: Bool
    let isSigner: Bool
    let pda: WorkstationIDLPDA?
}

struct WorkstationIDLPDA: Codable, Equatable {
    let seeds: [WorkstationIDLPDASeed]
    let program: String?

    var summary: String {
        let seedSummary = seeds.map(\.summary).joined(separator: ", ")
        if let program, !program.isEmpty {
            return "\(seedSummary) · program \(program)"
        }
        return seedSummary.isEmpty ? "No seed metadata" : seedSummary
    }
}

struct WorkstationIDLPDASeed: Codable, Equatable, Identifiable {
    var id: String { "\(kind):\(path ?? valueSummary ?? constBytes.map { "\($0.count) bytes" } ?? "unknown")" }

    let kind: String
    let path: String?
    let valueSummary: String?
    let constBytes: [UInt8]?

    var summary: String {
        if let path, !path.isEmpty {
            return "\(kind):\(path)"
        }
        if let valueSummary, !valueSummary.isEmpty {
            return "\(kind):\(valueSummary)"
        }
        if let constBytes {
            return "\(kind):\(constBytes.count) bytes"
        }
        return "\(kind):unknown"
    }
}

struct WorkstationIDLAccount: Codable, Equatable, Identifiable {
    var id: String { name }

    let name: String
    let discriminator: [UInt8]?
    let fields: [WorkstationIDLField]

    var discriminatorHex: String {
        (discriminator ?? WorkstationAnchorDiscriminator.account(name: name)).map { String(format: "%02x", $0) }.joined()
    }
}

struct WorkstationIDLNamedType: Codable, Equatable, Identifiable {
    var id: String { name }

    let name: String
    let fields: [WorkstationIDLField]
}

struct WorkstationIDLField: Codable, Equatable, Identifiable {
    var id: String { "\(name):\(type)" }

    let name: String
    let type: String
}

struct WorkstationIDLError: Codable, Equatable, Identifiable {
    var id: String { "\(code):\(name)" }

    let code: Int
    let name: String
    let message: String?
}

enum WorkstationIDLParserError: LocalizedError, Equatable {
    case invalidJSON
    case missingName

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "IDL JSON could not be parsed."
        case .missingName:
            return "IDL is missing a program name."
        }
    }
}

enum WorkstationAnchorDiscriminator {
    static func account(name: String) -> [UInt8] {
        Array(WorkstationToolchainVerifier.sha256Hex(data: Data("account:\(name)".utf8))
            .chunks(of: 2)
            .prefix(8)
            .compactMap { UInt8($0, radix: 16) })
    }
}

private extension String {
    func chunks(of size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            return String(self[start..<end])
        }
    }
}
