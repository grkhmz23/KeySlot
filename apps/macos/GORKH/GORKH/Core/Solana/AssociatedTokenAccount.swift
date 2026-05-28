import Foundation

enum AssociatedTokenAccount {
    static func deriveAddress(
        owner: String,
        mint: String,
        tokenProgramKind: TokenProgramKind
    ) throws -> ProgramDerivedAddressResult {
        guard let ownerBytes = SolanaAddressValidator.decodeAddress(owner),
              let mintBytes = SolanaAddressValidator.decodeAddress(mint),
              let tokenProgramBytes = SolanaAddressValidator.decodeAddress(tokenProgramKind.programID) else {
            throw SolanaValidationError.invalidAddress("Associated token account derivation contains an invalid address.")
        }

        return try ProgramDerivedAddress.findProgramAddress(
            seeds: [
                ownerBytes,
                tokenProgramBytes,
                mintBytes
            ],
            programID: SolanaConstants.associatedTokenAccountProgramID
        )
    }

    static func existingPlan(
        recipientOwner: String,
        mint: String,
        tokenProgramKind: TokenProgramKind,
        recipientTokenAccount: String,
        rentExemptLamports: UInt64? = nil
    ) -> AssociatedTokenAccountPlan {
        return AssociatedTokenAccountPlan(
            recipientOwnerAddress: recipientOwner,
            mintAddress: mint,
            tokenProgramKind: tokenProgramKind,
            associatedTokenAddress: recipientTokenAccount,
            recipientTokenAccountExists: true,
            shouldCreateAssociatedTokenAccount: false,
            creationSupported: true,
            rentExemptLamports: rentExemptLamports,
            message: "Recipient token account exists."
        )
    }

    static func missingPlan(
        recipientOwner: String,
        mint: String,
        tokenProgramKind: TokenProgramKind,
        rentExemptLamports: UInt64? = nil
    ) -> AssociatedTokenAccountPlan {
        let derived = try? deriveAddress(
            owner: recipientOwner,
            mint: mint,
            tokenProgramKind: tokenProgramKind
        )

        return AssociatedTokenAccountPlan(
            recipientOwnerAddress: recipientOwner,
            mintAddress: mint,
            tokenProgramKind: tokenProgramKind,
            associatedTokenAddress: derived?.base58Address,
            recipientTokenAccountExists: false,
            shouldCreateAssociatedTokenAccount: true,
            creationSupported: derived != nil && tokenProgramKind == .splToken,
            rentExemptLamports: rentExemptLamports,
            message: derived == nil
                ? "Recipient associated token account is missing, and ATA derivation failed."
                : "Recipient associated token account is missing. KeySlot will create \(derived?.base58Address ?? "the derived ATA") before transferring."
        )
    }
}
