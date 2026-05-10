import Foundation

struct WorkstationAccountDecodeRequest: Equatable {
    let address: String
    let ownerProgram: String?
    let lamports: UInt64?
    let dataBase64: String?
    let idlAccount: WorkstationIDLAccount?
    let idl: WorkstationIDL?

    init(
        address: String,
        ownerProgram: String?,
        lamports: UInt64?,
        dataBase64: String?,
        idlAccount: WorkstationIDLAccount?,
        idl: WorkstationIDL? = nil
    ) {
        self.address = address
        self.ownerProgram = ownerProgram
        self.lamports = lamports
        self.dataBase64 = dataBase64
        self.idlAccount = idlAccount
        self.idl = idl
    }
}

struct WorkstationAccountDecodedField: Equatable, Identifiable {
    var id: String { "\(name):\(value)" }

    let name: String
    let type: String
    let value: String
}

struct WorkstationAccountDecodeResult: Equatable {
    let address: String
    let ownerProgram: String?
    let lamports: UInt64?
    let dataLength: Int
    let status: WorkstationDataStatus
    let fields: [WorkstationAccountDecodedField]
    let rawPreview: String
    let message: String
}

struct WorkstationAccountDecoder {
    static func decode(_ request: WorkstationAccountDecodeRequest) -> WorkstationAccountDecodeResult {
        let data = request.dataBase64.flatMap { Data(base64Encoded: $0) } ?? Data()
        let matchedAccount = request.idlAccount ?? request.idl.flatMap { WorkstationAnchorAccountDecoder.matchedAccount(in: $0, data: data) }
        let fields = matchedAccount.map { WorkstationAnchorAccountDecoder.decodeFields(account: $0, data: data) } ?? []
        let fullyDecoded = fields.isEmpty == false && fields.allSatisfy { !$0.value.contains("Data unavailable") }

        return WorkstationAccountDecodeResult(
            address: request.address,
            ownerProgram: request.ownerProgram,
            lamports: request.lamports,
            dataLength: data.count,
            status: fields.isEmpty ? .unavailable : .ready,
            fields: fields,
            rawPreview: data.prefix(48).map { String(format: "%02x", $0) }.joined(),
            message: fields.isEmpty
                ? "Account fetched. No IDL account type matched or simple decode is unavailable."
                : (fullyDecoded
                   ? "Anchor discriminator matched and simple primitive fields decoded."
                   : "Anchor account type is known, but complex or incomplete fields remain unavailable.")
        )
    }
}
