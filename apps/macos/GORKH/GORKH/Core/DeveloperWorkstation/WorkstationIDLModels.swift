import Foundation

struct WorkstationIDL: Codable, Equatable, Identifiable {
    var id: String { name }

    let name: String
    let version: String?
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
}

struct WorkstationIDLAccount: Codable, Equatable, Identifiable {
    var id: String { name }

    let name: String
    let fields: [WorkstationIDLField]
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
