import Foundation
import Security

enum CloakPrivateVaultError: LocalizedError, Equatable {
    case storageLockedInPhase20
    case missingPrivateState
    case invalidPrivateState
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .storageLockedInPhase20:
            return "Cloak private data storage is locked in Phase 2.4."
        case .missingPrivateState:
            return "Cloak private state is missing from the local vault."
        case .invalidPrivateState:
            return "Cloak private state is invalid."
        case .keychainError(let status):
            return "Cloak private vault Keychain operation failed with status \(status)."
        }
    }
}

protocol CloakPrivateVault {
    func status(for walletID: UUID?) -> CloakVaultStatus
    func storeReference(kind: CloakSecretKind, referenceID: String, for walletID: UUID) throws
    func storeDepositState(
        _ state: Data,
        viewingState: Data?,
        metadata: CloakPrivateRecordMetadata
    ) throws
    func loadSpendState(recordID: UUID, walletID: UUID) throws -> Data
    func loadScanState(walletID: UUID) throws -> Data
    func records(for walletID: UUID?) -> [CloakPrivateRecordMetadata]
    func unspentRecords(for walletID: UUID?) -> [CloakPrivateRecordMetadata]
    func markSpent(recordID: UUID, walletID: UUID, signature: String?) throws -> CloakPrivateRecordMetadata
    func clearPrivateData(for walletID: UUID) throws
}

struct CloakPrivateVaultStatusOnly: CloakPrivateVault {
    func status(for walletID: UUID?) -> CloakVaultStatus {
        .statusOnly(walletID: walletID)
    }

    func storeReference(kind: CloakSecretKind, referenceID: String, for walletID: UUID) throws {
        throw CloakPrivateVaultError.storageLockedInPhase20
    }

    func storeDepositState(
        _ state: Data,
        viewingState: Data?,
        metadata: CloakPrivateRecordMetadata
    ) throws {
        throw CloakPrivateVaultError.storageLockedInPhase20
    }

    func loadSpendState(recordID: UUID, walletID: UUID) throws -> Data {
        throw CloakPrivateVaultError.storageLockedInPhase20
    }

    func loadScanState(walletID: UUID) throws -> Data {
        throw CloakPrivateVaultError.storageLockedInPhase20
    }

    func records(for walletID: UUID?) -> [CloakPrivateRecordMetadata] {
        []
    }

    func unspentRecords(for walletID: UUID?) -> [CloakPrivateRecordMetadata] {
        []
    }

    func markSpent(recordID: UUID, walletID: UUID, signature: String?) throws -> CloakPrivateRecordMetadata {
        throw CloakPrivateVaultError.storageLockedInPhase20
    }

    func clearPrivateData(for walletID: UUID) throws {
        throw CloakPrivateVaultError.storageLockedInPhase20
    }
}

final class KeychainCloakPrivateVault: CloakPrivateVault {
    private let service = "ai.gorkh.cloak.private.vault"
    private let metadataStore: CloakPrivateMetadataStore

    init(metadataStore: CloakPrivateMetadataStore = CloakPrivateMetadataStore()) {
        self.metadataStore = metadataStore
    }

    func status(for walletID: UUID?) -> CloakVaultStatus {
        let records = records(for: walletID)
        var kinds: [CloakSecretKind] = records.isEmpty ? [] : [.encryptedUtxoReference]
        if let walletID, records.contains(where: { (try? load(account: account(walletID: walletID, recordID: $0.id, suffix: "view"))) != nil }) {
            kinds.append(.viewingKeyReference)
        }
        return CloakVaultStatus(
            walletID: walletID,
            privateWalletStatus: records.isEmpty ? .readyForFutureStorage : .ready,
            availableReferenceKinds: kinds,
            storageDescription: records.isEmpty
                ? "Cloak private vault is ready. Secret UTXO state will be stored in Keychain only after an approved mainnet Shield SOL transaction."
                : "Cloak private state is stored in Keychain. Safe metadata is stored locally for activity display.",
            canClearPrivateData: walletID != nil && !records.isEmpty
        )
    }

