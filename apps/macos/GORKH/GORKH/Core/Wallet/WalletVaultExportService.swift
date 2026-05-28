import Foundation

// MARK: - Export Service

protocol WalletVaultExportServicing {
    func exportRecoveryPhrase(
        for profile: WalletProfile,
        code: String
    ) -> WalletExportResult<String>

    func exportPrivateKey(
        for profile: WalletProfile,
        code: String
    ) -> WalletExportResult<String>

    func exportBackup(
        for profile: WalletProfile,
        code: String
    ) -> WalletExportResult<WalletBackupPayload>

    func restoreBackup(
        payload: WalletBackupPayload,
        code: String,
        existingProfiles: [WalletProfile]
    ) -> WalletBackupRestoreResult
}

enum WalletExportResult<T>: Equatable where T: Equatable {
    case success(T)
    case locked(remaining: TimeInterval)
    case wrongCode(remainingAttempts: Int?)
    case missingEnvelope
    case localAuthFailed
    case failed(String)
}

final class WalletVaultExportService: WalletVaultExportServicing {
    private let vault: WalletVault
    private let codeService: VaultExportCodeServicing
    private let envelopeStore: ExportRecoveryEnvelopeStoring
    private let derivationService: SolanaDerivationService
    private let mnemonicService: any MnemonicService

    init(
        vault: WalletVault = KeychainWalletVault(),
        codeService: VaultExportCodeServicing = VaultExportCodeService(),
        envelopeStore: ExportRecoveryEnvelopeStoring = KeychainExportRecoveryEnvelopeStore(),
        derivationService: SolanaDerivationService = SolanaDerivationService(),
        mnemonicService: any MnemonicService = Bip39MnemonicService.shared
    ) {
        self.vault = vault
        self.codeService = codeService
        self.envelopeStore = envelopeStore
        self.derivationService = derivationService
        self.mnemonicService = mnemonicService
    }

    // MARK: - Recovery Phrase Export

    func exportRecoveryPhrase(
        for profile: WalletProfile,
        code: String
    ) -> WalletExportResult<String> {
        let now = Date()
        if codeService.isLocked(for: profile.id, now: now) {
            return .locked(remaining: codeService.lockoutRemaining(for: profile.id, now: now))
        }

        let verification = codeService.verify(code: code, for: profile.id)
        switch verification {
        case .success:
            break
        case .locked(let remaining):
            return .locked(remaining: remaining)
        case .invalidFormat:
            return .wrongCode(remainingAttempts: nil)
        case .wrongCode(let remaining):
            return .wrongCode(remainingAttempts: remaining)
        }

        guard let envelope = try? envelopeStore.loadEnvelope(for: profile.id) else {
            return .missingEnvelope
        }

        do {
            let mnemonic = try ExportRecoveryEnvelopeCrypto.decrypt(envelope: envelope, code: code)
            return .success(mnemonic)
        } catch {
            // Decryption failure with correct code should not happen; treat as wrong code
            return .wrongCode(remainingAttempts: nil)
        }
    }

    // MARK: - Private Key Export

    func exportPrivateKey(
        for profile: WalletProfile,
        code: String
    ) -> WalletExportResult<String> {
        let now = Date()
        if codeService.isLocked(for: profile.id, now: now) {
            return .locked(remaining: codeService.lockoutRemaining(for: profile.id, now: now))
        }

        let verification = codeService.verify(code: code, for: profile.id)
        switch verification {
        case .success:
            break
        case .locked(let remaining):
            return .locked(remaining: remaining)
        case .invalidFormat:
            return .wrongCode(remainingAttempts: nil)
        case .wrongCode(let remaining):
            return .wrongCode(remainingAttempts: remaining)
        }

        do {
            let secret = try vault.loadSecret(for: profile.id)
            let keypair = try SolanaKeypair(seed: secret.seed)

            // Export as Base58-encoded 64-byte keypair (seed + pubkey)
            var combined = Data(secret.seed)
            combined.append(keypair.publicKey)
            let base58 = Base58.encode(combined)

            return .success(base58)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Backup Export

    func exportBackup(
        for profile: WalletProfile,
        code: String
    ) -> WalletExportResult<WalletBackupPayload> {
        let now = Date()
        if codeService.isLocked(for: profile.id, now: now) {
            return .locked(remaining: codeService.lockoutRemaining(for: profile.id, now: now))
        }

        let verification = codeService.verify(code: code, for: profile.id)
        switch verification {
        case .success:
            break
        case .locked(let remaining):
            return .locked(remaining: remaining)
        case .invalidFormat:
            return .wrongCode(remainingAttempts: nil)
        case .wrongCode(let remaining):
            return .wrongCode(remainingAttempts: remaining)
        }

        guard let envelope = try? envelopeStore.loadEnvelope(for: profile.id) else {
            return .missingEnvelope
        }

        let payload = WalletBackupPayload(
            schemaVersion: WalletBackupPayload.currentSchemaVersion,
            productName: "KeySlot",
            walletPublicAddress: profile.publicAddress,
            walletLabel: profile.label,
            derivationPath: profile.derivationPath ?? DerivationPath.defaultSolana.rawValue,
            createdAt: profile.createdAt,
            encryptedRecoveryEnvelope: envelope,
            compatibilityMetadata: .default
        )

        return .success(payload)
    }

    // MARK: - Backup Restore

    func restoreBackup(
        payload: WalletBackupPayload,
        code: String,
        existingProfiles: [WalletProfile]
    ) -> WalletBackupRestoreResult {
        guard payload.schemaVersion == WalletBackupPayload.currentSchemaVersion else {
            return .failed(WalletBackupError.unsupportedSchemaVersion(payload.schemaVersion).localizedDescription)
        }

        guard VaultExportCode.isValidFormat(code) else {
            return .wrongCode(remainingAttempts: nil)
        }

        // Check for existing wallet with same address
        if existingProfiles.contains(where: { $0.publicAddress == payload.walletPublicAddress }) {
            return .failed(WalletBackupError.walletAlreadyExists.localizedDescription)
        }

        do {
            let mnemonic = try ExportRecoveryEnvelopeCrypto.decrypt(
                envelope: payload.encryptedRecoveryEnvelope,
                code: code
            )

            let path = try DerivationPath(payload.derivationPath)
            let keypair = try derivationService.deriveKeypair(mnemonic: mnemonic, path: path)

            guard keypair.publicAddress == payload.walletPublicAddress else {
                return .failed(WalletBackupError.addressMismatch.localizedDescription)
            }

            let profile = WalletProfile(
                label: payload.walletLabel,
                publicAddress: keypair.publicAddress,
                walletOrigin: .importedRecovery,
                derivationPath: path.rawValue
            )

            return .success(profile)
        } catch is ExportRecoveryEnvelope.EnvelopeError {
            return .wrongCode(remainingAttempts: nil)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
