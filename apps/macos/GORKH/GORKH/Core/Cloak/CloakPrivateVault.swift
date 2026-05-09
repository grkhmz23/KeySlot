import Foundation

enum CloakPrivateVaultError: LocalizedError, Equatable {
    case storageLockedInPhase20

    var errorDescription: String? {
        "Cloak private data storage is locked in Phase 2.2."
    }
}

protocol CloakPrivateVault {
    func status(for walletID: UUID?) -> CloakVaultStatus
    func storeReference(kind: CloakSecretKind, referenceID: String, for walletID: UUID) throws
    func clearPrivateData(for walletID: UUID) throws
}

struct CloakPrivateVaultStatusOnly: CloakPrivateVault {
    func status(for walletID: UUID?) -> CloakVaultStatus {
        .statusOnly(walletID: walletID)
    }

    func storeReference(kind: CloakSecretKind, referenceID: String, for walletID: UUID) throws {
        throw CloakPrivateVaultError.storageLockedInPhase20
    }

    func clearPrivateData(for walletID: UUID) throws {
        throw CloakPrivateVaultError.storageLockedInPhase20
    }
}
