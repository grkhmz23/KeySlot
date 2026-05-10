import CryptoKit
import Foundation

enum TransactionDecoder {
    static func decode(input: TransactionStudioInput, network: WalletNetwork) throws -> DecodedTransaction {
        let data = try TransactionStudioInputDetector.rawTransactionData(from: input)
        return try decode(data: data, inputKind: input.kind, fetchedSignature: nil, slot: nil, blockTime: nil, network: network)
    }

    static func decodeFetchedTransaction(
        transactionBase64: String,
        signature: String,
        slot: UInt64?,
        blockTime: Date?,
        loadedWritableAddresses: [String] = [],
        loadedReadonlyAddresses: [String] = [],
        network: WalletNetwork
    ) throws -> DecodedTransaction {
        guard let data = Data(base64Encoded: transactionBase64) else {
            throw TransactionStudioDecodeError.invalidRawTransaction("Fetched transaction payload was not valid base64.")
        }
        return try decode(
            data: data,
            inputKind: .signature,
            fetchedSignature: signature,
            slot: slot,
            blockTime: blockTime,
            loadedWritableAddresses: loadedWritableAddresses,
            loadedReadonlyAddresses: loadedReadonlyAddresses,
            network: network
        )
    }

    static func decode(
        data: Data,
        inputKind: TransactionStudioInputKind,
        fetchedSignature: String?,
        slot: UInt64?,
        blockTime: Date?,
        loadedWritableAddresses: [String] = [],
        loadedReadonlyAddresses: [String] = [],
        network: WalletNetwork
    ) throws -> DecodedTransaction {
        var cursor = 0
        let signatureCount = try readShortVector(data, cursor: &cursor)
        let signatureBytes = signatureCount * 64
        guard cursor + signatureBytes <= data.count else {
            throw TransactionStudioDecodeError.invalidRawTransaction("Transaction is truncated before signatures are complete.")
        }
        var signatures: [String] = []
        for _ in 0..<signatureCount {
            signatures.append(Base58.encode(data.subdata(in: cursor..<(cursor + 64))))
            cursor += 64
        }

        let messageOffset = cursor
        guard cursor < data.count else {
            throw TransactionStudioDecodeError.invalidRawTransaction("Transaction is missing a message.")
        }

        let firstMessageByte = data[cursor]
        let version: String
        if firstMessageByte & 0x80 == 0 {
            version = "legacy"
        } else {
            let versionNumber = Int(firstMessageByte & 0x7f)
            guard versionNumber == 0 else {
                throw TransactionStudioDecodeError.invalidRawTransaction("Unsupported Solana transaction version \(versionNumber).")
            }
            version = "v0"
            cursor += 1
        }

        guard cursor + 3 <= data.count else {
            throw TransactionStudioDecodeError.invalidRawTransaction("Transaction message header is truncated.")
        }
        let requiredSignatures = Int(data[cursor])
        let readonlySigned = Int(data[cursor + 1])
        let readonlyUnsigned = Int(data[cursor + 2])
        cursor += 3

        let accountCount = try readShortVector(data, cursor: &cursor)
        var accountKeys: [String] = []
        for _ in 0..<accountCount {
            guard cursor + 32 <= data.count else {
                throw TransactionStudioDecodeError.invalidRawTransaction("Account key list is truncated.")
            }
            accountKeys.append(Base58.encode(data.subdata(in: cursor..<(cursor + 32))))
            cursor += 32
        }

        guard cursor + 32 <= data.count else {
            throw TransactionStudioDecodeError.invalidRawTransaction("Recent blockhash is truncated.")
        }
        let recentBlockhash = Base58.encode(data.subdata(in: cursor..<(cursor + 32)))
        cursor += 32

        let staticAccountMetas = accountKeys.enumerated().map { index, address in
            let isSigner = index < requiredSignatures
            let isWritable: Bool
            if isSigner {
                isWritable = index < max(0, requiredSignatures - readonlySigned)
            } else {
                isWritable = index < max(0, accountKeys.count - readonlyUnsigned)
            }
            return DecodedAccountMeta(index: index, address: address, isSigner: isSigner, isWritable: isWritable)
        }
        let loadedWritableMetas = loadedWritableAddresses.enumerated().map { offset, address in
            DecodedAccountMeta(index: accountKeys.count + offset, address: address, isSigner: false, isWritable: true)
        }
        let loadedReadonlyMetas = loadedReadonlyAddresses.enumerated().map { offset, address in
            DecodedAccountMeta(index: accountKeys.count + loadedWritableAddresses.count + offset, address: address, isSigner: false, isWritable: false)
        }
        let allAccountMetas = staticAccountMetas + loadedWritableMetas + loadedReadonlyMetas

        let instructionCount = try readShortVector(data, cursor: &cursor)
        var instructions: [DecodedInstruction] = []
        for index in 0..<instructionCount {
            guard cursor < data.count else {
                throw TransactionStudioDecodeError.invalidRawTransaction("Instruction \(index) is truncated.")
            }
            let programIndex = Int(data[cursor])
            cursor += 1
            let accountIndexCount = try readShortVector(data, cursor: &cursor)
            guard cursor + accountIndexCount <= data.count else {
                throw TransactionStudioDecodeError.invalidRawTransaction("Instruction \(index) account index list is truncated.")
            }
            let instructionAccountIndexes = data[cursor..<(cursor + accountIndexCount)].map(Int.init)
            cursor += accountIndexCount
            let instructionDataLength = try readShortVector(data, cursor: &cursor)
            guard cursor + instructionDataLength <= data.count else {
                throw TransactionStudioDecodeError.invalidRawTransaction("Instruction \(index) data is truncated.")
            }
            let instructionData = data.subdata(in: cursor..<(cursor + instructionDataLength))
            cursor += instructionDataLength

            let programID = programIndex < allAccountMetas.count ? allAccountMetas[programIndex].address : "Address lookup table program"
            let label = TransactionInstructionLabeler.label(for: programID)
            let accounts = instructionAccountIndexes.compactMap { accountIndex -> DecodedAccountMeta? in
                guard accountIndex < allAccountMetas.count else {
                    return nil
                }
                return allAccountMetas[accountIndex]
            }
            let parsed = TransactionInstructionParser.parse(
                programID: programID,
                programLabel: label,
                accounts: accounts,
                data: instructionData
            )
            instructions.append(DecodedInstruction(
                index: index,
                programID: programID,
                programLabel: label,
                accounts: accounts,
                dataLength: instructionDataLength,
                decodedAction: parsed.action,
                riskHints: parsed.riskHints,
                parseStatus: parsed.status,
                parsedSummary: parsed
            ))
        }

        var addressLookupTables: [AddressLookupTableSummary] = []
        if version == "v0" {
            var loadedWritableOffset = 0
            var loadedReadonlyOffset = 0
            let lookupCount = try readShortVector(data, cursor: &cursor)
            for _ in 0..<lookupCount {
                guard cursor + 32 <= data.count else {
                    throw TransactionStudioDecodeError.invalidRawTransaction("Address lookup table reference is truncated.")
                }
                let tableAddress = Base58.encode(data.subdata(in: cursor..<(cursor + 32)))
                cursor += 32
                let writableCount = try readShortVector(data, cursor: &cursor)
                guard cursor + writableCount <= data.count else {
                    throw TransactionStudioDecodeError.invalidRawTransaction("Address lookup table writable indexes are truncated.")
                }
                let writableIndexes = data[cursor..<(cursor + writableCount)].map(Int.init)
                cursor += writableCount
                let readonlyCount = try readShortVector(data, cursor: &cursor)
                guard cursor + readonlyCount <= data.count else {
                    throw TransactionStudioDecodeError.invalidRawTransaction("Address lookup table readonly indexes are truncated.")
                }
                let readonlyIndexes = data[cursor..<(cursor + readonlyCount)].map(Int.init)
                cursor += readonlyCount
                let tableLoadedWritable = Array(loadedWritableAddresses.dropFirst(loadedWritableOffset).prefix(writableCount))
                let tableLoadedReadonly = Array(loadedReadonlyAddresses.dropFirst(loadedReadonlyOffset).prefix(readonlyCount))
                loadedWritableOffset += writableCount
                loadedReadonlyOffset += readonlyCount
                let hasLoadedAddresses = tableLoadedWritable.isEmpty == false || tableLoadedReadonly.isEmpty == false
                addressLookupTables.append(AddressLookupTableSummary(
                    tableAddress: tableAddress,
                    writableIndexCount: writableCount,
                    readonlyIndexCount: readonlyCount,
                    writableIndexes: writableIndexes,
                    readonlyIndexes: readonlyIndexes,
                    loadedWritableAddresses: tableLoadedWritable,
                    loadedReadonlyAddresses: tableLoadedReadonly,
                    resolutionStatus: hasLoadedAddresses ? .loaded : .unresolved,
                    resolutionReason: hasLoadedAddresses ? nil : "Loaded ALT addresses were not present in this transaction source."
                ))
            }
        }

        let groupedPrograms = Dictionary(grouping: instructions, by: \.programID)
        let programSummaries = groupedPrograms.map { programID, instructions in
            ProgramSummary(
                programID: programID,
                label: TransactionInstructionLabeler.label(for: programID),
                instructionCount: instructions.count
            )
        }.sorted { $0.label < $1.label }
        let addressLookupOverview = TransactionAddressLookupOverview(
            tableCount: addressLookupTables.count,
            loadedWritableCount: loadedWritableAddresses.count,
            loadedReadonlyCount: loadedReadonlyAddresses.count,
            unresolvedTableCount: addressLookupTables.filter { $0.resolutionStatus != .loaded }.count
        )

        let messageData = data.subdata(in: messageOffset..<data.count)
        return DecodedTransaction(
            inputKind: inputKind,
            network: network,
            transactionVersion: version,
            signatureCount: signatureCount,
            signatures: signatures,
            feePayer: staticAccountMetas.first?.address,
            recentBlockhash: recentBlockhash,
            staticAccountCount: staticAccountMetas.count,
            accountMetas: allAccountMetas,
            instructions: instructions,
            programSummaries: programSummaries,
            signerSummaries: staticAccountMetas.filter(\.isSigner).map { SignerSummary(address: $0.address, isFeePayer: $0.index == 0) },
            writableAccounts: allAccountMetas.filter(\.isWritable).map { WritableAccountSummary(address: $0.address, isSigner: $0.isSigner) },
            addressLookupTables: addressLookupTables,
            addressLookupOverview: addressLookupOverview,
            feeSummary: TransactionFeeSummary(requiredSignatureCount: requiredSignatures, estimatedFeeLamports: nil),
            messageBase64: messageData.base64EncodedString(),
            simulationTransactionBase64: data.base64EncodedString(),
            fetchedSignature: fetchedSignature,
            slot: slot,
            blockTime: blockTime,
            fingerprint: fingerprint(data),
            decodedAt: Date()
        )
    }

    private static func readShortVector(_ data: Data, cursor: inout Int) throws -> Int {
        var result = 0
        var shift = 0
        while true {
            guard cursor < data.count, shift <= 28 else {
                throw TransactionStudioDecodeError.invalidRawTransaction("Transaction contains an invalid compact vector.")
            }
            let byte = data[cursor]
            cursor += 1
            result |= Int(byte & 0x7f) << shift
            if byte & 0x80 == 0 {
                return result
            }
            shift += 7
        }
    }

    private static func fingerprint(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.prefix(10).map { String(format: "%02x", $0) }.joined()
    }
}
