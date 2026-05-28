import Foundation
import Security

struct DeveloperWalletMetadata: Codable, Equatable {
    let id: UUID
    let publicAddress: String
    let allowedClusters: [WalletNetwork]
    let status: DeveloperWalletStatus
    let createdAt: Date
}

enum DeveloperWalletStatus: String, Codable, Equatable {
    case ready
    case revoked
    case missing
}

protocol DeveloperKeyVaulting {
    func generateDeveloperWallet(now: Date) throws -> DeveloperWalletMetadata
    func metadata() -> DeveloperWalletMetadata?
    func loadSeed(for id: UUID) throws -> Data
    func deleteDeveloperWallet(id: UUID) throws
    func containsDeveloperWallet(id: UUID) -> Bool
}

final class KeychainDeveloperKeyVault: DeveloperKeyVaulting {
    private let service = "foundation.swarp.keyslot.developer-workstation"
    private let legacyService = "ai.gorkh.developer-workstation"
    private var cachedMetadata: DeveloperWalletMetadata?

    func generateDeveloperWallet(now: Date = Date()) throws -> DeveloperWalletMetadata {
        let keypair = try SolanaKeypair.generate()
        let metadata = DeveloperWalletMetadata(
            id: UUID(),
            publicAddress: keypair.publicAddress,
            allowedClusters: [.localnet, .devnet],
            status: .ready,
            createdAt: now
        )
        try save(seed: keypair.seed, id: metadata.id)
        cachedMetadata = metadata
        return metadata
    }

    func metadata() -> DeveloperWalletMetadata? {
        cachedMetadata
    }

    func loadSeed(for id: UUID) throws -> Data {
        // Try new service first
        if let seed = try? loadSeed(from: service, id: id) {
            return seed
        }
        // Fall back to legacy service
        if let seed = try? loadSeed(from: legacyService, id: id) {
            return seed
        }
        throw WalletVaultError.missingSecret
    }

    private func loadSeed(from serviceName: String, id: UUID) throws -> Data {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(baseQuery(id: id, service: serviceName, returnData: true) as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw WalletVaultError.missingSecret
        }
        guard status == errSecSuccess else {
            throw WalletVaultError.keychainError(status)
        }
        guard let data = item as? Data, data.count == 32 else {
            throw WalletVaultError.invalidSecret
        }
        return data
    }

    func deleteDeveloperWallet(id: UUID) throws {
        let statusNew = SecItemDelete(baseQuery(id: id, service: service, returnData: false) as CFDictionary)
        let statusLegacy = SecItemDelete(baseQuery(id: id, service: legacyService, returnData: false) as CFDictionary)
        guard statusNew == errSecSuccess || statusNew == errSecItemNotFound || statusLegacy == errSecSuccess || statusLegacy == errSecItemNotFound else {
            throw WalletVaultError.keychainError(statusNew)
        }
        cachedMetadata = cachedMetadata?.id == id ? nil : cachedMetadata
    }

    func containsDeveloperWallet(id: UUID) -> Bool {
        if containsDeveloperWallet(in: service, id: id) {
            return true
        }
        return containsDeveloperWallet(in: legacyService, id: id)
    }

    private func containsDeveloperWallet(in serviceName: String, id: UUID) -> Bool {
        SecItemCopyMatching(baseQuery(id: id, service: serviceName, returnData: false) as CFDictionary, nil) == errSecSuccess
    }

    private func save(seed: Data, id: UUID) throws {
        let query = baseQuery(id: id, service: service, returnData: false)
        let attributes: [String: Any] = [kSecValueData as String: seed]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw WalletVaultError.keychainError(updateStatus)
        }
        var addQuery = query
        addQuery[kSecValueData as String] = seed
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw WalletVaultError.keychainError(addStatus)
        }
    }

    private func baseQuery(id: UUID, service: String, returnData: Bool) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: returnData,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
    }
}

final class InMemoryDeveloperKeyVault: DeveloperKeyVaulting {
    private var records: [UUID: (metadata: DeveloperWalletMetadata, seed: Data)] = [:]

    func generateDeveloperWallet(now: Date = Date()) throws -> DeveloperWalletMetadata {
        let keypair = try SolanaKeypair.generate()
        let metadata = DeveloperWalletMetadata(
            id: UUID(),
            publicAddress: keypair.publicAddress,
            allowedClusters: [.localnet, .devnet],
            status: .ready,
            createdAt: now
        )
        records[metadata.id] = (metadata, keypair.seed)
        return metadata
    }

    func metadata() -> DeveloperWalletMetadata? {
        records.values.first?.metadata
    }

    func loadSeed(for id: UUID) throws -> Data {
        guard let record = records[id] else {
            throw WalletVaultError.missingSecret
        }
        return record.seed
    }

    func deleteDeveloperWallet(id: UUID) throws {
        records.removeValue(forKey: id)
    }

    func containsDeveloperWallet(id: UUID) -> Bool {
        records[id] != nil
    }
}

struct WorkstationTemporaryKeypairFile: Equatable {
    let url: URL
    let createdAt: Date
}

enum WorkstationTemporaryKeypairFilePolicy {
    static let directoryPrefix = "keyslot-workstation-"
    static let fileName = "developer-authority.json"

    static func write(seed: Data, publicKey: Data, fileManager: FileManager = .default, now: Date = Date()) throws -> WorkstationTemporaryKeypairFile {
        guard seed.count == 32, publicKey.count == 32 else {
            throw WalletVaultError.invalidSecret
        }
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("\(directoryPrefix)\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        let bytes = Array(seed + publicKey)
        let data = try JSONSerialization.data(withJSONObject: bytes)
        try data.write(to: url, options: [.atomic])
        try fileManager.setAttributes([.posixPermissions: NSNumber(value: Int16(0o600))], ofItemAtPath: url.path)
        return WorkstationTemporaryKeypairFile(url: url, createdAt: now)
    }

    static func delete(_ temporaryFile: WorkstationTemporaryKeypairFile, fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: temporaryFile.url.deletingLastPathComponent())
    }

    static func redactedPath(_ temporaryFile: WorkstationTemporaryKeypairFile) -> String {
        temporaryFile.url.deletingLastPathComponent().appendingPathComponent("[redacted-developer-authority].json").path
    }
}
