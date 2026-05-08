import Foundation

enum AssociatedTokenAccount {
    static func existingPlan(
        recipientOwner: String,
        mint: String,
        tokenProgramKind: TokenProgramKind,
        recipientTokenAccount: String,
        rentExemptLamports: UInt64? = nil
    ) -> AssociatedTokenAccountPlan {
        AssociatedTokenAccountPlan(
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
        AssociatedTokenAccountPlan(
            recipientOwnerAddress: recipientOwner,
            mintAddress: mint,
            tokenProgramKind: tokenProgramKind,
            associatedTokenAddress: nil,
            recipientTokenAccountExists: false,
            shouldCreateAssociatedTokenAccount: true,
            creationSupported: false,
            rentExemptLamports: rentExemptLamports,
            message: "Recipient associated token account is missing. Creation is visible in the plan, but automatic ATA creation is deferred until PDA derivation is implemented without unsafe assumptions."
        )
    }
}
