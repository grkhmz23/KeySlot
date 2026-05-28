import Foundation

enum WorkstationPDASeedKind: String, Codable, CaseIterable, Identifiable {
    case utf8String = "string_utf8"
    case pubkey
    case rawHex = "raw_hex"
    case bytes
    case u8
    case u16LE = "u16_le"
    case u32LE = "u32_le"
    case u64LE = "u64_le"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .utf8String:
            return "String"
        case .pubkey:
            return "Pubkey"
        case .rawHex:
            return "Raw hex"
        case .bytes:
            return "Bytes"
        case .u8:
            return "u8"
        case .u16LE:
            return "u16 LE"
        case .u32LE:
            return "u32 LE"
        case .u64LE:
            return "u64 LE"
        }
    }
}

struct WorkstationPDASeedInput: Codable, Equatable, Identifiable {
    var id: UUID
    var kind: WorkstationPDASeedKind
    var value: String

    init(id: UUID = UUID(), kind: WorkstationPDASeedKind = .utf8String, value: String = "") {
        self.id = id
        self.kind = kind
        self.value = value
    }
}

enum WorkstationPDASeedError: LocalizedError, Equatable {
    case emptySeed
    case invalidPubkey
    case invalidHex
    case invalidBytes
    case invalidInteger
    case seedTooLong

    var errorDescription: String? {
        switch self {
        case .emptySeed:
            return "Seed value is empty."
        case .invalidPubkey:
            return "Pubkey seed must be a valid Solana public key."
        case .invalidHex:
            return "Raw hex seed must contain an even number of hex characters."
        case .invalidBytes:
            return "Bytes seed must contain comma or space separated byte values from 0 to 255."
        case .invalidInteger:
            return "Integer seed must fit the selected fixed-width type."
        case .seedTooLong:
            return "Each PDA seed must be 32 bytes or shorter."
        }
    }
}

struct WorkstationPDADerivationRequest: Equatable {
    let programID: String
    let seeds: [WorkstationPDASeedInput]
    let expectedAddress: String?
}

struct WorkstationPDADerivationResult: Codable, Equatable {
    let status: WorkstationPDADerivationStatus
    let programID: String?
    let derivedAddress: String?
    let bump: UInt8?
    let expectedAddress: String?
    let seedSummary: String
    let message: String
}

enum WorkstationPDAAccountCheckStatus: String, Codable, Equatable {
    case notRun = "not_run"
    case exists
    case notFound = "not_found"
    case unavailable

    var title: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct WorkstationPDAAccountCheck: Codable, Equatable {
    let status: WorkstationPDAAccountCheckStatus
    let address: String?
    let ownerProgram: String?
    let ownerLabel: String?
    let lamports: UInt64?
    let executable: Bool?
    let dataLength: Int?
    let decodedAccountType: String?
    let message: String
}

struct PDAService {
    private let rpcClient: WorkstationReadOnlyRPCClient

    init(session: URLSession = .shared, configuration: RPCFastConfiguration = RPCFastConfiguration()) {
        rpcClient = WorkstationReadOnlyRPCClient(session: session, configuration: configuration)
    }

    func derive(_ request: WorkstationPDADerivationRequest) -> WorkstationPDADerivationResult {
        let programID = request.programID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SolanaAddressValidator.isValidAddress(programID) else {
            return WorkstationPDADerivationResult(
                status: .missingProgramID,
                programID: nil,
                derivedAddress: nil,
                bump: nil,
                expectedAddress: cleanAddress(request.expectedAddress),
                seedSummary: request.seeds.map(seedSummary).joined(separator: ", "),
                message: "Enter a valid program id before PDA derivation."
            )
        }

        do {
            let seedData = try request.seeds.map(seedData)
            let result = try ProgramDerivedAddress.findProgramAddress(seeds: seedData, programID: programID)
            let expected = cleanAddress(request.expectedAddress)
            let status: WorkstationPDADerivationStatus = expected == nil || expected == result.base58Address ? .derived : .mismatch
            return WorkstationPDADerivationResult(
                status: status,
                programID: programID,
                derivedAddress: result.base58Address,
                bump: result.bump,
                expectedAddress: expected,
                seedSummary: request.seeds.map(seedSummary).joined(separator: ", "),
                message: status == .mismatch
                    ? "Derived PDA does not match the expected account."
                    : "Derived with real Solana PDA hashing and ed25519 off-curve validation."
            )
        } catch {
            return WorkstationPDADerivationResult(
                status: .invalidInput,
                programID: programID,
                derivedAddress: nil,
                bump: nil,
                expectedAddress: cleanAddress(request.expectedAddress),
                seedSummary: request.seeds.map(seedSummary).joined(separator: ", "),
                message: error.localizedDescription
            )
        }
    }

