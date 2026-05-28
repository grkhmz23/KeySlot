import Foundation

enum WalletBackupRiskStatus: String, Codable, CaseIterable, Identifiable {
    case backedUp = "backed_up"
    case notVerified = "not_verified"
    case cannotVerify = "cannot_verify"
    case seedOnlyWallet = "seed_only_wallet"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backedUp:
            return "Backed up"
        case .notVerified:
            return "Not verified"
        case .cannotVerify:
            return "Cannot verify"
        case .seedOnlyWallet:
            return "Seed-only wallet"
        }
    }
}

struct WalletBackupStatus: Equatable, Identifiable {
    let id: UUID
    let riskStatus: WalletBackupRiskStatus
    let recoveryPhraseConfirmed: Bool
    let recoveryPhraseExportAvailable: Bool
    let title: String
    let message: String

    static func evaluate(profile: WalletProfile) -> WalletBackupStatus {
        switch profile.walletOrigin {
        case .generatedRecovery:
            return WalletBackupStatus(
                id: profile.id,
                riskStatus: .backedUp,
                recoveryPhraseConfirmed: true,
                recoveryPhraseExportAvailable: false,
                title: "Recovery phrase confirmed",
                message: "The phrase was confirmed during setup. KeySlot stores only the derived signing seed in Keychain, so the phrase cannot be shown again."
            )
        case .importedRecovery:
            return WalletBackupStatus(
                id: profile.id,
                riskStatus: .cannotVerify,
                recoveryPhraseConfirmed: true,
                recoveryPhraseExportAvailable: false,
                title: "Imported recovery phrase",
                message: "This wallet was imported from a phrase. KeySlot stores only the derived signing seed in Keychain and cannot verify or reveal your phrase later."
            )
        case .importedPrivateKey:
            return WalletBackupStatus(
                id: profile.id,
                riskStatus: .seedOnlyWallet,
                recoveryPhraseConfirmed: false,
                recoveryPhraseExportAvailable: false,
                title: "Imported private key",
                message: "This wallet has no recovery phrase in KeySlot. Keep the original private key or source wallet backed up offline."
            )
        case .legacyKeypair:
            return WalletBackupStatus(
                id: profile.id,
                riskStatus: .seedOnlyWallet,
                recoveryPhraseConfirmed: false,
                recoveryPhraseExportAvailable: false,
                title: "Local keypair wallet",
                message: "This wallet was stored as a signing seed only. Recovery phrase export is unavailable."
            )
        case .watchOnly:
            return WalletBackupStatus(
                id: profile.id,
                riskStatus: .cannotVerify,
                recoveryPhraseConfirmed: false,
                recoveryPhraseExportAvailable: false,
                title: "Watch-only address",
                message: "This profile stores public metadata only. It cannot sign, export, or recover funds."
            )
        case .hardwarePlaceholder:
            return WalletBackupStatus(
                id: profile.id,
                riskStatus: .cannotVerify,
                recoveryPhraseConfirmed: false,
                recoveryPhraseExportAvailable: false,
                title: "Hardware wallet placeholder",
                message: "Hardware wallet signing is not implemented in KeySlot yet."
            )
        case .multisigPlaceholder:
            return WalletBackupStatus(
                id: profile.id,
                riskStatus: .cannotVerify,
                recoveryPhraseConfirmed: false,
                recoveryPhraseExportAvailable: false,
                title: "Multisig placeholder",
                message: "Multisig execution is not implemented in KeySlot yet."
            )
        }
    }
}