    func storeReference(kind: CloakSecretKind, referenceID: String, for walletID: UUID) throws {
        _ = kind
        _ = referenceID
        _ = walletID
    }

    func storeDepositState(
        _ state: Data,
        viewingState: Data?,
        metadata: CloakPrivateRecordMetadata
    ) throws {
        guard !state.isEmpty else {
            throw CloakPrivateVaultError.invalidPrivateState
        }
        try save(data: state, account: account(walletID: metadata.walletID, recordID: metadata.id, suffix: "spend"))
        if let viewingState, !viewingState.isEmpty {
            try save(data: viewingState, account: account(walletID: metadata.walletID, recordID: metadata.id, suffix: "view"))
        }
        metadataStore.upsert(metadata)
    }

    func loadSpendState(recordID: UUID, walletID: UUID) throws -> Data {
        try load(account: account(walletID: walletID, recordID: recordID, suffix: "spend"))
    }

    func loadScanState(walletID: UUID) throws -> Data {
        for record in records(for: walletID) {
            if let state = try? load(account: account(walletID: walletID, recordID: record.id, suffix: "view")) {
                return state
            }
        }
        throw CloakPrivateVaultError.missingPrivateState
    }

    func records(for walletID: UUID?) -> [CloakPrivateRecordMetadata] {
        metadataStore.load()
            .filter { walletID == nil || $0.walletID == walletID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func unspentRecords(for walletID: UUID?) -> [CloakPrivateRecordMetadata] {
        records(for: walletID).filter { $0.state == .deposited || $0.state == .unknown }
    }

    func markSpent(recordID: UUID, walletID: UUID, signature: String?) throws -> CloakPrivateRecordMetadata {
        guard let existing = records(for: walletID).first(where: { $0.id == recordID }) else {
            throw CloakPrivateVaultError.missingPrivateState
        }
        let updated = existing.spent(with: signature)
        metadataStore.upsert(updated)
        try? delete(account: account(walletID: walletID, recordID: recordID, suffix: "spend"))
        return updated
    }

    func clearPrivateData(for walletID: UUID) throws {
        let walletRecords = records(for: walletID)
        for record in walletRecords {
            try? delete(account: account(walletID: walletID, recordID: record.id, suffix: "spend"))
            try? delete(account: account(walletID: walletID, recordID: record.id, suffix: "view"))
        }
        metadataStore.remove(walletID: walletID)
    }

    private func account(walletID: UUID, recordID: UUID, suffix: String) -> String {
        "\(walletID.uuidString).\(recordID.uuidString).\(suffix)"
    }

    private func save(data: Data, account: String) throws {
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw CloakPrivateVaultError.keychainError(updateStatus)
        }
        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw CloakPrivateVaultError.keychainError(addStatus)
        }
    }

    private func load(account: String) throws -> Data {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw CloakPrivateVaultError.missingPrivateState
        }
        guard status == errSecSuccess else {
            throw CloakPrivateVaultError.keychainError(status)
        }
        guard let data = item as? Data, !data.isEmpty else {
            throw CloakPrivateVaultError.invalidPrivateState
        }
        return data
    }

    private func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CloakPrivateVaultError.keychainError(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

final class CloakPrivateMetadataStore {
    static let recordsKey = "ai.gorkh.cloak.private.records.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [CloakPrivateRecordMetadata] {
        guard let data = defaults.data(forKey: Self.recordsKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CloakPrivateRecordMetadata].self, from: data)) ?? []
    }

    func upsert(_ record: CloakPrivateRecordMetadata) {
        var records = load()
        records.removeAll { $0.id == record.id }
        records.append(record)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try? encoder.encode(records), forKey: Self.recordsKey)
    }

    func remove(walletID: UUID) {
        let records = load().filter { $0.walletID != walletID }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try? encoder.encode(records), forKey: Self.recordsKey)
    }
}