    func checkAccount(address: String, cluster: WorkstationCluster, idl: WorkstationIDL?) async -> WorkstationPDAAccountCheck {
        let cleaned = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SolanaAddressValidator.isValidAddress(cleaned) else {
            return WorkstationPDAAccountCheck(
                status: .unavailable,
                address: nil,
                ownerProgram: nil,
                ownerLabel: nil,
                lamports: nil,
                executable: nil,
                dataLength: nil,
                decodedAccountType: nil,
                message: "Enter or derive a valid PDA address before checking account existence."
            )
        }
        do {
            return try await rpcClient.getAccountInfo(address: cleaned, cluster: cluster, idl: idl)
        } catch {
            return WorkstationPDAAccountCheck(
                status: .unavailable,
                address: cleaned,
                ownerProgram: nil,
                ownerLabel: nil,
                lamports: nil,
                executable: nil,
                dataLength: nil,
                decodedAccountType: nil,
                message: AgentSafetyRedactor.redact(error.localizedDescription)
            )
        }
    }

    static func seedData(from input: WorkstationPDASeedInput) throws -> Data {
        let value = input.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw WorkstationPDASeedError.emptySeed
        }
        let data: Data
        switch input.kind {
        case .utf8String:
            data = Data(value.utf8)
        case .pubkey:
            guard let decoded = SolanaAddressValidator.decodeAddress(value) else {
                throw WorkstationPDASeedError.invalidPubkey
            }
            data = decoded
        case .rawHex:
            data = try parseHex(value)
        case .bytes:
            data = try parseByteList(value)
        case .u8:
            guard let number = UInt8(value) else { throw WorkstationPDASeedError.invalidInteger }
            data = Data([number])
        case .u16LE:
            guard let number = UInt16(value) else { throw WorkstationPDASeedError.invalidInteger }
            data = littleEndian(number)
        case .u32LE:
            guard let number = UInt32(value) else { throw WorkstationPDASeedError.invalidInteger }
            data = littleEndian(number)
        case .u64LE:
            guard let number = UInt64(value) else { throw WorkstationPDASeedError.invalidInteger }
            data = littleEndian(number)
        }
        guard data.count <= 32 else {
            throw WorkstationPDASeedError.seedTooLong
        }
        return data
    }

    private func seedData(_ input: WorkstationPDASeedInput) throws -> Data {
        try Self.seedData(from: input)
    }

    static func seedSummary(_ input: WorkstationPDASeedInput) -> String {
        "\(input.kind.title):\(AgentSafetyRedactor.redact(input.value).prefix(48))"
    }

    private func seedSummary(_ input: WorkstationPDASeedInput) -> String {
        Self.seedSummary(input)
    }

    private func cleanAddress(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              SolanaAddressValidator.isValidAddress(value) else {
            return nil
        }
        return value
    }

