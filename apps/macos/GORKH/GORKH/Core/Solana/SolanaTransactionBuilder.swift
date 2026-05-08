import CryptoKit
import Foundation

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

        var message = Data()
        message.append(1) // required signatures
        message.append(0) // readonly signed accounts
        message.append(1) // readonly unsigned accounts

        let accountKeys = [from, to, systemProgram]
        message.append(shortVector(accountKeys.count))
        accountKeys.forEach { message.append($0) }
        message.append(contentsOf: blockhash)

        message.append(shortVector(1)) // one instruction
        message.append(2) // system program account index
        message.append(shortVector(2))
        message.append(0)
        message.append(1)

        var instructionData = Data()
        instructionData.append(littleEndianUInt32(2)) // SystemInstruction::Transfer
        instructionData.append(littleEndianUInt64(draft.amountLamports))

        message.append(shortVector(instructionData.count))
        message.append(instructionData)

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

    private static func shortVector(_ value: Int) -> Data {
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

    private static func littleEndianUInt32(_ value: UInt32) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: MemoryLayout<UInt32>.size)
    }

    private static func littleEndianUInt64(_ value: UInt64) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: MemoryLayout<UInt64>.size)
    }
}
