import Foundation

enum TransactionStudioSmokeFixture {
    static let publicAddress = SolanaConstants.systemProgramID
    static let invalidSignature = "not-a-solana-signature"
    static let invalidAddress = "not-a-solana-address"
    static let rawTransactionEnvironmentName = "GORKH_TX_STUDIO_RAW_TX_BASE64"
    static let signatureEnvironmentName = "GORKH_TX_STUDIO_SMOKE_SIGNATURE"
    static let splSignatureEnvironmentName = "GORKH_TX_STUDIO_SPL_SIGNATURE"
    static let jupiterSignatureEnvironmentName = "GORKH_TX_STUDIO_JUPITER_SIGNATURE"
    static let failedSignatureEnvironmentName = "GORKH_TX_STUDIO_FAILED_SIGNATURE"
}
