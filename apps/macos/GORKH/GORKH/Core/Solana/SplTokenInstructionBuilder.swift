import Foundation

enum SplTokenInstructionBuilder {
    static func transferCheckedInstructionData(amountRaw: UInt64, decimals: UInt8) -> Data {
        var data = Data()
        data.append(12) // TokenInstruction::TransferChecked
        data.append(SolanaTransactionBuilder.littleEndianUInt64(amountRaw))
        data.append(decimals)
        return data
    }

    static func makeTransferCheckedMessage(draft: TokenTransferDraft, recentBlockhash: String) throws -> Data {
        guard draft.tokenProgramKind == .splToken else {
            throw TokenTransferValidationError.unsupportedTokenProgram("Token-2022 sends are detected but not enabled until extension account handling is implemented.")
        }
        guard let recipientTokenAccount = draft.recipientTokenAccount else {
            throw TokenTransferValidationError.associatedTokenAccountCreationUnavailable(draft.ataPlan.message)
        }
        guard let owner = SolanaAddressValidator.decodeAddress(draft.ownerAddress),
              let source = SolanaAddressValidator.decodeAddress(draft.sourceTokenAccount),
              let destination = SolanaAddressValidator.decodeAddress(recipientTokenAccount),
              let mint = SolanaAddressValidator.decodeAddress(draft.mintAddress),
              let tokenProgram = SolanaAddressValidator.decodeAddress(draft.tokenProgramKind.programID) else {
            throw SolanaValidationError.invalidAddress("Token transfer contains an invalid account address.")
        }
        guard let blockhash = Base58.decode(recentBlockhash), blockhash.count == 32 else {
            throw SolanaValidationError.invalidAddress("Latest blockhash is invalid.")
        }

        let instruction = SolanaCompiledInstruction(
            programIDIndex: 4,
            accountIndexes: [1, 3, 2, 0],
            data: transferCheckedInstructionData(amountRaw: draft.amountRaw, decimals: draft.decimals)
        )

        return SolanaTransactionBuilder.makeMessage(
            accountKeys: [owner, source, destination, mint, tokenProgram],
            recentBlockhash: Data(blockhash),
            readonlySignedAccounts: 1,
            readonlyUnsignedAccounts: 2,
            instructions: [instruction]
        )
    }
}
