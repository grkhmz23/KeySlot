import Foundation

struct WorkstationAccountDecodeRequest: Equatable {
    let address: String
    let ownerProgram: String?
    let lamports: UInt64?
    let dataBase64: String?
    let idlAccount: WorkstationIDLAccount?
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
        let fields = request.idlAccount.map { account in
            account.fields.map { field in
                WorkstationAccountDecodedField(
                    name: field.name,
                    type: field.type,
                    value: "Decode unavailable in D1 without a reviewed Borsh layout."
                )
            }
        } ?? []

        return WorkstationAccountDecodeResult(
            address: request.address,
            ownerProgram: request.ownerProgram,
            lamports: request.lamports,
            dataLength: data.count,
            status: fields.isEmpty ? .unavailable : .ready,
            fields: fields,
            rawPreview: data.prefix(48).map { String(format: "%02x", $0) }.joined(),
            message: fields.isEmpty
                ? "Account fetched. IDL field decode is unavailable for this account type."
                : "IDL account fields are listed; byte-level decode remains conservative in D1."
        )
    }
}
