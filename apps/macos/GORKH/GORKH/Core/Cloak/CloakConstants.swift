import Foundation

enum CloakConstants {
    static let programID = "zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW"
    static let nativeSolMint = "So11111111111111111111111111111111111111112"

    static let minimumDepositLamports: UInt64 = 10_000_000
    static let fixedFeeLamports: UInt64 = 5_000_000
    static let variableFeeNumerator: UInt64 = 3
    static let variableFeeDenominator: UInt64 = 1_000

    static let phaseLockMessage = "Cloak execution is locked in Phase 2.0. No SDK transaction is built, signed, or sent."
}
