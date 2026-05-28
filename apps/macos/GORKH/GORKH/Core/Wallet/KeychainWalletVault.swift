import Foundation
import Security

final class KeychainWalletVault: WalletVault {
    private let service = "foundation.swarp.keyslot.wallet.vault"
    private let legacyService = "ai.gorkh.wallet.vault"

    func saveSecret(_ secret: WalletSecret, for walletID: UUID) throws {
        // Write to new service
        let query = baseQuery(for: walletID, service: service)
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
        // Try new service first
        if let secret = try? loadSecret(from: service, walletID: walletID) {
            return secret
        }
        // Fall back to legacy service
        if let secret = try? loadSecret(from: legacyService, walletID: walletID) {
            return secret
        }
        throw WalletVaultError.missingSecret
    }

    private func loadSecret(from serviceName: String, walletID: UUID) throws -> WalletSecret {
        var query = baseQuery(for: walletID, service: serviceName)
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
        let statusNew = SecItemDelete(baseQuery(for: walletID, service: service) as CFDictionary)
        let statusLegacy = SecItemDelete(baseQuery(for: walletID, service: legacyService) as CFDictionary)
        guard statusNew == errSecSuccess || statusNew == errSecItemNotFound || statusLegacy == errSecSuccess || statusLegacy == errSecItemNotFound else {
            throw WalletVaultError.keychainError(statusNew)
        }
    }

    func containsSecret(for walletID: UUID) -> Bool {
        if containsSecret(in: service, walletID: walletID) {
            return true
        }
        return containsSecret(in: legacyService, walletID: walletID)
    }

    private func containsSecret(in serviceName: String, walletID: UUID) -> Bool {
        var query = baseQuery(for: walletID, service: serviceName)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = false

        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    private func baseQuery(for walletID: UUID, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletID.uuidString
        ]
    }
}
