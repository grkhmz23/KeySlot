import CryptoKit
import Foundation
import Security

// MARK: - Export Recovery Envelope

/// Encrypts the BIP39 recovery phrase so it can only be decrypted with the correct Vault Export Code.
/// Uses AES-GCM for authenticated encryption. The encryption key is derived from the Vault Export Code
/// via HKDF-SHA256 with a unique per-wallet salt.
struct ExportRecoveryEnvelope: Codable, Equatable {
    let version: Int
    let salt: Data
    let nonce: Data
    let ciphertext: Data
    let tag: Data

    static let currentVersion = 1

    enum EnvelopeError: LocalizedError, Equatable {
        case invalidVersion
        case decryptionFailed
        case keyDerivationFailed
        case invalidInput

        var errorDescription: String? {
            switch self {
            case .invalidVersion:
                return "Recovery envelope version is not supported."
            case .decryptionFailed:
                return "Decryption failed. The Vault Export Code may be incorrect."
            case .keyDerivationFailed:
                return "Key derivation from Vault Export Code failed."
            case .invalidInput:
                return "Invalid input for recovery envelope operation."
            }
        }
    }
}

// MARK: - Envelope Encryption / Decryption

enum ExportRecoveryEnvelopeCrypto {
    static func encrypt(mnemonic: String, code: String) throws -> ExportRecoveryEnvelope {
        guard let mnemonicData = mnemonic.data(using: .utf8),
              !mnemonicData.isEmpty else {
            throw ExportRecoveryEnvelope.EnvelopeError.invalidInput
        }

        let salt = try generateSalt()
        let key = try deriveKey(from: code, salt: salt)
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(mnemonicData, using: key, nonce: nonce)

        guard let ciphertext = sealedBox.ciphertext,
              let tag = sealedBox.tag else {
            throw ExportRecoveryEnvelope.EnvelopeError.decryptionFailed
        }

        return ExportRecoveryEnvelope(
            version: ExportRecoveryEnvelope.currentVersion,
            salt: salt,
            nonce: Data(nonce),
            ciphertext: ciphertext,
            tag: tag
        )
    }

    static func decrypt(envelope: ExportRecoveryEnvelope, code: String) throws -> String {
        guard envelope.version == ExportRecoveryEnvelope.currentVersion else {
            throw ExportRecoveryEnvelope.EnvelopeError.invalidVersion
        }

        let key = try deriveKey(from: code, salt: envelope.salt)
        let nonce = try AES.GCM.Nonce(data: envelope.nonce)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: envelope.ciphertext, tag: envelope.tag)
        let decrypted = try AES.GCM.open(sealedBox, using: key)

        guard let mnemonic = String(data: decrypted, encoding: .utf8),
              !mnemonic.isEmpty else {
            throw ExportRecoveryEnvelope.EnvelopeError.decryptionFailed
        }

        return mnemonic
    }

    private static func deriveKey(from code: String, salt: Data) throws -> SymmetricKey {
        let normalized = VaultExportCode.normalize(code)
        guard normalized.count == VaultExportCode.totalLength,
              let codeData = normalized.data(using: .utf8) else {
            throw ExportRecoveryEnvelope.EnvelopeError.keyDerivationFailed
        }

        var saltInput = Data(salt)
        saltInput.append(codeData)
        let prk = HKDF<SHA256>.extract(inputKeyingMaterial: .init(data: codeData), salt: salt)
        let derived = HKDF<SHA256>.expand(pseudoRandomKey: prk, info: Data("keyslot-export-recovery-envelope".utf8), outputByteCount: 32)
        return SymmetricKey(data: derived)
    }

    private static func generateSalt() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw ExportRecoveryEnvelope.EnvelopeError.keyDerivationFailed
        }
        return Data(bytes)
    }
}

// MARK: - Envelope Storage

protocol ExportRecoveryEnvelopeStoring {
    func saveEnvelope(_ envelope: ExportRecoveryEnvelope, for walletID: UUID) throws
    func loadEnvelope(for walletID: UUID) throws -> ExportRecoveryEnvelope?
    func deleteEnvelope(for walletID: UUID) throws
    func containsEnvelope(for walletID: UUID) -> Bool
}

final class KeychainExportRecoveryEnvelopeStore: ExportRecoveryEnvelopeStoring {
    private let service = "foundation.swarp.keyslot.wallet.recovery-envelope"

    func saveEnvelope(_ envelope: ExportRecoveryEnvelope, for walletID: UUID) throws {
        let data = try JSONEncoder().encode(envelope)
        let query = baseQuery(for: walletID)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw WalletVaultError.keychainError(updateStatus)
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw WalletVaultError.keychainError(addStatus)
        }
    }

    func loadEnvelope(for walletID: UUID) throws -> ExportRecoveryEnvelope? {
        var query = baseQuery(for: walletID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw WalletVaultError.keychainError(status)
        }
        guard let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(ExportRecoveryEnvelope.self, from: data)
    }

    func deleteEnvelope(for walletID: UUID) throws {
        let status = SecItemDelete(baseQuery(for: walletID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WalletVaultError.keychainError(status)
        }
    }

    func containsEnvelope(for walletID: UUID) -> Bool {
        var query = baseQuery(for: walletID)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = false
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    private func baseQuery(for walletID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletID.uuidString
        ]
    }
}
