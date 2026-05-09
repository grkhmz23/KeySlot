import Combine
import Foundation

@MainActor
final class WalletManager: ObservableObject {
    @Published private(set) var profiles: [WalletProfile] = []
    @Published var selectedWalletID: UUID?
    @Published var selectedNetwork: WalletNetwork = .devnet
    @Published private(set) var vaultState: WalletVaultState = .missing
    @Published private(set) var balance: WalletBalance?
    @Published private(set) var auditEvents: [AuditEvent] = []
    @Published private(set) var currentDraft: TransactionDraft?
    @Published private(set) var simulationResult: SimulationResult?
    @Published private(set) var approvalState: ApprovalState = .idle
    @Published private(set) var tokenBalances: [TokenBalance] = []
    @Published private(set) var tokenBalancesFetchedAt: Date?
    @Published private(set) var tokenBalanceError: String?
    @Published private(set) var currentTokenDraft: TokenTransferDraft?
    @Published private(set) var tokenSimulationResult: SimulationResult?
    @Published private(set) var tokenApprovalState: ApprovalState = .idle
    @Published private(set) var lastTransactionSignature: String?
    @Published private(set) var lastConfirmationStatus: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var isBusy = false
    @Published private(set) var securityPolicy: WalletSecurityPolicy
    @Published private(set) var authenticationStatusMessage: String
    @Published private(set) var cloakAdapterStatus: CloakAdapterStatus = .lockedInPhase23
    @Published private(set) var cloakVaultStatus: CloakVaultStatus = .statusOnly(walletID: nil)
    @Published private(set) var currentCloakDepositDraft: CloakDepositDraft?
    @Published private(set) var currentCloakSignerRequest: CloakSignerRequestSummary?
    @Published private(set) var cloakSignerPreflightResult: CloakSignerPreflightResult?
    @Published private(set) var cloakBridgeResponse: CloakBridgeResponseSummary?
    @Published private(set) var cloakBridgeContractResponse: CloakBridgeResponse?
    @Published private(set) var cloakHelperInvocationStatus: CloakHelperInvocationStatus = .disabled

    private let vault: WalletVault
    private let rpcClient: SolanaRPCClient
    private let auditLog: AuditLog
    private let metadataStore: WalletMetadataStore
    private let securitySettingsStore: WalletSecuritySettingsStore
    private let localAuthenticationService: any LocalAuthenticationService
    private let mnemonicService: any MnemonicService
    private let cloakBridge: any CloakBridgeProtocol
    private let cloakPrivateVault: any CloakPrivateVault
    private let cloakHelperInvocationAdapter: CloakHelperInvocationAdapter
    private let cloakSignerBridgePolicy: CloakSignerBridgePolicy
    private let derivationService: SolanaDerivationService
    private var lockController: WalletLockController
    private var unlockedSecrets: [UUID: WalletSecret] = [:]
    private var preparedMessage: Data?
    private var preparedTokenMessage: Data?
    private var preparedDraftFingerprint: String?
    private var preparedTokenDraftFingerprint: String?

    var selectedProfile: WalletProfile? {
        profiles.first { $0.id == selectedWalletID }
    }

    var selectedBackupStatus: WalletBackupStatus? {
        selectedProfile.map(WalletBackupStatus.evaluate(profile:))
    }

    var explorerURLForLastSignature: URL? {
        guard let signature = lastTransactionSignature else {
            return nil
        }
        return URL(string: "https://explorer.solana.com/tx/\(signature)\(selectedNetwork.explorerClusterQuery)")
    }

    convenience init() {
        self.init(
            vault: KeychainWalletVault(),
            rpcClient: SolanaRPCClient(),
            auditLog: AuditLog(),
            metadataStore: WalletMetadataStore()
        )
    }

    convenience init(
        vault: WalletVault,
        rpcClient: SolanaRPCClient,
        auditLog: AuditLog,
        metadataStore: WalletMetadataStore
    ) {
        self.init(
            vault: vault,
            rpcClient: rpcClient,
            auditLog: auditLog,
            metadataStore: metadataStore,
            securitySettingsStore: WalletSecuritySettingsStore(),
            localAuthenticationService: SystemLocalAuthenticationService(),
            mnemonicService: Bip39MnemonicService.shared,
            cloakBridge: CloakBridgeUnavailable(),
            cloakPrivateVault: CloakPrivateVaultStatusOnly(),
            cloakHelperInvocationAdapter: .disabled()
        )
    }

    init(
        vault: WalletVault,
        rpcClient: SolanaRPCClient,
        auditLog: AuditLog,
        metadataStore: WalletMetadataStore,
        securitySettingsStore: WalletSecuritySettingsStore,
        localAuthenticationService: any LocalAuthenticationService,
        mnemonicService: any MnemonicService,
        cloakBridge: any CloakBridgeProtocol,
        cloakPrivateVault: any CloakPrivateVault,
        cloakHelperInvocationAdapter: CloakHelperInvocationAdapter
    ) {
        self.vault = vault
        self.rpcClient = rpcClient
        self.auditLog = auditLog
        self.metadataStore = metadataStore
        self.securitySettingsStore = securitySettingsStore
        self.localAuthenticationService = localAuthenticationService
        self.mnemonicService = mnemonicService
        self.cloakBridge = cloakBridge
        self.cloakPrivateVault = cloakPrivateVault
        self.cloakHelperInvocationAdapter = cloakHelperInvocationAdapter
        self.cloakSignerBridgePolicy = .locked
        self.derivationService = SolanaDerivationService(mnemonicService: mnemonicService)
        let policy = securitySettingsStore.loadPolicy()
        self.securityPolicy = policy
        self.authenticationStatusMessage = localAuthenticationService.statusDescription
        self.cloakHelperInvocationStatus = cloakHelperInvocationAdapter.status
        self.lockController = WalletLockController(policy: policy)
        loadMetadata()
        auditEvents = auditLog.loadRecent()
        refreshVaultState()
        refreshCloakVaultStatus(recordAudit: false)
    }

    func selectProfile(_ profileID: UUID?) {
        noteUserActivity()
        selectedWalletID = profileID
        if let selectedProfile {
            selectedNetwork = selectedProfile.selectedNetwork
        }
        balance = nil
        currentDraft = nil
        simulationResult = nil
        approvalState = .idle
        preparedMessage = nil
        preparedDraftFingerprint = nil
        tokenBalances = []
        tokenBalancesFetchedAt = nil
        tokenBalanceError = nil
        currentTokenDraft = nil
        tokenSimulationResult = nil
        tokenApprovalState = .idle
        preparedTokenMessage = nil
        preparedTokenDraftFingerprint = nil
        currentCloakDepositDraft = nil
        currentCloakSignerRequest = nil
        cloakSignerPreflightResult = nil
        cloakBridgeResponse = nil
        cloakBridgeContractResponse = nil
        refreshVaultState()
        refreshCloakVaultStatus(recordAudit: false)
    }

