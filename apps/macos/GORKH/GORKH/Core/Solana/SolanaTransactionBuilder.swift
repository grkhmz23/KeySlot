import CryptoKit
import Foundation

struct SolanaCompiledInstruction: Equatable {
    let programIDIndex: UInt8
    let accountIndexes: [UInt8]
    let data: Data
}

struct SolanaInstructionAccountMeta: Equatable {
    let address: String
    let isSigner: Bool
    let isWritable: Bool
}

struct SolanaInstructionProposal: Equatable {
    let programID: String
    let accounts: [SolanaInstructionAccountMeta]
    let data: Data
}

enum SolanaTransactionBuilder {
    static func makeTransferMessage(draft: TransactionDraft, recentBlockhash: String) throws -> Data {
        guard let from = SolanaAddressValidator.decodeAddress(draft.fromAddress) else {
            throw SolanaValidationError.invalidAddress("Sender address is invalid.")
        }
        guard let to = SolanaAddressValidator.decodeAddress(draft.toAddress) else {
            throw SolanaValidationError.invalidAddress("Recipient address is invalid.")
        }
        guard let systemProgram = SolanaAddressValidator.decodeAddress(SolanaConstants.systemProgramID) else {
            throw SolanaValidationError.invalidAddress("System program address is invalid.")
        }
        guard let blockhash = Base58.decode(recentBlockhash), blockhash.count == 32 else {
            throw SolanaValidationError.invalidAddress("Latest blockhash is invalid.")
        }

        var instructionData = Data()
        instructionData.append(littleEndianUInt32(2)) // SystemInstruction::Transfer
        instructionData.append(littleEndianUInt64(draft.amountLamports))

        let instruction = SolanaCompiledInstruction(
            programIDIndex: 2,
            accountIndexes: [0, 1],
            data: instructionData
        )

        return makeMessage(
            accountKeys: [from, to, systemProgram],
            recentBlockhash: Data(blockhash),
            readonlySignedAccounts: 0,
            readonlyUnsignedAccounts: 1,
            instructions: [instruction]
        )
    }

    static func makeMessage(
        accountKeys: [Data],
        recentBlockhash: Data,
        requiredSignatures: UInt8 = 1,
        readonlySignedAccounts: UInt8,
        readonlyUnsignedAccounts: UInt8,
        instructions: [SolanaCompiledInstruction]
    ) -> Data {
        var message = Data()
        message.append(requiredSignatures)
        message.append(readonlySignedAccounts)
        message.append(readonlyUnsignedAccounts)

        message.append(shortVector(accountKeys.count))
        accountKeys.forEach { message.append($0) }
        message.append(recentBlockhash)

        message.append(shortVector(instructions.count))
        instructions.forEach { instruction in
            message.append(instruction.programIDIndex)
            message.append(shortVector(instruction.accountIndexes.count))
            instruction.accountIndexes.forEach { message.append($0) }
            message.append(shortVector(instruction.data.count))
            message.append(instruction.data)
        }

        return message
    }

