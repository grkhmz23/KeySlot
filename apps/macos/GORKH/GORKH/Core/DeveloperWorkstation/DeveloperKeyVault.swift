import Foundation
import Security

enum DeveloperWalletStatus: String, Codable, Equatable {
    case missing
    case ready
    case deleted
    case error

    var title: String {
        switch self {
        case .missing:
            return "Missing"
        case .ready:
            return "Ready"
        case .deleted:
            return "Deleted"
        case .error:
            return "Error"
        }
    }
}

struct DeveloperWalletMetadata: Codable, Equatable, Identifiable {
    let id: UUID
    let publicAddress: String
    let allowedClusters: [WorkstationCluster]
    let status: DeveloperWalletStatus
    let createdAt: Date

    static let missing = DeveloperWalletMetadata(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000D0A1")!,
        publicAddress: "",
        allowedClusters: [.localnet, .devnet],
        status: .missing,
        createdAt: Date(timeIntervalSince1970: 0)
    )
}

protocol DeveloperKeyVaulting {
    func generateDeveloperWallet(now: Date) throws -> DeveloperWalletMetadata
    func metadata() -> DeveloperWalletMetadata?
    func loadSeed(for id: UUID) throws -> Data
    func deleteDeveloperWallet(id: UUID) throws
    func containsDeveloperWallet(id: UUID) -> Bool
}

final class KeychainDeveloperKeyVault: DeveloperKeyVaulting {
    private let service = "ai.gorkh.developer-workstation"
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
        var item: CFTypeRef?
        let status = SecItemCopyMatching(baseQuery(id: id, returnData: true) as CFDictionary, &item)
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
        let status = SecItemDelete(baseQuery(id: id, returnData: false) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WalletVaultError.keychainError(status)
        }
        cachedMetadata = cachedMetadata?.id == id ? nil : cachedMetadata
    }

    func containsDeveloperWallet(id: UUID) -> Bool {
        SecItemCopyMatching(baseQuery(id: id, returnData: false) as CFDictionary, nil) == errSecSuccess
    }

    private func save(seed: Data, id: UUID) throws {
        let query = baseQuery(id: id, returnData: false)
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

    private func baseQuery(id: UUID, returnData: Bool) -> [String: Any] {
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
    static func write(seed: Data, publicKey: Data, fileManager: FileManager = .default, now: Date = Date()) throws -> WorkstationTemporaryKeypairFile {
        guard seed.count == 32, publicKey.count == 32 else {
            throw WalletVaultError.invalidSecret
        }
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("gorkh-workstation-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("developer-authority.json")
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