    func setNetwork(_ network: WalletNetwork) {
        noteUserActivity()
        selectedNetwork = network
        guard let selectedWalletID,
              let index = profiles.firstIndex(where: { $0.id == selectedWalletID }) else {
            return
        }
        profiles[index].selectedNetwork = network
        profiles[index].lastUsedAt = Date()
        saveMetadata()
        balance = nil
        currentDraft = nil
        simulationResult = nil
        approvalState = .idle
        preparedMessage = nil
        preparedDraftFingerprint = nil
        tokenBalances = []
        tokenBalancesFetchedAt = nil
        tokenBalanceError = nil
        currentTokenDraft = nil
        tokenSimulationResult = nil
        tokenApprovalState = .idle
        preparedTokenMessage = nil
        preparedTokenDraftFingerprint = nil
        currentCloakDepositDraft = nil
        currentCloakSignerRequest = nil
        cloakSignerPreflightResult = nil
        cloakBridgeResponse = cloakBridge.validateEnvironment(network: network)
        cloakBridgeContractResponse = cloakBridge.environmentCheck(network: network)
    }

    func recordPrivateTabViewed() {
        noteUserActivity()
        refreshCloakVaultStatus()
        record(
            kind: .privateTabViewed,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "Private wallet section viewed.",
            details: [
                "cloakProgramID": CloakConstants.programID,
                "bridgeStatus": cloakAdapterStatus.rawValue,
                "phase": "2.4"
            ]
        )
        record(
            kind: .cloakReviewFlowViewed,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "Cloak signer bridge review flow viewed.",
            details: [
                "cloakProgramID": CloakConstants.programID,
                "bridgeStatus": cloakAdapterStatus.rawValue,
                "signingEnabled": "\(cloakSignerBridgePolicy.signingEnabled)",
                "phase": "2.4"
            ]
        )
    }

    func refreshCloakVaultStatus(recordAudit: Bool = true) {
        cloakAdapterStatus = cloakBridge.checkAvailability()
        cloakVaultStatus = cloakPrivateVault.status(for: selectedWalletID)
        cloakBridgeResponse = cloakBridge.validateEnvironment(network: selectedNetwork)
        cloakBridgeContractResponse = cloakBridge.environmentCheck(network: selectedNetwork)

        guard recordAudit else {
            return
        }

        record(
            kind: .cloakVaultStatusChecked,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "Cloak private vault status checked.",
            details: [
                "bridgeStatus": cloakAdapterStatus.rawValue,
                "vaultStatus": cloakVaultStatus.privateWalletStatus.rawValue,
                "referenceCount": "\(cloakVaultStatus.availableReferenceKinds.count)"
            ]
        )
    }

    func checkCloakBridgeHealth() async {
        noteUserActivity()
        let request = CloakBridgeRequest(command: .health, network: selectedNetwork)
        let response = await cloakHelperInvocationAdapter.invoke(request)
        cloakBridgeContractResponse = response
        cloakHelperInvocationStatus = statusFromResponse(response)
        record(
            kind: helperAuditKind(for: response, successKind: .cloakHelperHealthChecked),
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "Cloak bridge health checked.",
            details: [
                "bridgeCommand": response.command.rawValue,
                "bridgeStatus": response.status.rawValue,
                "errorCategory": response.errorCategory.rawValue
            ]
        )
    }

    func checkCloakBridgeEnvironment() async {
        noteUserActivity()
        let request = CloakBridgeRequest(command: .environmentCheck, network: selectedNetwork)
        let response = await cloakHelperInvocationAdapter.invoke(request)
        cloakBridgeContractResponse = response
        cloakHelperInvocationStatus = statusFromResponse(response)
        record(
            kind: helperAuditKind(for: response, successKind: .cloakHelperEnvironmentChecked),
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "Cloak bridge environment checked.",
            details: [
                "network": selectedNetwork.rawValue,
                "bridgeCommand": response.command.rawValue,
                "bridgeStatus": response.status.rawValue,
                "errorCategory": response.errorCategory.rawValue
            ]
        )
    }

    func runCloakDepositPlanDryRun() async {
        noteUserActivity()
        guard let draft = currentCloakDepositDraft else {
            return
        }

        let request = CloakBridgeRequest(
            command: .depositPlan,
            actionKind: .deposit,
            network: draft.network,
            walletPublicAddress: draft.sourceWalletAddress,
            amountLamports: draft.grossLamports,
            mintAddress: draft.mintAddress,
            feeQuote: draft.feeQuote
        )
        let response = await cloakHelperInvocationAdapter.invoke(request)
        cloakBridgeContractResponse = response
        cloakHelperInvocationStatus = statusFromResponse(response)
        if let signerRequest = response.signerRequestSummary {
            currentCloakSignerRequest = signerRequest
            cloakSignerPreflightResult = cloakSignerBridgePolicy.preflight(
                request: signerRequest,
                expectedWalletPublicKey: draft.sourceWalletAddress
            )
        }
        record(
            kind: helperAuditKind(for: response, successKind: .cloakDepositPlanDryRunChecked),
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "Cloak deposit plan dry-run checked.",
            details: [
                "network": draft.network.rawValue,
                "bridgeCommand": response.command.rawValue,
                "bridgeStatus": response.status.rawValue,
                "errorCategory": response.errorCategory.rawValue,
                "grossLamports": "\(draft.grossLamports)",
                "feeLamports": "\(draft.feeQuote.totalFeeLamports)",
                "netLamports": "\(draft.feeQuote.netLamports)"
            ]
        )
    }