    private static func parseHex(_ value: String) throws -> Data {
        let cleaned = value
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
        guard cleaned.count.isMultiple(of: 2), cleaned.range(of: #"^[0-9a-fA-F]*$"#, options: .regularExpression) != nil else {
            throw WorkstationPDASeedError.invalidHex
        }
        var bytes: [UInt8] = []
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else {
                throw WorkstationPDASeedError.invalidHex
            }
            bytes.append(byte)
            index = next
        }
        return Data(bytes)
    }

    private static func parseByteList(_ value: String) throws -> Data {
        let parts = value
            .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
            .map(String.init)
        guard !parts.isEmpty else {
            throw WorkstationPDASeedError.invalidBytes
        }
        let bytes = try parts.map { part -> UInt8 in
            guard let byte = UInt8(part) else {
                throw WorkstationPDASeedError.invalidBytes
            }
            return byte
        }
        return Data(bytes)
    }

    private static func littleEndian<T: FixedWidthInteger>(_ value: T) -> Data {
        var mutable = value.littleEndian
        return withUnsafeBytes(of: &mutable) { Data($0) }
    }
}

struct WorkstationReadOnlyRPCClient {
    private let session: URLSession
    private let configuration: RPCFastConfiguration

    init(session: URLSession, configuration: RPCFastConfiguration) {
        self.session = session
        self.configuration = configuration
    }

    func getAccountInfo(address: String, cluster: WorkstationCluster, idl: WorkstationIDL?) async throws -> WorkstationPDAAccountCheck {
        let result = try await request(
            method: "getAccountInfo",
            params: [
                address,
                [
                    "encoding": "base64",
                    "commitment": "confirmed"
                ]
            ],
            cluster: cluster
        )
        guard let dictionary = result as? [String: Any] else {
            throw SolanaRPCError.invalidResponse
        }
        guard !(dictionary["value"] is NSNull),
              let value = dictionary["value"] as? [String: Any] else {
            return WorkstationPDAAccountCheck(
                status: .notFound,
                address: address,
                ownerProgram: nil,
                ownerLabel: nil,
                lamports: nil,
                executable: nil,
                dataLength: nil,
                decodedAccountType: nil,
                message: "No account exists at this PDA on \(cluster.title)."
            )
        }
        let owner = value["owner"] as? String
        let lamports = uint64Value(value["lamports"])
        let executable = value["executable"] as? Bool
        let dataLength = intValue(value["space"])
        let dataBase64: String?
        if let dataArray = value["data"] as? [Any] {
            dataBase64 = dataArray.first as? String
        } else {
            dataBase64 = nil
        }
        let decodedType: String?
        if let dataBase64, let data = Data(base64Encoded: dataBase64), let idl {
            decodedType = WorkstationAnchorAccountDecoder.matchedAccount(in: idl, data: data)?.name
        } else {
            decodedType = nil
        }
        return WorkstationPDAAccountCheck(
            status: .exists,
            address: address,
            ownerProgram: owner,
            ownerLabel: owner.map(TransactionInstructionLabeler.label(for:)),
            lamports: lamports,
            executable: executable,
            dataLength: dataLength,
            decodedAccountType: decodedType,
            message: "Account exists. Details were fetched with read-only getAccountInfo."
        )
    }

    private func request(method: String, params: [Any], cluster: WorkstationCluster) async throws -> Any {
        guard method == "getAccountInfo" else {
            throw SolanaRPCError.methodBlocked("Developer Workstation PDA checks allow getAccountInfo only.")
        }
        var request = URLRequest(url: cluster.rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let network = cluster.walletNetwork {
            configuration.applyAuthentication(to: &request, network: network)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": UUID().uuidString,
            "method": method,
            "params": params
        ])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SolanaRPCError.transport("Read-only RPC request failed.")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SolanaRPCError.invalidResponse
        }
        if let error = json["error"] as? [String: Any] {
            throw SolanaRPCError.rpc(configuration.redact(error["message"] as? String ?? "RPC error"))
        }
        guard let result = json["result"] else {
            throw SolanaRPCError.invalidResponse
        }
        return result
    }

    private func uint64Value(_ value: Any?) -> UInt64? {
        if let value = value as? UInt64 {
            return value
        }
        if let value = value as? Int, value >= 0 {
            return UInt64(value)
        }
        if let value = value as? NSNumber {
            return value.uint64Value
        }
        if let value = value as? String {
            return UInt64(value)
        }
        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        if let value = value as? String {
            return Int(value)
        }
        return nil
    }
}
