import Foundation
import Security

final class KeychainWalletVault: WalletVault {
    private let service = "ai.gorkh.wallet.vault"

    func saveSecret(_ secret: WalletSecret, for walletID: UUID) throws {
        let query = baseQuery(for: walletID)
        let attributes: [String: Any] = [
            kSecValueData as String: secret.seed,
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

    func loadSecret(for walletID: UUID) throws -> WalletSecret {
        var query = baseQuery(for: walletID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw WalletVaultError.missingSecret
        }
        guard status == errSecSuccess else {
            throw WalletVaultError.keychainError(status)
        }
        guard let data = item as? Data else {
            throw WalletVaultError.invalidSecret
        }

        return try WalletSecret(seed: data)
    }

    func deleteSecret(for walletID: UUID) throws {
        let status = SecItemDelete(baseQuery(for: walletID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WalletVaultError.keychainError(status)
        }
    }

    func containsSecret(for walletID: UUID) -> Bool {
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