    func draftCloakSolDeposit(amountSOLText: String) {
        noteUserActivity()
        guard let profile = selectedProfile else {
            vaultState = .missing
            return
        }

        do {
            let lamports = try SolanaAmountValidator.lamports(fromSOLText: amountSOLText)
            let draft = try CloakDepositDraft(
                network: selectedNetwork,
                sourceWalletAddress: profile.publicAddress,
                grossLamports: lamports
            )
            let response = cloakBridge.buildDepositPlanSummary(draft: draft)
            let contractResponse = cloakBridge.depositPlan(draft: draft)
            let signerRequest = CloakSignerRequestSummary.depositPreview(draft: draft)
            let preflight = cloakSignerBridgePolicy.preflight(
                request: signerRequest,
                expectedWalletPublicKey: profile.publicAddress
            )

            currentCloakDepositDraft = draft
            currentCloakSignerRequest = signerRequest
            cloakSignerPreflightResult = preflight
            cloakBridgeResponse = response
            cloakBridgeContractResponse = contractResponse
            statusMessage = "Cloak deposit draft prepared. Execution remains locked."

            record(
                kind: .cloakDepositPlanGenerated,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Cloak SOL deposit plan generated.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "cloakAction": CloakActionKind.deposit.rawValue,
                    "mint": draft.mintAddress,
                    "grossLamports": "\(draft.grossLamports)",
                    "feeLamports": "\(draft.feeQuote.totalFeeLamports)",
                    "netLamports": "\(draft.feeQuote.netLamports)",
                    "bridgeStatus": contractResponse.status.rawValue,
                    "bridgeCommand": contractResponse.command.rawValue,
                    "draftFingerprint": signerRequest.draftFingerprint
                ]
            )
            record(
                kind: preflight.state == .rejected ? .cloakSignerRequestRejected : .cloakSignerPreflightChecked,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: preflight.message,
                details: [
                    "network": selectedNetwork.rawValue,
                    "cloakAction": CloakActionKind.deposit.rawValue,
                    "requestID": signerRequest.id.uuidString,
                    "signerState": preflight.state.rawValue,
                    "draftFingerprint": signerRequest.draftFingerprint,
                    "requirementsCount": "\(preflight.requirements.count)"
                ]
            )
            record(
                kind: .cloakApprovalRequirementGenerated,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Cloak approval requirements generated for future signer bridge.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "cloakAction": CloakActionKind.deposit.rawValue,
                    "requestID": signerRequest.id.uuidString,
                    "requirementsCount": "\(preflight.requirements.count)",
                    "requiresMainnetPhrase": "\(preflight.requirements.contains(.mainnetConfirmationPhrase))"
                ]
            )
        } catch {
            currentCloakDepositDraft = nil
            currentCloakSignerRequest = nil
            cloakSignerPreflightResult = nil
            cloakBridgeResponse = CloakBridgeResponseSummary(
                requestID: nil,
                actionKind: .deposit,
                status: .blocked,
                message: error.localizedDescription,
                programID: CloakConstants.programID,
                createdAt: Date()
            )
            cloakBridgeContractResponse = CloakBridgeResponse(
                requestID: nil,
                command: .depositPlan,
                actionKind: .deposit,
                status: .rejected,
                errorCategory: .invalidRequest,
                message: error.localizedDescription
            )
            statusMessage = error.localizedDescription
            record(
                kind: .cloakDepositExecutionBlocked,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Cloak deposit draft rejected.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "cloakAction": CloakActionKind.deposit.rawValue,
                    "reason": error.localizedDescription
                ]
            )
        }
    }

    func blockCloakAction(_ actionKind: CloakActionKind) {
        noteUserActivity()
        let request = CloakBridgeRequestSummary(
            actionKind: actionKind,
            network: selectedNetwork,
            walletPublicAddress: selectedProfile?.publicAddress ?? "",
            grossLamports: actionKind == .deposit ? currentCloakDepositDraft?.grossLamports : nil
        )
        let response = CloakBridgeResponseSummary.locked(request: request)
        cloakBridgeResponse = response
        cloakBridgeContractResponse = CloakBridgeResponse(
            requestID: request.id,
            command: actionKind == .deposit ? .executeDeposit : .environmentCheck,
            actionKind: actionKind,
            status: .locked,
            errorCategory: .lockedInPhase23,
            message: response.message
        )
        statusMessage = response.message
        record(
            kind: .cloakBridgeExecutionRejected,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "Cloak action blocked by Phase 2.4 execution lock.",
            details: [
                "network": selectedNetwork.rawValue,
                "cloakAction": actionKind.rawValue,
                "requestID": request.id.uuidString,
                "bridgeStatus": response.status.rawValue
            ]
        )
        if actionKind == .deposit {
            record(
                kind: .cloakSignerRequestLocked,
                walletID: selectedWalletID,
                publicAddress: selectedProfile?.publicAddress,
                message: "Cloak signer request remains locked.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "cloakAction": actionKind.rawValue,
                    "bridgeStatus": response.status.rawValue,
                    "phase": "2.4"
                ]
            )
        }
    }

    private func statusFromResponse(_ response: CloakBridgeResponse) -> CloakHelperInvocationStatus {
        switch response.status {
        case .ok:
            return .dryRunEnabled
        case .unavailable:
            return .unavailable
        case .error, .rejected:
            return .error
        case .locked:
            return cloakHelperInvocationAdapter.status
        }
    }

    private func helperAuditKind(for response: CloakBridgeResponse, successKind: AuditEvent.Kind) -> AuditEvent.Kind {
        if response.errorCategory == .forbiddenField || response.message.lowercased().contains("response rejected") {
            return .cloakHelperResponseRejected
        }
        if response.errorCategory == .lockedInPhase23 || response.status == .locked {
            return .cloakHelperInvocationBlocked
        }
        return successKind
    }

    func createWallet(label: String) {
        runSensitiveOperation {
            let keypair = try SolanaKeypair.generate()
            let profile = WalletProfile(
                label: label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "GORKH Wallet" : label,
                publicAddress: keypair.publicAddress,
                selectedNetwork: selectedNetwork,
                walletOrigin: .legacyKeypair
            )
            let secret = try WalletSecret(seed: keypair.seed)
            try vault.saveSecret(secret, for: profile.id)

            profiles.append(profile)
            selectedWalletID = profile.id
            unlockedSecrets[profile.id] = secret
            noteUserActivity()
            saveMetadata()
            refreshVaultState()
            record(
                kind: .walletCreated,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Wallet created locally."
            )
            statusMessage = "Wallet created and unlocked on this Mac."
        }
    }

    func generateRecoveryPhrase() -> [String] {
        do {
            return try mnemonicService.generate(wordCount: 12)
        } catch {
            statusMessage = error.localizedDescription
            vaultState = .error(error.localizedDescription)
            recordFailure(message: error.localizedDescription)
            return []
        }
    }

    func createRecoveryWallet(label: String, recoveryWords: [String], derivationPath: DerivationPath) {
        let phrase = recoveryWords.joined(separator: " ")
        runSensitiveOperation {
            let keypair = try derivationService.deriveKeypair(mnemonic: phrase, path: derivationPath)
            let profile = WalletProfile(
                label: label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "GORKH Wallet" : label,
                publicAddress: keypair.publicAddress,
                selectedNetwork: selectedNetwork,
                walletOrigin: .generatedRecovery,
                derivationPath: derivationPath.rawValue
            )
            let secret = try WalletSecret(seed: keypair.seed)
            try vault.saveSecret(secret, for: profile.id)

            profiles.append(profile)
            selectedWalletID = profile.id
            unlockedSecrets[profile.id] = secret
            noteUserActivity()
            saveMetadata()
            refreshVaultState()
            record(
                kind: .walletCreated,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Wallet created from recovery phrase locally.",
                details: [
                    "origin": profile.walletOrigin.rawValue,
                    "derivationPath": derivationPath.rawValue
                ]
            )
            statusMessage = "Recovery wallet created and unlocked on this Mac."
        }
    }

    func importPrivateKey(label: String, privateKeyText: String) {
        runSensitiveOperation {
            let keypair = try SolanaKeypair.importPrivateKey(privateKeyText)
            let profile = WalletProfile(
                label: label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Imported Wallet" : label,
                publicAddress: keypair.publicAddress,
                selectedNetwork: selectedNetwork,
                walletOrigin: .importedPrivateKey
            )
            let secret = try WalletSecret(seed: keypair.seed)
            try vault.saveSecret(secret, for: profile.id)

            profiles.append(profile)
            selectedWalletID = profile.id
            unlockedSecrets[profile.id] = secret
            noteUserActivity()
            saveMetadata()
            refreshVaultState()
            record(
                kind: .walletImported,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Wallet imported locally."
            )
            statusMessage = "Wallet imported and unlocked."
        }
    }

    func importMnemonic(label: String, mnemonic: String) {
        importMnemonic(label: label, mnemonic: mnemonic, derivationPath: .defaultSolana)
    }

    func importMnemonic(label: String, mnemonic: String, derivationPath: DerivationPath) {
        runSensitiveOperation {
            let keypair = try derivationService.deriveKeypair(mnemonic: mnemonic, path: derivationPath)
            let profile = WalletProfile(
                label: label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Imported Wallet" : label,
                publicAddress: keypair.publicAddress,
                selectedNetwork: selectedNetwork,
                walletOrigin: .importedRecovery,
                derivationPath: derivationPath.rawValue
            )
            let secret = try WalletSecret(seed: keypair.seed)
            try vault.saveSecret(secret, for: profile.id)

            profiles.append(profile)
            selectedWalletID = profile.id
            unlockedSecrets[profile.id] = secret
            noteUserActivity()
            saveMetadata()
            refreshVaultState()
            record(
                kind: .walletImported,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Recovery phrase wallet imported locally.",
                details: [
                    "origin": profile.walletOrigin.rawValue,
                    "derivationPath": derivationPath.rawValue
                ]
            )
            statusMessage = "Recovery wallet imported and unlocked."
        }
    }

    func previewMnemonicAddress(mnemonic: String, derivationPath: DerivationPath) throws -> String {
        try derivationService.deriveKeypair(mnemonic: mnemonic, path: derivationPath).publicAddress
    }

    func isValidMnemonic(_ mnemonic: String) -> Bool {
        mnemonicService.validate(mnemonic)
    }

    func noteUserActivity(now: Date = Date()) {
        lockController.markActivity(now: now)
    }

    func enforceAutoLockIfNeeded(now: Date = Date()) {
        guard vaultState == .unlocked, lockController.shouldAutoLock(now: now) else {
            return
        }
        lockWallet(message: "Wallet auto-locked after inactivity.", details: [
            "reason": "inactivity",
            "timeout": securityPolicy.autoLockTimeout.rawValue
        ], kind: .walletAutoLocked)
    }

    func lockForAppInactivity() {
        guard securityPolicy.lockWhenAppInactive, vaultState == .unlocked else {
            return
        }
        lockWallet(message: "Wallet locked because the app became inactive.", details: [
            "reason": "app_inactive"
        ], kind: .walletAutoLocked)
    }

    func updateAutoLockTimeout(_ timeout: WalletAutoLockTimeout) {
        var policy = securityPolicy
        policy.autoLockTimeout = timeout
        updateSecurityPolicy(policy)
    }

    func updateLockWhenAppInactive(_ enabled: Bool) {
        var policy = securityPolicy
        policy.lockWhenAppInactive = enabled
        updateSecurityPolicy(policy)
    }

    func updateRequireLocalAuthenticationForUnlock(_ enabled: Bool) {
        var policy = securityPolicy
        policy.requireLocalAuthenticationForUnlock = enabled
        updateSecurityPolicy(policy)
    }

    func updateRequireLocalAuthenticationForSigning(_ enabled: Bool) {
        var policy = securityPolicy
        policy.requireLocalAuthenticationForSigning = enabled
        updateSecurityPolicy(policy)
    }

    func unlockWallet() async {
        guard let profile = selectedProfile else {
            vaultState = .missing
            return
        }

        guard await authenticateIfNeeded(
            required: securityPolicy.requireLocalAuthenticationForUnlock,
            reason: "Unlock the local GORKH wallet signer."
        ) else {
            return
        }

        runSensitiveOperation {
            let secret = try vault.loadSecret(for: profile.id)
            unlockedSecrets[profile.id] = secret
            noteUserActivity()
            refreshVaultState()
            record(
                kind: .walletUnlocked,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Wallet unlocked into memory."
            )
            statusMessage = "Wallet unlocked."
        }
    }

    func lockWallet() {
        lockWallet(message: "Wallet locked.")
    }

    private func lockWallet(
        message: String,
        details: [String: String] = [:],
        kind: AuditEvent.Kind = .walletLocked
    ) {
        guard let profile = selectedProfile else {
            vaultState = .missing
            return
        }

        if var secret = unlockedSecrets[profile.id] {
            secret.clear()
        }
        unlockedSecrets.removeValue(forKey: profile.id)
        preparedMessage = nil
        preparedTokenMessage = nil
        preparedDraftFingerprint = nil
        preparedTokenDraftFingerprint = nil
        approvalState = currentDraft == nil ? .idle : .drafted
        tokenApprovalState = currentTokenDraft == nil ? .idle : .drafted
        refreshVaultState()
        record(
            kind: kind,
            walletID: profile.id,
            publicAddress: profile.publicAddress,
            message: message,
            details: details
        )
        statusMessage = message
    }

    func deleteSelectedWallet(confirmation: String) {
        guard let profile = selectedProfile else {
            return
        }
        guard confirmation == "DELETE WALLET" else {
            statusMessage = "Type DELETE WALLET to remove this wallet from this Mac."
            return
        }

        runSensitiveOperation {
            try vault.deleteSecret(for: profile.id)
            unlockedSecrets.removeValue(forKey: profile.id)
            preparedMessage = nil
            preparedTokenMessage = nil
            preparedDraftFingerprint = nil
            preparedTokenDraftFingerprint = nil
            profiles.removeAll { $0.id == profile.id }
            selectedWalletID = profiles.first?.id
            saveMetadata()
            refreshVaultState()
            record(
                kind: .walletDeleted,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Wallet metadata and Keychain secret were deleted from this Mac."
            )
            statusMessage = "Wallet removed."
        }
    }

    func refreshBalance() async {
        noteUserActivity()
        guard let profile = selectedProfile else {
            vaultState = .missing
            return
        }

        await runAsyncOperation {
            let lamports = try await rpcClient.getBalance(address: profile.publicAddress, network: selectedNetwork)
            balance = WalletBalance(lamports: lamports, network: selectedNetwork, fetchedAt: Date(), errorMessage: nil)
            record(
                kind: .balanceRefreshed,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Balance refreshed.",
                details: ["network": selectedNetwork.rawValue]
            )
            statusMessage = "Balance refreshed."
        }
    }

    func refreshTokenBalances() async {
        noteUserActivity()
        guard let profile = selectedProfile else {
            vaultState = .missing
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let balances = try await rpcClient.getTokenBalances(ownerAddress: profile.publicAddress, network: selectedNetwork)
            tokenBalances = balances
            tokenBalancesFetchedAt = Date()
            tokenBalanceError = nil
            record(
                kind: .tokenBalancesRefreshed,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "SPL token balances refreshed.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "tokenAccountCount": "\(balances.count)"
                ]
            )
            statusMessage = balances.isEmpty ? "No SPL token accounts found." : "SPL token balances refreshed."
        } catch {
            tokenBalanceError = error.localizedDescription
            statusMessage = error.localizedDescription
            record(
                kind: .tokenTransferFailed,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Token balance refresh failed.",
                details: ["error": error.localizedDescription]
            )
        }
    }

    func draftTokenTransfer(token: TokenBalance, recipient: String, amountText: String) async {
        noteUserActivity()
        guard let profile = selectedProfile else {
            vaultState = .missing
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            guard vaultState == .unlocked else {
                throw WalletVaultError.missingSecret
            }
            guard token.ownerAddress == profile.publicAddress else {
                throw TokenTransferValidationError.invalidTokenAccount("Selected token account does not belong to the active wallet.")
            }
            guard token.programKind == .splToken else {
                throw TokenTransferValidationError.unsupportedTokenProgram("Token-2022 balances are visible, but Token-2022 sends are deferred until extension account handling is implemented.")
            }
            guard token.state == .initialized else {
                throw TokenTransferValidationError.invalidTokenAccount("Selected token account is \(token.state.rawValue) and cannot be sent.")
            }
            let mintDecimals = token.decimals == nil
                ? try? await rpcClient.getMintDecimals(
                    mintAddress: token.mintAddress,
                    programKind: token.programKind,
                    network: selectedNetwork
                )
                : nil
            let metadata = TokenMetadataResolver.resolve(
                balance: token,
                network: selectedNetwork,
                mintAccountDecimals: mintDecimals
            )
            let warnings = TokenMetadataResolver.warnings(for: token, metadata: metadata)
            guard let decimals = metadata.decimals else {
                throw TokenTransferValidationError.invalidDecimals("Token decimals could not be resolved from the token account, local registry, or mint account.")
            }
            if warnings.contains(.frozenAccount) {
                throw TokenTransferValidationError.invalidTokenAccount("Selected token account is frozen and cannot be sent.")
            }
            if warnings.contains(.token2022Unsupported) {
                throw TokenTransferValidationError.unsupportedTokenProgram("Token-2022 balances are visible, but Token-2022 sends are deferred until extension account handling is implemented.")
            }
            let recipientOwner = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
            guard SolanaAddressValidator.isValidAddress(recipientOwner) else {
                throw SolanaValidationError.invalidAddress("Recipient owner address is invalid.")
            }

            let amountRaw = try TokenAmountFormatter.rawAmount(fromUIAmount: amountText, decimals: decimals)
            guard amountRaw <= token.amountRaw else {
                throw TokenTransferValidationError.insufficientBalance("Token amount exceeds the available balance.")
            }

            let recipientAccounts = try await rpcClient.getTokenAccounts(
                ownerAddress: recipientOwner,
                mintAddress: token.mintAddress,
                programKind: token.programKind,
                network: selectedNetwork
            )
            let recipientTokenAccount = recipientAccounts.first { $0.state == .initialized }?.tokenAccountAddress
            let rent = try? await rpcClient.getMinimumBalanceForRentExemption(byteCount: 165, network: selectedNetwork)
            let ataPlan: AssociatedTokenAccountPlan
            if let recipientTokenAccount {
                ataPlan = AssociatedTokenAccount.existingPlan(
                    recipientOwner: recipientOwner,
                    mint: token.mintAddress,
                    tokenProgramKind: token.programKind,
                    recipientTokenAccount: recipientTokenAccount,
                    rentExemptLamports: rent
                )
            } else {
                ataPlan = AssociatedTokenAccount.missingPlan(
                    recipientOwner: recipientOwner,
                    mint: token.mintAddress,
                    tokenProgramKind: token.programKind,
                    rentExemptLamports: rent
                )
            }
            let destinationTokenAccount = recipientTokenAccount ?? ataPlan.associatedTokenAddress

            let draft = TokenTransferDraft(
                network: selectedNetwork,
                ownerAddress: profile.publicAddress,
                sourceTokenAccount: token.tokenAccountAddress,
                mintAddress: token.mintAddress,
                tokenProgramKind: token.programKind,
                recipientOwnerAddress: recipientOwner,
                recipientTokenAccount: destinationTokenAccount,
                amountRaw: amountRaw,
                amountText: amountText.trimmingCharacters(in: .whitespacesAndNewlines),
                decimals: decimals,
                availableAmountRaw: token.amountRaw,
                ataPlan: ataPlan,
                tokenSymbol: metadata.symbol,
                tokenName: metadata.name,
                metadataSource: metadata.source,
                sourceAccountState: token.state,
                sourceDelegateAddress: token.delegateAddress,
                sourceCloseAuthorityAddress: token.closeAuthorityAddress,
                warnings: warnings
            )

            currentTokenDraft = draft
            tokenSimulationResult = nil
            preparedTokenMessage = nil
            preparedTokenDraftFingerprint = nil
            lastTransactionSignature = nil
            lastConfirmationStatus = nil
            tokenApprovalState = .drafted

            if ataPlan.shouldCreateAssociatedTokenAccount {
                guard ataPlan.creationSupported, destinationTokenAccount != nil else {
                    throw TokenTransferValidationError.associatedTokenAccountCreationUnavailable(ataPlan.message)
                }
                record(
                    kind: .ataCreationPlanned,
                    walletID: profile.id,
                    publicAddress: profile.publicAddress,
                    message: "Recipient associated token account is missing.",
                    details: [
                        "network": selectedNetwork.rawValue,
                        "mint": token.mintAddress,
                        "tokenSymbol": metadata.symbol,
                        "tokenProgram": token.programKind.rawValue,
                        "recipientOwner": recipientOwner,
                        "associatedTokenAccount": destinationTokenAccount ?? ""
                    ]
                )
            }

            record(
                kind: .tokenTransferDrafted,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "SPL token transfer drafted.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "mint": token.mintAddress,
                    "tokenSymbol": metadata.symbol,
                    "tokenMetadataSource": metadata.source.rawValue,
                    "sourceTokenAccount": token.tokenAccountAddress,
                    "sourceAccountState": token.state.rawValue,
                    "recipientOwner": recipientOwner,
                    "recipientTokenAccount": destinationTokenAccount ?? "",
                    "createsAssociatedTokenAccount": "\(ataPlan.shouldCreateAssociatedTokenAccount)",
                    "amountRaw": "\(amountRaw)",
                    "decimals": "\(decimals)",
                    "warnings": warnings.map(\.rawValue).joined(separator: ","),
                    "warningsCount": "\(warnings.count)"
                ]
            )
            statusMessage = "Token transfer draft prepared."
        } catch {
            tokenApprovalState = .failed(error.localizedDescription)
            statusMessage = error.localizedDescription
            recordTokenFailure(message: error.localizedDescription)
        }
    }

    func simulateCurrentTokenDraft() async {
        noteUserActivity()
        guard let draft = currentTokenDraft, let profile = selectedProfile else {
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let blockhash = try await rpcClient.getLatestBlockhash(network: draft.network)
            let message = try SplTokenInstructionBuilder.makeTransferCheckedMessage(
                draft: draft,
                recentBlockhash: blockhash
            )
            let messageBase64 = SolanaTransactionBuilder.makeMessageBase64(message: message)
            let fee = try? await rpcClient.getFeeForMessage(messageBase64: messageBase64, network: draft.network)
            let transactionBase64 = SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message)
            var result = try await rpcClient.simulateTransaction(transactionBase64: transactionBase64, network: draft.network)
            result.estimatedFeeLamports = fee ?? result.estimatedFeeLamports

            preparedTokenMessage = message
            preparedTokenDraftFingerprint = WalletApprovalGuard.fingerprint(draft: draft)
            tokenSimulationResult = result
            tokenApprovalState = result.status == .success ? .simulated : .failed(result.errorMessage ?? "Token simulation failed.")
            record(
                kind: .tokenTransferSimulated,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "SPL token transfer simulated.",
                details: [
                    "network": draft.network.rawValue,
                    "mint": draft.mintAddress,
                    "tokenSymbol": draft.tokenSymbol ?? "UNKNOWN",
                    "status": result.status.rawValue,
                    "createsAssociatedTokenAccount": "\(draft.ataPlan.shouldCreateAssociatedTokenAccount)",
                    "warningsCount": "\(draft.warnings.count)"
                ]
            )
            if draft.ataPlan.shouldCreateAssociatedTokenAccount, result.status == .success {
                record(
                    kind: .ataCreationIncluded,
                    walletID: profile.id,
                    publicAddress: profile.publicAddress,
                    message: "ATA creation included in simulated SPL token transfer.",
                    details: [
                        "network": draft.network.rawValue,
                        "mint": draft.mintAddress,
                        "tokenSymbol": draft.tokenSymbol ?? "UNKNOWN",
                        "associatedTokenAccount": draft.ataPlan.associatedTokenAddress ?? ""
                    ]
                )
            }
            statusMessage = result.status == .success ? "Token simulation succeeded." : (result.errorMessage ?? "Token simulation failed.")
        } catch {
            tokenSimulationResult = .unavailable(error.localizedDescription)
            tokenApprovalState = .failed(error.localizedDescription)
            statusMessage = error.localizedDescription
            recordTokenFailure(message: error.localizedDescription)
        }
    }

    func approveAndSendToken(
        mainnetConfirmation: String,
        hasCompletedDevnetSmoke: Bool,
        allowsUnavailableSimulation: Bool
    ) async {
        guard let draft = currentTokenDraft,
              let profile = selectedProfile else {
            return
        }

        enforceAutoLockIfNeeded()

        let currentFingerprint = WalletApprovalGuard.fingerprint(draft: draft)
        do {
            try WalletApprovalGuard.validate(WalletSigningPreflightContext(
                network: draft.network,
                simulation: tokenSimulationResult,
                mainnetConfirmation: mainnetConfirmation,
                hasCompletedDevnetSmoke: hasCompletedDevnetSmoke,
                allowsUnavailableSimulation: allowsUnavailableSimulation,
                vaultState: vaultState,
                hasUnlockedSecret: unlockedSecrets[profile.id] != nil,
                hasPreparedMessage: preparedTokenMessage != nil,
                preparedDraftFingerprint: preparedTokenDraftFingerprint,
                currentDraftFingerprint: currentFingerprint,
                hasBlockingWarnings: draft.warnings.contains { $0.blocksSend }
            ))
        } catch {
            tokenApprovalState = .failed(error.localizedDescription)
            statusMessage = draft.network.isMainnet
                ? "Mainnet token send requires unlock, simulation, exact confirmation, and matching approval."
                : error.localizedDescription
            recordTokenFailure(message: error.localizedDescription)
            return
        }

        guard await authenticateIfNeeded(
            required: securityPolicy.requireLocalAuthenticationForSigning,
            reason: "Authorize local signing for this SPL token transfer."
        ) else {
            tokenApprovalState = .failed("Device authentication failed.")
            return
        }

        guard let secret = unlockedSecrets[profile.id],
              let message = preparedTokenMessage else {
            tokenApprovalState = .failed(WalletSigningPreflightError.missingPreparedMessage.localizedDescription)
            statusMessage = WalletSigningPreflightError.missingPreparedMessage.localizedDescription
            return
        }

        noteUserActivity()
        record(
            kind: .tokenTransferApproved,
            walletID: profile.id,
            publicAddress: profile.publicAddress,
            message: "SPL token transfer approved by user.",
            details: [
                "network": draft.network.rawValue,
                "mint": draft.mintAddress,
                "tokenSymbol": draft.tokenSymbol ?? "UNKNOWN",
                "amountRaw": "\(draft.amountRaw)",
                "createsAssociatedTokenAccount": "\(draft.ataPlan.shouldCreateAssociatedTokenAccount)",
                "warnings": draft.warnings.map(\.rawValue).joined(separator: ","),
                "warningsCount": "\(draft.warnings.count)"
            ]
        )

        tokenApprovalState = .approved
        isBusy = true
        defer { isBusy = false }

        do {
            tokenApprovalState = .sending
            let signedTransactionBase64 = try SolanaTransactionBuilder.makeSignedTransactionBase64(
                message: message,
                seed: secret.seed
            )
            let signature = try await rpcClient.sendTransaction(
                transactionBase64: signedTransactionBase64,
                network: draft.network
            )
            lastTransactionSignature = signature
            lastConfirmationStatus = try? await rpcClient.getSignatureStatus(signature: signature, network: draft.network)
            tokenApprovalState = .sent(signature)
            record(
                kind: .tokenTransferSent,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                transactionSignature: signature,
                message: "SPL token transfer sent.",
                details: [
                    "network": draft.network.rawValue,
                    "mint": draft.mintAddress,
                    "tokenSymbol": draft.tokenSymbol ?? "UNKNOWN",
                    "sourceTokenAccount": draft.sourceTokenAccount,
                    "sourceAccountState": draft.sourceAccountState.rawValue,
                    "recipientOwner": draft.recipientOwnerAddress,
                    "recipientTokenAccount": draft.recipientTokenAccount ?? "",
                    "createsAssociatedTokenAccount": "\(draft.ataPlan.shouldCreateAssociatedTokenAccount)",
                    "amountRaw": "\(draft.amountRaw)",
                    "decimals": "\(draft.decimals)",
                    "warnings": draft.warnings.map(\.rawValue).joined(separator: ","),
                    "warningsCount": "\(draft.warnings.count)"
                ]
            )
            statusMessage = "SPL token transfer sent."
        } catch {
            tokenApprovalState = .failed(error.localizedDescription)
            statusMessage = error.localizedDescription
            recordTokenFailure(message: error.localizedDescription)
        }
    }

    func draftTransaction(recipient: String, amountSOLText: String) {
        noteUserActivity()
        guard let profile = selectedProfile else {
            vaultState = .missing
            return
        }

        do {
            guard SolanaAddressValidator.isValidAddress(recipient) else {
                throw SolanaValidationError.invalidAddress("Recipient address is invalid.")
            }
            let lamports = try SolanaAmountValidator.lamports(fromSOLText: amountSOLText)
            let draft = TransactionDraft(
                network: selectedNetwork,
                fromAddress: profile.publicAddress,
                toAddress: recipient.trimmingCharacters(in: .whitespacesAndNewlines),
                amountLamports: lamports
            )
            currentDraft = draft
            simulationResult = nil
            preparedMessage = nil
            preparedDraftFingerprint = nil
            lastTransactionSignature = nil
            lastConfirmationStatus = nil
            approvalState = .drafted
            record(
                kind: .transactionDrafted,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "SOL transfer drafted.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "to": draft.toAddress,
                    "amountLamports": "\(draft.amountLamports)"
                ]
            )
            statusMessage = "Transaction draft prepared."
        } catch {
            approvalState = .failed(error.localizedDescription)
            recordFailure(message: error.localizedDescription)
            statusMessage = error.localizedDescription
        }
    }

    func simulateCurrentDraft() async {
        noteUserActivity()
        guard let draft = currentDraft, let profile = selectedProfile else {
            return
        }

        await runAsyncOperation {
            let blockhash = try await rpcClient.getLatestBlockhash(network: draft.network)
            let message = try SolanaTransactionBuilder.makeTransferMessage(draft: draft, recentBlockhash: blockhash)
            let messageBase64 = SolanaTransactionBuilder.makeMessageBase64(message: message)
            let fee = try? await rpcClient.getFeeForMessage(messageBase64: messageBase64, network: draft.network)
            let transactionBase64 = SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message)
            var result = try await rpcClient.simulateTransaction(transactionBase64: transactionBase64, network: draft.network)
            result.estimatedFeeLamports = fee ?? result.estimatedFeeLamports

            preparedMessage = message
            preparedDraftFingerprint = WalletApprovalGuard.fingerprint(draft: draft)
            simulationResult = result
            approvalState = result.status == .success ? .simulated : .failed(result.errorMessage ?? "Simulation failed.")
            record(
                kind: .transactionSimulated,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Transaction simulated.",
                details: [
                    "network": draft.network.rawValue,
                    "status": result.status.rawValue
                ]
            )
            statusMessage = result.status == .success ? "Simulation succeeded." : (result.errorMessage ?? "Simulation failed.")
        }
    }

    func approveAndSend(
        mainnetConfirmation: String,
        hasCompletedDevnetSmoke: Bool,
        allowsUnavailableSimulation: Bool
    ) async {
        guard let draft = currentDraft,
              let profile = selectedProfile else {
            return
        }

        enforceAutoLockIfNeeded()

        let currentFingerprint = WalletApprovalGuard.fingerprint(draft: draft)
        do {
            try WalletApprovalGuard.validate(WalletSigningPreflightContext(
                network: draft.network,
                simulation: simulationResult,
                mainnetConfirmation: mainnetConfirmation,
                hasCompletedDevnetSmoke: hasCompletedDevnetSmoke,
                allowsUnavailableSimulation: allowsUnavailableSimulation,
                vaultState: vaultState,
                hasUnlockedSecret: unlockedSecrets[profile.id] != nil,
                hasPreparedMessage: preparedMessage != nil,
                preparedDraftFingerprint: preparedDraftFingerprint,
                currentDraftFingerprint: currentFingerprint,
                hasBlockingWarnings: false
            ))
        } catch {
            approvalState = .failed(error.localizedDescription)
            statusMessage = draft.network.isMainnet
                ? "Mainnet requires unlock, simulation, exact confirmation, and matching approval."
                : error.localizedDescription
            recordFailure(message: error.localizedDescription)
            return
        }

        guard await authenticateIfNeeded(
            required: securityPolicy.requireLocalAuthenticationForSigning,
            reason: "Authorize local signing for this SOL transfer."
        ) else {
            approvalState = .failed("Device authentication failed.")
            return
        }

        guard let secret = unlockedSecrets[profile.id],
              let message = preparedMessage else {
            approvalState = .failed(WalletSigningPreflightError.missingPreparedMessage.localizedDescription)
            statusMessage = WalletSigningPreflightError.missingPreparedMessage.localizedDescription
            return
        }

        noteUserActivity()
        record(
            kind: .transactionApproved,
            walletID: profile.id,
            publicAddress: profile.publicAddress,
            message: "Transaction approved by user.",
            details: ["network": draft.network.rawValue]
        )

        approvalState = .approved
        await runAsyncOperation {
            approvalState = .sending
            let signedTransactionBase64 = try SolanaTransactionBuilder.makeSignedTransactionBase64(
                message: message,
                seed: secret.seed
            )
            let signature = try await rpcClient.sendTransaction(
                transactionBase64: signedTransactionBase64,
                network: draft.network
            )
            lastTransactionSignature = signature
            lastConfirmationStatus = try? await rpcClient.getSignatureStatus(signature: signature, network: draft.network)
            approvalState = .sent(signature)
            record(
                kind: .transactionSent,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                transactionSignature: signature,
                message: "Transaction sent.",
                details: [
                    "network": draft.network.rawValue,
                    "to": draft.toAddress,
                    "amountLamports": "\(draft.amountLamports)"
                ]
            )
            statusMessage = "Transaction sent."
        }
    }

    private func refreshVaultState() {
        guard let selectedWalletID else {
            vaultState = profiles.isEmpty ? .missing : .locked
            return
        }

        if unlockedSecrets[selectedWalletID] != nil {
            vaultState = .unlocked
        } else if vault.containsSecret(for: selectedWalletID) {
            vaultState = .locked
        } else {
            vaultState = .missing
        }
    }

    private func loadMetadata() {
        profiles = metadataStore.loadProfiles()
        selectedWalletID = metadataStore.loadSelectedWalletID() ?? profiles.first?.id
        if let selectedProfile {
            selectedNetwork = selectedProfile.selectedNetwork
        } else {
            selectedNetwork = metadataStore.loadSelectedNetwork()
        }
    }

    private func saveMetadata() {
        metadataStore.saveProfiles(profiles)
        metadataStore.saveSelectedWalletID(selectedWalletID)
        metadataStore.saveSelectedNetwork(selectedNetwork)
    }

    private func updateSecurityPolicy(_ policy: WalletSecurityPolicy) {
        securityPolicy = policy
        securitySettingsStore.savePolicy(policy)
        lockController.updatePolicy(policy)
        record(
            kind: .securityPolicyUpdated,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "Wallet security policy updated.",
            details: [
                "autoLockTimeout": policy.autoLockTimeout.rawValue,
                "lockWhenAppInactive": "\(policy.lockWhenAppInactive)",
                "authForUnlock": "\(policy.requireLocalAuthenticationForUnlock)",
                "authForSigning": "\(policy.requireLocalAuthenticationForSigning)"
            ]
        )
    }

    private func authenticateIfNeeded(required: Bool, reason: String) async -> Bool {
        guard required else {
            authenticationStatusMessage = "Device authentication is disabled in local settings."
            return true
        }

        let result = await localAuthenticationService.authenticate(reason: reason)
        authenticationStatusMessage = result.message
        if result.succeeded {
            return true
        }
        statusMessage = result.message
        record(
            kind: .localAuthenticationFailed,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "Local authentication failed.",
            details: ["authResult": result.message]
        )
        return false
    }

    private func runSensitiveOperation(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            vaultState = .error(error.localizedDescription)
            statusMessage = error.localizedDescription
            recordFailure(message: error.localizedDescription)
        }
    }

    private func runAsyncOperation(_ operation: () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await operation()
        } catch {
            statusMessage = error.localizedDescription
            approvalState = .failed(error.localizedDescription)
            recordFailure(message: error.localizedDescription)
        }
    }

    private func record(
        kind: AuditEvent.Kind,
        walletID: UUID?,
        publicAddress: String?,
        transactionSignature: String? = nil,
        message: String,
        details: [String: String] = [:]
    ) {
        let event = AuditEvent(
            kind: kind,
            walletID: walletID,
            network: selectedNetwork,
            publicAddress: publicAddress,
            transactionSignature: transactionSignature,
            message: message,
            details: details
        )
        auditLog.record(event)
        auditEvents.insert(event, at: 0)
    }

    private func recordFailure(message: String) {
        record(
            kind: .transactionFailed,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: message
        )
    }

    private func recordTokenFailure(message: String) {
        record(
            kind: .tokenTransferFailed,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: message
        )
    }
}

