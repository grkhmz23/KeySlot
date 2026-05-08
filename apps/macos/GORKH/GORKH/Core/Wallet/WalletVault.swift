import Foundation

struct WalletSecret: Equatable {
    private(set) var seed: Data

    init(seed: Data) throws {
        guard seed.count == 32 else {
            throw WalletVaultError.invalidSecret
        }
        self.seed = seed
    }

    mutating func clear() {
        seed.resetBytes(in: 0..<seed.count)
        seed.removeAll(keepingCapacity: false)
    }
}

protocol WalletVault {
    func saveSecret(_ secret: WalletSecret, for walletID: UUID) throws
    func loadSecret(for walletID: UUID) throws -> WalletSecret
    func deleteSecret(for walletID: UUID) throws
    func containsSecret(for walletID: UUID) -> Bool
}

enum WalletVaultError: LocalizedError, Equatable {
    case invalidSecret
    case missingSecret
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidSecret:
            return "Wallet secret is invalid."
        case .missingSecret:
            return "Wallet secret is missing."
        case .keychainError(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

final class InMemoryWalletVault: WalletVault {
    private var secrets: [UUID: WalletSecret] = [:]

    func saveSecret(_ secret: WalletSecret, for walletID: UUID) throws {
        secrets[walletID] = secret
    }

    func loadSecret(for walletID: UUID) throws -> WalletSecret {
        guard let secret = secrets[walletID] else {
            throw WalletVaultError.missingSecret
        }
        return secret
    }

    func deleteSecret(for walletID: UUID) throws {
        secrets.removeValue(forKey: walletID)
    }

    func containsSecret(for walletID: UUID) -> Bool {
        secrets[walletID] != nil
    }
}
