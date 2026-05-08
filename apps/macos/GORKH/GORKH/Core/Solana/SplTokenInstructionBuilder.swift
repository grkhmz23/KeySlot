import Foundation

enum SplTokenInstructionBuilder {
    private struct AccountMeta {
        let key: Data
        var isSigner: Bool
        var isWritable: Bool
    }

    private struct CompiledAccounts {
        let keys: [Data]
        let indexByKey: [Data: UInt8]
        let requiredSignatures: UInt8
        let readonlySignedAccounts: UInt8
        let readonlyUnsignedAccounts: UInt8
    }

    static func transferCheckedInstructionData(amountRaw: UInt64, decimals: UInt8) -> Data {
        var data = Data()
        data.append(12) // TokenInstruction::TransferChecked
        data.append(SolanaTransactionBuilder.littleEndianUInt64(amountRaw))
        data.append(decimals)
        return data
    }

    static func createAssociatedTokenAccountInstructionData() -> Data {
        Data() // Associated Token Account Create instruction
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
              let recipientOwner = SolanaAddressValidator.decodeAddress(draft.recipientOwnerAddress),
              let mint = SolanaAddressValidator.decodeAddress(draft.mintAddress),
              let associatedTokenProgram = SolanaAddressValidator.decodeAddress(SolanaConstants.associatedTokenAccountProgramID),
              let systemProgram = SolanaAddressValidator.decodeAddress(SolanaConstants.systemProgramID),
              let tokenProgram = SolanaAddressValidator.decodeAddress(draft.tokenProgramKind.programID) else {
            throw SolanaValidationError.invalidAddress("Token transfer contains an invalid account address.")
        }
        guard let blockhash = Base58.decode(recentBlockhash), blockhash.count == 32 else {
            throw SolanaValidationError.invalidAddress("Latest blockhash is invalid.")
        }

        var accountMetas = [
            AccountMeta(key: owner, isSigner: true, isWritable: true),
            AccountMeta(key: source, isSigner: false, isWritable: true),
            AccountMeta(key: destination, isSigner: false, isWritable: true),
            AccountMeta(key: mint, isSigner: false, isWritable: false),
            AccountMeta(key: tokenProgram, isSigner: false, isWritable: false)
        ]
        if draft.ataPlan.shouldCreateAssociatedTokenAccount {
            accountMetas.append(contentsOf: [
                AccountMeta(key: recipientOwner, isSigner: false, isWritable: false),
                AccountMeta(key: associatedTokenProgram, isSigner: false, isWritable: false),
                AccountMeta(key: systemProgram, isSigner: false, isWritable: false)
            ])
        }
        let metas = compileAccounts(accountMetas)

        var instructions: [SolanaCompiledInstruction] = []
        if draft.ataPlan.shouldCreateAssociatedTokenAccount {
            guard draft.ataPlan.creationSupported else {
                throw TokenTransferValidationError.associatedTokenAccountCreationUnavailable(draft.ataPlan.message)
            }
            instructions.append(SolanaCompiledInstruction(
                programIDIndex: try index(for: associatedTokenProgram, in: metas),
                accountIndexes: [
                    try index(for: owner, in: metas),
                    try index(for: destination, in: metas),
                    try index(for: recipientOwner, in: metas),
                    try index(for: mint, in: metas),
                    try index(for: systemProgram, in: metas),
                    try index(for: tokenProgram, in: metas)
                ],
                data: createAssociatedTokenAccountInstructionData()
            ))
        }

        instructions.append(
            SolanaCompiledInstruction(
                programIDIndex: try index(for: tokenProgram, in: metas),
                accountIndexes: [
                    try index(for: source, in: metas),
                    try index(for: mint, in: metas),
                    try index(for: destination, in: metas),
                    try index(for: owner, in: metas)
                ],
                data: transferCheckedInstructionData(amountRaw: draft.amountRaw, decimals: draft.decimals)
            )
        )

        return SolanaTransactionBuilder.makeMessage(
            accountKeys: metas.keys,
            recentBlockhash: Data(blockhash),
            requiredSignatures: metas.requiredSignatures,
            readonlySignedAccounts: metas.readonlySignedAccounts,
            readonlyUnsignedAccounts: metas.readonlyUnsignedAccounts,
            instructions: instructions
        )
    }

    static func instructionCount(for draft: TokenTransferDraft) -> Int {
        draft.ataPlan.shouldCreateAssociatedTokenAccount ? 2 : 1
    }

    private static func compileAccounts(_ metas: [AccountMeta]) -> CompiledAccounts {
        var merged: [AccountMeta] = []

        for meta in metas {
            if let index = merged.firstIndex(where: { $0.key == meta.key }) {
                merged[index].isSigner = merged[index].isSigner || meta.isSigner
                merged[index].isWritable = merged[index].isWritable || meta.isWritable
            } else {
                merged.append(meta)
            }
        }

        let sorted =
            merged.filter { $0.isSigner && $0.isWritable } +
            merged.filter { $0.isSigner && !$0.isWritable } +
            merged.filter { !$0.isSigner && $0.isWritable } +
            merged.filter { !$0.isSigner && !$0.isWritable }

        var indexByKey: [Data: UInt8] = [:]
        sorted.enumerated().forEach { index, meta in
            indexByKey[meta.key] = UInt8(index)
        }

        return CompiledAccounts(
            keys: sorted.map(\.key),
            indexByKey: indexByKey,
            requiredSignatures: UInt8(sorted.filter(\.isSigner).count),
            readonlySignedAccounts: UInt8(sorted.filter { $0.isSigner && !$0.isWritable }.count),
            readonlyUnsignedAccounts: UInt8(sorted.filter { !$0.isSigner && !$0.isWritable }.count)
        )
    }

    private static func index(for key: Data, in accounts: CompiledAccounts) throws -> UInt8 {
        guard let index = accounts.indexByKey[key] else {
            throw TokenTransferValidationError.invalidTokenAccount("Token transaction account ordering failed.")
        }
        return index
    }
}
