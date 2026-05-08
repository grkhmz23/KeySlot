import CryptoKit
import Foundation

struct SolanaCompiledInstruction: Equatable {
    let programIDIndex: UInt8
    let accountIndexes: [UInt8]
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
        readonlySignedAccounts: UInt8,
        readonlyUnsignedAccounts: UInt8,
        instructions: [SolanaCompiledInstruction]
    ) -> Data {
        var message = Data()
        message.append(1) // required signatures; GORKH Phase 1 signing is single-owner only.
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

    static func makeUnsignedTransactionBase64(message: Data) -> String {
        var transaction = Data()
        transaction.append(shortVector(1))
        transaction.append(Data(repeating: 0, count: 64))
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
}