    static func makeInstructionProposalMessage(
        feePayer: String,
        recentBlockhash: String,
        instructions proposals: [SolanaInstructionProposal]
    ) throws -> Data {
        guard !proposals.isEmpty else {
            throw SolanaValidationError.invalidAddress("At least one instruction is required.")
        }
        guard let blockhash = Base58.decode(recentBlockhash), blockhash.count == 32 else {
            throw SolanaValidationError.invalidAddress("Latest blockhash is invalid.")
        }
        guard SolanaAddressValidator.isValidAddress(feePayer) else {
            throw SolanaValidationError.invalidAddress("Fee payer address is invalid.")
        }

        var metas: [String: (isSigner: Bool, isWritable: Bool, order: Int)] = [
            feePayer: (isSigner: true, isWritable: true, order: 0)
        ]
        var order = 1
        func merge(address: String, isSigner: Bool, isWritable: Bool) throws {
            guard SolanaAddressValidator.isValidAddress(address) else {
                throw SolanaValidationError.invalidAddress("Instruction account address is invalid.")
            }
            if var existing = metas[address] {
                existing.isSigner = existing.isSigner || isSigner
                existing.isWritable = existing.isWritable || isWritable
                metas[address] = existing
            } else {
                metas[address] = (isSigner: isSigner, isWritable: isWritable, order: order)
                order += 1
            }
        }

        for proposal in proposals {
            try merge(address: proposal.programID, isSigner: false, isWritable: false)
            for account in proposal.accounts {
                try merge(address: account.address, isSigner: account.isSigner, isWritable: account.isWritable)
            }
        }

        let sortedKeys = metas
            .sorted { left, right in
                let lhs = accountSortRank(address: left.key, feePayer: feePayer, meta: left.value)
                let rhs = accountSortRank(address: right.key, feePayer: feePayer, meta: right.value)
                if lhs != rhs {
                    return lhs < rhs
                }
                return left.value.order < right.value.order
            }
            .map(\.key)

        guard sortedKeys.count <= Int(UInt8.max) else {
            throw SolanaValidationError.invalidAddress("Instruction account list is too large for a legacy transaction.")
        }

        let keyIndexes = Dictionary(uniqueKeysWithValues: sortedKeys.enumerated().map { ($0.element, UInt8($0.offset)) })
        let compiled = try proposals.map { proposal in
            guard let programIndex = keyIndexes[proposal.programID] else {
                throw SolanaValidationError.invalidAddress("Instruction program ID is missing from account keys.")
            }
            let accountIndexes = try proposal.accounts.map { account -> UInt8 in
                guard let index = keyIndexes[account.address] else {
                    throw SolanaValidationError.invalidAddress("Instruction account is missing from account keys.")
                }
                return index
            }
            return SolanaCompiledInstruction(
                programIDIndex: programIndex,
                accountIndexes: accountIndexes,
                data: proposal.data
            )
        }

        let signerMetas = sortedKeys.compactMap { key -> (String, (isSigner: Bool, isWritable: Bool, order: Int))? in
            guard let meta = metas[key], meta.isSigner else {
                return nil
            }
            return (key, meta)
        }
        let unsignedMetas = sortedKeys.compactMap { key -> (String, (isSigner: Bool, isWritable: Bool, order: Int))? in
            guard let meta = metas[key], !meta.isSigner else {
                return nil
            }
            return (key, meta)
        }
        guard signerMetas.count <= Int(UInt8.max) else {
            throw SolanaValidationError.invalidAddress("Instruction signer list is too large.")
        }

        let accountKeyData = try sortedKeys.map { key -> Data in
            guard let decoded = SolanaAddressValidator.decodeAddress(key) else {
                throw SolanaValidationError.invalidAddress("Instruction account address is invalid.")
            }
            return decoded
        }

        return makeMessage(
            accountKeys: accountKeyData,
            recentBlockhash: Data(blockhash),
            requiredSignatures: UInt8(signerMetas.count),
            readonlySignedAccounts: UInt8(signerMetas.filter { !$0.1.isWritable }.count),
            readonlyUnsignedAccounts: UInt8(unsignedMetas.filter { !$0.1.isWritable }.count),
            instructions: compiled
        )
    }

    static func makeUnsignedTransactionBase64(message: Data) -> String {
        var transaction = Data()
        let requiredSignatures = Int(message.first ?? 1)
        transaction.append(shortVector(requiredSignatures))
        transaction.append(Data(repeating: 0, count: requiredSignatures * 64))
        transaction.append(message)
        return transaction.base64EncodedString()
    }

    static func makeSignedTransactionBase64(message: Data, seed: Data) throws -> String {
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        let signature = try privateKey.signature(for: message)

        var transaction = Data()
        transaction.append(shortVector(1))
        transaction.append(signature)
        transaction.append(message)
        return transaction.base64EncodedString()
    }

    static func makeMessageBase64(message: Data) -> String {
        message.base64EncodedString()
    }

    static func shortVector(_ value: Int) -> Data {
        var remaining = value
        var output = Data()

        repeat {
            var byte = UInt8(remaining & 0x7f)
            remaining >>= 7
            if remaining > 0 {
                byte |= 0x80
            }
            output.append(byte)
        } while remaining > 0

        return output
    }

    static func littleEndianUInt32(_ value: UInt32) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: MemoryLayout<UInt32>.size)
    }

    static func littleEndianUInt64(_ value: UInt64) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: MemoryLayout<UInt64>.size)
    }

    private static func accountSortRank(
        address: String,
        feePayer: String,
        meta: (isSigner: Bool, isWritable: Bool, order: Int)
    ) -> Int {
        if address == feePayer {
            return 0
        }
        switch (meta.isSigner, meta.isWritable) {
        case (true, true):
            return 1
        case (true, false):
            return 2
        case (false, true):
            return 3
        case (false, false):
            return 4
        }
    }
}