struct WalletMetadataStore {
    static let profilesKey = "gorkh.wallet.profiles"
    static let selectedWalletIDKey = "gorkh.wallet.selectedWalletID"
    static let selectedNetworkKey = "gorkh.wallet.selectedNetwork"
    static let allowedKeys = [profilesKey, selectedWalletIDKey, selectedNetworkKey]

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadProfiles() -> [WalletProfile] {
        guard let data = defaults.data(forKey: Self.profilesKey) else {
            return []
        }
        return (try? decoder.decode([WalletProfile].self, from: data)) ?? []
    }

    func saveProfiles(_ profiles: [WalletProfile]) {
        guard let data = try? encoder.encode(profiles) else {
            return
        }
        defaults.set(data, forKey: Self.profilesKey)
    }

    func loadSelectedWalletID() -> UUID? {
        guard let raw = defaults.string(forKey: Self.selectedWalletIDKey) else {
            return nil
        }
        return UUID(uuidString: raw)
    }

    func saveSelectedWalletID(_ id: UUID?) {
        if let id {
            defaults.set(id.uuidString, forKey: Self.selectedWalletIDKey)
        } else {
            defaults.removeObject(forKey: Self.selectedWalletIDKey)
        }
    }

    func loadSelectedNetwork() -> WalletNetwork {
        guard let raw = defaults.string(forKey: Self.selectedNetworkKey),
              let network = WalletNetwork(rawValue: raw) else {
            return .devnet
        }
        return network
    }

    func saveSelectedNetwork(_ network: WalletNetwork) {
        defaults.set(network.rawValue, forKey: Self.selectedNetworkKey)
    }
}
