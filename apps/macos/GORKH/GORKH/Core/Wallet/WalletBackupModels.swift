import Foundation

// MARK: - Wallet Backup Payload

/// App-native encrypted wallet backup. Never contains plaintext secrets.
struct WalletBackupPayload: Codable, Equatable {
    let schemaVersion: Int
    let productName: String
    let walletPublicAddress: String
    let walletLabel: String
    let derivationPath: String
    let createdAt: Date
    let encryptedRecoveryEnvelope: ExportRecoveryEnvelope
    let compatibilityMetadata: WalletBackupCompatibilityMetadata

    static let currentSchemaVersion = 1
    static let fileExtension = "keyslotwallet"
}

struct WalletBackupCompatibilityMetadata: Codable, Equatable {
    let platform: String
    let appVersion: String?
    let derivationStandard: String
    let curve: String

    static let `default` = WalletBackupCompatibilityMetadata(
        platform: "macOS",
        appVersion: nil,
        derivationStandard: "BIP39 + SLIP-0010 Ed25519",
        curve: "ed25519"
    )
}

// MARK: - Backup Errors

enum WalletBackupError: LocalizedError, Equatable {
    case invalidFile
    case unsupportedSchemaVersion(Int)
    case decryptionFailed
    case authenticationFailed
    case wrongVaultExportCode
    case walletAlreadyExists
    case addressMismatch
    case invalidPayload
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "The backup file is invalid or corrupted."
        case .unsupportedSchemaVersion(let version):
            return "Backup schema version \(version) is not supported."
        case .decryptionFailed:
            return "Backup decryption failed."
        case .authenticationFailed:
            return "Backup authentication failed. The file may have been tampered with."
        case .wrongVaultExportCode:
            return "The Vault Export Code is incorrect."
        case .walletAlreadyExists:
            return "A wallet with this address already exists."
        case .addressMismatch:
            return "The restored wallet address does not match the backup."
        case .invalidPayload:
            return "The backup payload is missing required fields."
        case .writeFailed:
            return "Failed to write backup file."
        }
    }
}

// MARK: - Backup Result

enum WalletBackupRestoreResult: Equatable {
    case success(WalletProfile)
    case wrongCode(remainingAttempts: Int?)
    case locked(remaining: TimeInterval)
    case failed(String)
}
