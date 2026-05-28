import Combine
import Foundation

struct PendingSendDraft: Equatable {
    let amount: String
    let recipient: String
    let token: String?
}

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
    @Published var selectedPortfolioScope: PortfolioWalletScope = .activeWallet
    @Published private(set) var portfolioSummary: PortfolioAggregateSummary = .empty()
    @Published private(set) var portfolioHistory: [PortfolioSnapshot] = []
    @Published private(set) var portfolioPnLSummary: PnLPortfolioSummary = .empty()
    @Published private(set) var costBasisEntries: [CostBasisEntry] = []
    @Published private(set) var portfolioStatus: PortfolioDataStatus = .idle
    @Published private(set) var portfolioErrorMessage: String?
    @Published private(set) var pusdCirculationSnapshot: PUSDCirculationSnapshot = .idle()
    @Published private(set) var currentSwapQuote: JupiterQuoteSummary?
    @Published private(set) var currentSwapBuild: JupiterSwapTransactionBuild?
    @Published private(set) var currentSwapReview: SwapTransactionReview?
    @Published private(set) var swapSimulationResult: SimulationResult?
    @Published private(set) var swapApprovalState: ApprovalState = .idle
    @Published private(set) var swapErrorMessage: String?
    @Published private(set) var lastSwapSignature: String?
    @Published private(set) var lastSwapConfirmationStatus: String?
    @Published private(set) var swapBalanceDeltaVerification: SwapBalanceDeltaVerification = .notStarted
    @Published private(set) var currentOrcaHarvestDraft: OrcaHarvestDraft?
    @Published private(set) var currentOrcaHarvestReview: OrcaHarvestReview?
    @Published private(set) var orcaHarvestSimulationResult: SimulationResult?
    @Published private(set) var orcaHarvestApprovalState: ApprovalState = .idle
    @Published private(set) var orcaHarvestErrorMessage: String?
    @Published private(set) var lastOrcaHarvestSignature: String?
    @Published private(set) var rpcHealthSnapshot: RPCHealthSnapshot
    @Published var pendingSendDraft: PendingSendDraft?

    private let vault: WalletVault
    private let rpcClient: SolanaRPCClient
    private let rpcHealthChecker: RPCHealthChecker
    private let auditLog: AuditLog
    private let metadataStore: WalletMetadataStore
    private let securitySettingsStore: WalletSecuritySettingsStore
    private let localAuthenticationService: any LocalAuthenticationService
    private let mnemonicService: any MnemonicService
    private let portfolioRefreshService: PortfolioManager
    private let portfolioSnapshotStore: PortfolioSnapshotStore
    private let costBasisStore: CostBasisStore
    private let pusdCirculationClient: PUSDCirculationClient
    private let jupiterQuoteClient: JupiterQuoteClient
    private let jupiterSwapClient: JupiterSwapClient
    private let orcaHelperBridge: any OrcaHelperBridging
    private let derivationService: SolanaDerivationService
    private var lockController: WalletLockController
    private var unlockedSecrets: [UUID: WalletSecret] = [:]
    private var preparedMessage: Data?
    private var preparedTokenMessage: Data?
    private var preparedDraftFingerprint: String?
    private var preparedTokenDraftFingerprint: String?
    private var preparedSwapFingerprint: String?
    private var preparedOrcaHarvestMessage: Data?
    private var preparedOrcaHarvestFingerprint: String?
    private var swapPreflightBalances: [String: UInt64] = [:]

    var rpcFastConfiguration: RPCFastConfiguration {
        rpcClient.configuration
    }

    var rpcFastEndpoint: RPCFastEndpoint {
        rpcFastConfiguration.endpoint(for: selectedNetwork)
    }

    var rpcProviderSecurityStatus: RPCProviderSecurityStatus {
        rpcFastConfiguration.securityStatus(for: selectedNetwork)
    }

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

    var explorerURLForLastSwapSignature: URL? {
        guard let signature = lastSwapSignature else {
            return nil
        }
        return URL(string: "https://explorer.solana.com/tx/\(signature)\(selectedNetwork.explorerClusterQuery)")
    }

    var jupiterAPIConfiguration: JupiterAPIConfiguration {
        JupiterAPIConfiguration()
    }

    var jupiterSwapAPIMode: JupiterSwapAPIMode {
        jupiterAPIConfiguration.swapMode
    }

    var jupiterEndpointCompatibility: [JupiterEndpointCompatibility] {
        jupiterAPIConfiguration.endpointCompatibility
    }

    var swapInputTokenOptions: [SwapTokenOption] {
        var options: [SwapTokenOption] = []
        if let balance {
            options.append(SwapTokenOption(
                mintAddress: SwapConstants.nativeSolMint,
                symbol: "SOL",
                name: "Solana",
                decimals: 9,
                balanceRaw: balance.lamports,
                uiAmountString: TokenAmountFormatter.format(rawAmount: balance.lamports, decimals: 9),
                isNativeSOL: true,
                tokenProgramKind: nil,
                warnings: []
            ))
        }

        let grouped = Dictionary(grouping: tokenBalances) { $0.mintAddress }
        for (mint, balances) in grouped {
            guard let first = balances.first else {
                continue
            }
            let metadata = TokenMetadataResolver.resolve(balance: first, network: selectedNetwork)
            let warnings = balances.reduce(into: [TokenWarning]()) { partial, balance in
                TokenMetadataResolver.warnings(for: balance, metadata: metadata).forEach { warning in
                    if !partial.contains(warning) {
                        partial.append(warning)
                    }
                }
            }
            let totalRaw = balances.reduce(UInt64(0)) { partial, balance in
                let result = partial.addingReportingOverflow(balance.amountRaw)
                return result.overflow ? UInt64.max : result.partialValue
            }
            let decimals = metadata.decimals
            options.append(SwapTokenOption(
                mintAddress: mint,
                symbol: metadata.symbol,
                name: metadata.name,
                decimals: decimals,
                balanceRaw: totalRaw,
                uiAmountString: decimals.map { TokenAmountFormatter.format(rawAmount: totalRaw, decimals: $0) } ?? "\(totalRaw)",
                isNativeSOL: false,
                tokenProgramKind: first.programKind,
                warnings: warnings.sorted { $0.rawValue < $1.rawValue }
            ))
        }

        return options.sorted {
            if $0.isNativeSOL != $1.isNativeSOL {
                return $0.isNativeSOL
            }
            return $0.symbol < $1.symbol
        }
    }

    var swapOutputTokenOptions: [TokenMetadata] {
        TokenMetadataRegistry.knownTokens
            .filter { $0.network == selectedNetwork || $0.network == nil }
            .sorted { $0.symbol < $1.symbol }
    }

    var activePUSDTokenBalance: TokenBalance? {
        guard selectedNetwork == .mainnetBeta, let profile = selectedProfile else {
            return nil
        }
        return tokenBalances.first {
            $0.ownerAddress == profile.publicAddress
                && $0.mintAddress == PUSDConstants.mintAddress
                && $0.programKind == .splToken
                && $0.state == .initialized
                && $0.amountRaw > 0
        }
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
            portfolioPriceClient: JupiterPriceClient(),
            portfolioSnapshotStore: PortfolioSnapshotStore()
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
        portfolioPriceClient: (any PortfolioPriceClient)? = nil,
        portfolioSnapshotStore: PortfolioSnapshotStore? = nil,
        costBasisStore: CostBasisStore? = nil,
        pusdCirculationClient: PUSDCirculationClient? = nil,
        jupiterQuoteClient: JupiterQuoteClient? = nil,
        jupiterSwapClient: JupiterSwapClient? = nil,
        orcaHelperBridge: (any OrcaHelperBridging)? = nil
    ) {
        let resolvedPortfolioPriceClient = portfolioPriceClient ?? JupiterPriceClient()
        self.vault = vault
        self.rpcClient = rpcClient
        self.rpcHealthChecker = RPCHealthChecker(rpcClient: rpcClient)
        self.auditLog = auditLog
        self.metadataStore = metadataStore
        self.securitySettingsStore = securitySettingsStore
        self.localAuthenticationService = localAuthenticationService
        self.mnemonicService = mnemonicService
        self.portfolioRefreshService = PortfolioManager(rpcClient: rpcClient, priceClient: resolvedPortfolioPriceClient)
        self.portfolioSnapshotStore = portfolioSnapshotStore ?? PortfolioSnapshotStore()
        self.costBasisStore = costBasisStore ?? CostBasisStore()
        self.pusdCirculationClient = pusdCirculationClient ?? PUSDCirculationClient()
        self.jupiterQuoteClient = jupiterQuoteClient ?? JupiterQuoteClient()
        self.jupiterSwapClient = jupiterSwapClient ?? JupiterSwapClient()
        self.orcaHelperBridge = orcaHelperBridge ?? OrcaHelperBridge.liveDefault()
        self.derivationService = SolanaDerivationService(mnemonicService: mnemonicService)
        self.rpcHealthSnapshot = .unchecked(network: .devnet, configuration: rpcClient.configuration)
        let policy = securitySettingsStore.loadPolicy()
        self.securityPolicy = policy
        self.authenticationStatusMessage = localAuthenticationService.statusDescription
        self.lockController = WalletLockController(policy: policy)
        loadMetadata()
        rpcHealthSnapshot = .unchecked(network: selectedNetwork, configuration: rpcClient.configuration)
        auditEvents = auditLog.loadRecent()
        portfolioHistory = Array(self.portfolioSnapshotStore.load().reversed())
        costBasisEntries = self.costBasisStore.load()
        refreshPnLSummary()
        refreshVaultState()
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
        portfolioSummary = .empty(scope: selectedPortfolioScope, network: selectedNetwork)
        portfolioStatus = .idle
        portfolioErrorMessage = nil
        resetSwapState()
        resetOrcaHarvestState()
        refreshVaultState()
        refreshPnLSummary()
    }

    func setNetwork(_ network: WalletNetwork) {
        noteUserActivity()
        selectedNetwork = network
        rpcHealthSnapshot = .unchecked(network: network, configuration: rpcFastConfiguration)
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
        portfolioSummary = .empty(scope: selectedPortfolioScope, network: selectedNetwork)
        portfolioStatus = .idle
        portfolioErrorMessage = nil
        resetSwapState()
        resetOrcaHarvestState()
        refreshPnLSummary()
    }

    func refreshRPCProviderHealth() async {
        noteUserActivity()
        let snapshot = await rpcHealthChecker.check(network: selectedNetwork)
        rpcHealthSnapshot = snapshot

        let kind: AuditEvent.Kind = {
            switch snapshot.status {
            case .healthy:
                return .rpcProviderHealthChecked
            case .degraded, .unavailable:
                return .rpcProviderDegraded
            case .tokenMissing:
                return .rpcProviderTokenMissing
            case .unchecked:
                return .rpcProviderHealthChecked
            }
        }()

        record(
            kind: kind,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: rpcHealthAuditMessage(for: snapshot),
            details: [
                "provider": snapshot.provider.rawValue,
                "network": snapshot.network.rawValue,
                "status": snapshot.status.rawValue,
                "httpHost": snapshot.httpEndpointHost,
                "webSocketHost": snapshot.webSocketEndpointHost,
                "tokenStatus": snapshot.tokenStatus.rawValue,
                "latencyMilliseconds": snapshot.latencyMilliseconds.map(String.init) ?? "unavailable",
                "slot": snapshot.slot.map(String.init) ?? "unavailable",
                "blockHeight": snapshot.blockHeight.map(String.init) ?? "unavailable",
                "beamStatus": snapshot.beamStatus
            ]
        )
    }

    func setPortfolioScope(_ scope: PortfolioWalletScope) {
        noteUserActivity()
        selectedPortfolioScope = scope
        portfolioSummary = .empty(scope: scope, network: selectedNetwork)
        refreshPnLSummary()
        portfolioStatus = .idle
        portfolioErrorMessage = nil
    }


    func createWallet(label: String) {
        runSensitiveOperation {
            let keypair = try SolanaKeypair.generate()
            let profile = WalletProfile(
                label: label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "KeySlot Wallet" : label,
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
                label: label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "KeySlot Wallet" : label,
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


    func addWatchOnlyWallet(label: String, publicAddress: String, tag: String?) {
        noteUserActivity()
        let address = publicAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SolanaAddressValidator.isValidAddress(address) else {
            statusMessage = "Watch-only address is not a valid Solana public key."
            return
        }
        guard !profiles.contains(where: { $0.publicAddress == address && $0.profileKind == .watchOnly }) else {
            statusMessage = "This watch-only address is already tracked."
            return
        }

        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = WalletProfile(
            label: trimmedLabel.isEmpty ? "Watch \(address.shortAddress)" : trimmedLabel,
            publicAddress: address,
            selectedNetwork: selectedNetwork,
            walletOrigin: .watchOnly,
            profileKind: .watchOnly,
            colorTag: trimmedTag?.isEmpty == false ? trimmedTag : nil
        )

        profiles.append(profile)
        selectedWalletID = profile.id
        saveMetadata()
        refreshVaultState()
        record(
            kind: .watchOnlyWalletAdded,
            walletID: profile.id,
            publicAddress: profile.publicAddress,
            message: "Watch-only wallet added.",
            details: [
                "profileKind": profile.profileKind.rawValue,
                "tag": profile.colorTag ?? ""
            ]
        )
        statusMessage = "Watch-only wallet added."
    }

    func updateWalletLabel(profileID: UUID, label: String, tag: String? = nil) {
        noteUserActivity()
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else {
            return
        }

        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else {
            statusMessage = "Wallet label cannot be empty."
            return
        }

        profiles[index].label = trimmedLabel
        profiles[index].accounts = profiles[index].accounts.map {
            WalletAccount(id: $0.id, publicAddress: $0.publicAddress, label: trimmedLabel, derivationPath: $0.derivationPath)
        }
        let trimmedTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines)
        profiles[index].colorTag = trimmedTag?.isEmpty == false ? trimmedTag : nil
        profiles[index].lastUsedAt = Date()
        saveMetadata()
        let updated = profiles[index]
        record(
            kind: .walletLabelUpdated,
            walletID: updated.id,
            publicAddress: updated.publicAddress,
            message: "Wallet label updated.",
            details: [
                "profileKind": updated.profileKind.rawValue,
                "tag": updated.colorTag ?? ""
            ]
        )
        statusMessage = "Wallet label updated."
    }

    func removeWatchOnlyWallet(profileID: UUID, confirmation: String) {
        noteUserActivity()
        guard confirmation == "REMOVE WATCH" else {
            statusMessage = "Type REMOVE WATCH to remove this watch-only address."
            return
        }
        guard let profile = profiles.first(where: { $0.id == profileID && $0.profileKind == .watchOnly }) else {
            statusMessage = "Only watch-only profiles can be removed here."
            return
        }

        profiles.removeAll { $0.id == profileID }
        if selectedWalletID == profileID {
            selectedWalletID = profiles.first?.id
        }
        saveMetadata()
        refreshVaultState()
        record(
            kind: .watchOnlyWalletRemoved,
            walletID: profile.id,
            publicAddress: profile.publicAddress,
            message: "Watch-only wallet removed.",
            details: ["profileKind": profile.profileKind.rawValue]
        )
        statusMessage = "Watch-only wallet removed."
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
        guard profile.canSign else {
            vaultState = .missing
            statusMessage = "Watch-only wallets cannot be unlocked or used for signing."
            return
        }

        guard await authenticateIfNeeded(
            required: securityPolicy.requireLocalAuthenticationForUnlock,
            reason: "Unlock the local KeySlot wallet signer."
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
        if profile.profileKind == .watchOnly {
            removeWatchOnlyWallet(profileID: profile.id, confirmation: confirmation == "DELETE WALLET" ? "REMOVE WATCH" : confirmation)
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
            recordRPCInfrastructureErrorIfNeeded(error)
            record(
                kind: .tokenTransferFailed,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Token balance refresh failed.",
                details: ["error": error.localizedDescription]
            )
        }
    }

    func refreshPortfolio() async {
        noteUserActivity()
        guard !profiles.isEmpty else {
            portfolioSummary = .empty(scope: selectedPortfolioScope, network: selectedNetwork)
            portfolioStatus = .idle
            portfolioErrorMessage = "No wallet is configured."
            return
        }

        portfolioStatus = .loading
        portfolioErrorMessage = nil
        isBusy = true
        defer { isBusy = false }

        let result = await portfolioRefreshService.refresh(
            scope: selectedPortfolioScope,
            selectedWalletID: selectedWalletID,
            profiles: profiles,
            network: selectedNetwork
        )

        portfolioSummary = result.summary
        portfolioStatus = result.summary.status
        portfolioErrorMessage = result.summary.errorMessage
        if selectedPortfolioScope == .activeWallet,
           let walletSummary = result.summary.wallets.first,
           walletSummary.id == selectedWalletID {
            if let solAsset = walletSummary.assets.first(where: { $0.asset.isNativeSOL })?.asset {
                balance = WalletBalance(
                    lamports: solAsset.amountRaw,
                    network: selectedNetwork,
                    fetchedAt: result.summary.refreshedAt,
                    errorMessage: nil
                )
            }
        }

        record(
            kind: selectedPortfolioScope == .activeWallet ? .portfolioRefreshed : .multiWalletPortfolioRefreshed,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "Portfolio refreshed with read-only balances and prices.",
            details: [
                "network": selectedNetwork.rawValue,
                "portfolioScope": selectedPortfolioScope.rawValue,
                "walletCount": "\(result.summary.wallets.count)",
                "assetCount": "\(result.summary.assetCount)",
                "stakeAccountCount": "\(result.summary.nativeStakeSummary.accountCount)",
                "lstHoldingCount": "\(result.summary.lstSummary.holdingCount)",
                "lendingPositionCount": "\(result.summary.lendingSummary.positionCount)",
                "lendingPartialAdapterCount": "\(result.summary.lendingSummary.partialAdapterCount)",
                "lendingUnavailableAdapterCount": "\(result.summary.lendingSummary.unavailableAdapterCount)",
                "lpPositionCount": "\(result.summary.lpSummary.positionCount)",
                "lpPartialAdapterCount": "\(result.summary.lpSummary.partialAdapterCount)",
                "lpUnavailableAdapterCount": "\(result.summary.lpSummary.unavailableAdapterCount)",
                "pusdAmountRaw": "\(result.summary.pusdTreasurySummary.totalAmountRaw)",
                "pusdWalletCount": "\(result.summary.pusdTreasurySummary.holdingWalletCount)",
                "pusdPriceSource": result.summary.pusdTreasurySummary.priceSource.rawValue,
                "yieldHeldOpportunityCount": "\(result.summary.yieldSummary.heldOpportunityCount)",
                "yieldAPYAvailableCount": "\(result.summary.yieldSummary.apyAvailableCount)",
                "yieldUnavailableCount": "\(result.summary.yieldSummary.unavailableCount)",
                "unavailablePriceCount": "\(result.summary.unavailablePriceCount)",
                "priceSource": result.summary.priceSource
            ]
        )

        if result.summary.pusdTreasurySummary.hasBalance {
            record(
                kind: .pusdPortfolioRefreshed,
                walletID: selectedWalletID,
                publicAddress: selectedProfile?.publicAddress,
                message: "PUSD treasury balances refreshed from read-only SPL accounts.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "portfolioScope": selectedPortfolioScope.rawValue,
                    "pusdAmountRaw": "\(result.summary.pusdTreasurySummary.totalAmountRaw)",
                    "pusdWalletCount": "\(result.summary.pusdTreasurySummary.holdingWalletCount)",
                    "pusdWatchOnlyAmountRaw": "\(result.summary.pusdTreasurySummary.watchOnlyAmountRaw)",
                    "pusdWatchOnlyWalletCount": "\(result.summary.pusdTreasurySummary.watchOnlyWalletCount)",
                    "pusdPriceSource": result.summary.pusdTreasurySummary.priceSource.rawValue
                ]
            )
        }

        record(
            kind: result.summary.nativeStakeSummary.errorMessage?.isEmpty == false ? .stakeRefreshFailed : .stakeAccountsRefreshed,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: result.summary.nativeStakeSummary.errorMessage?.isEmpty == false
                ? "Stake account refresh failed or partially failed."
                : "Stake accounts refreshed with read-only RPC.",
            details: [
                "network": selectedNetwork.rawValue,
                "portfolioScope": selectedPortfolioScope.rawValue,
                "stakeAccountCount": "\(result.summary.nativeStakeSummary.accountCount)",
                "activeStakeLamports": "\(result.summary.nativeStakeSummary.activeLamports)",
                "deactivatingStakeLamports": "\(result.summary.nativeStakeSummary.deactivatingLamports)",
                "source": result.summary.nativeStakeSummary.source
            ]
        )

        record(
            kind: result.summary.lstSummary.priceUnavailableCount > 0 ? .lstDataUnavailable : .lstComparisonRefreshed,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: result.summary.lstSummary.priceUnavailableCount > 0
                ? "LST comparison refreshed with unavailable price data."
                : "LST comparison refreshed.",
            details: [
                "network": selectedNetwork.rawValue,
                "portfolioScope": selectedPortfolioScope.rawValue,
                "lstHoldingCount": "\(result.summary.lstSummary.holdingCount)",
                "lstPriceUnavailableCount": "\(result.summary.lstSummary.priceUnavailableCount)",
                "source": result.summary.lstSummary.dataSource
            ]
        )

        let lendingStatus = result.summary.lendingSummary.status
        let lendingProtocolStatuses = result.summary.lendingSummary.protocols
            .map { "\($0.protocolKind.rawValue):\($0.status.rawValue)" }
            .joined(separator: ",")
        record(
            kind: lendingAuditKind(for: lendingStatus),
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: lendingAuditMessage(for: lendingStatus),
            details: [
                "network": selectedNetwork.rawValue,
                "portfolioScope": selectedPortfolioScope.rawValue,
                "lendingPositionCount": "\(result.summary.lendingSummary.positionCount)",
                "lendingRiskyPositionCount": "\(result.summary.lendingSummary.riskyPositionCount)",
                "lendingPartialAdapterCount": "\(result.summary.lendingSummary.partialAdapterCount)",
                "lendingSuppliedPositionCount": "\(result.summary.lendingSummary.suppliedPositionCount)",
                "lendingBorrowedPositionCount": "\(result.summary.lendingSummary.borrowedPositionCount)",
                "lendingUnavailableAdapterCount": "\(result.summary.lendingSummary.unavailableAdapterCount)",
                "lendingMarketReserveCount": "\(result.summary.lendingSummary.marketReserveCount)",
                "lendingProtocolStatuses": lendingProtocolStatuses,
                "status": result.summary.lendingSummary.status.rawValue,
                "source": result.summary.lendingSummary.source
            ]
        )

        let lpStatus = result.summary.lpSummary.status
        let lpProtocolStatuses = result.summary.lpSummary.protocols
            .map { "\($0.protocolKind.rawValue):\($0.status.rawValue)" }
            .joined(separator: ",")
        record(
            kind: lpAuditKind(for: lpStatus, protocols: result.summary.lpSummary.protocols),
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: lpAuditMessage(for: lpStatus),
            details: [
                "network": selectedNetwork.rawValue,
                "portfolioScope": selectedPortfolioScope.rawValue,
                "lpPositionCount": "\(result.summary.lpSummary.positionCount)",
                "lpPartialAdapterCount": "\(result.summary.lpSummary.partialAdapterCount)",
                "lpPartialPositionCount": "\(result.summary.lpSummary.partialPositionCount)",
                "lpUnavailableAdapterCount": "\(result.summary.lpSummary.unavailableAdapterCount)",
                "lpProtocolStatuses": lpProtocolStatuses,
                "status": result.summary.lpSummary.status.rawValue,
                "source": result.summary.lpSummary.source
            ]
        )

        record(
            kind: result.summary.yieldSummary.unavailableCount > 0 ? .yieldSourceUnavailable : .yieldComparisonRefreshed,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: result.summary.yieldSummary.unavailableCount > 0
                ? "Yield comparison refreshed with unavailable rate sources."
                : "Yield comparison refreshed.",
            details: [
                "network": selectedNetwork.rawValue,
                "portfolioScope": selectedPortfolioScope.rawValue,
                "yieldStatus": result.summary.yieldSummary.status.rawValue,
                "yieldHoldingCount": "\(result.summary.yieldSummary.holdings.count)",
                "yieldHeldOpportunityCount": "\(result.summary.yieldSummary.heldOpportunityCount)",
                "yieldAPYAvailableCount": "\(result.summary.yieldSummary.apyAvailableCount)",
                "yieldUnavailableCount": "\(result.summary.yieldSummary.unavailableCount)",
                "yieldTopSource": result.summary.yieldSummary.topYieldSourceLabel ?? "",
                "source": result.summary.yieldSummary.source
            ]
        )

        if let priceError = result.priceErrorMessage {
            record(
                kind: .portfolioPriceRefreshFailed,
                walletID: selectedWalletID,
                publicAddress: selectedProfile?.publicAddress,
                message: "Portfolio price refresh failed; balances remain visible.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "portfolioScope": selectedPortfolioScope.rawValue,
                    "error": priceError
                ]
            )
        }

        let snapshot = PortfolioSnapshot(summary: result.summary)
        do {
            portfolioHistory = Array(try portfolioSnapshotStore.append(snapshot).reversed())
            refreshPnLSummary()
            record(
                kind: .portfolioSnapshotStored,
                walletID: selectedWalletID,
                publicAddress: selectedProfile?.publicAddress,
                message: "Portfolio snapshot stored locally.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "portfolioScope": selectedPortfolioScope.rawValue,
                    "assetCount": "\(snapshot.assetCount)",
                    "stakeAccountCount": "\(snapshot.stakeAccountCount)",
                        "lstHoldingCount": "\(snapshot.lstHoldingCount)",
                        "lendingPositionCount": "\(snapshot.lendingPositionCount)",
                        "lendingPartialAdapterCount": "\(snapshot.lendingPartialAdapterCount)",
                        "lendingUnavailableAdapterCount": "\(snapshot.lendingUnavailableAdapterCount)",
                        "lendingMarketReserveCount": "\(snapshot.lendingMarketReserveCount)",
                    "lpPositionCount": "\(snapshot.lpPositionCount)",
                    "lpPartialAdapterCount": "\(snapshot.lpPartialAdapterCount)",
                    "lpUnavailableAdapterCount": "\(snapshot.lpUnavailableAdapterCount)",
                    "pusdAmountRaw": "\(snapshot.pusdTotalAmountRaw)",
                    "pusdWalletCount": "\(snapshot.pusdHoldingWalletCount)",
                    "pusdPriceSource": snapshot.pusdPriceSource,
                    "yieldHeldOpportunityCount": "\(snapshot.yieldHeldOpportunityCount)",
                    "yieldAPYAvailableCount": "\(snapshot.yieldAPYAvailableCount)",
                    "yieldUnavailableCount": "\(snapshot.yieldUnavailableCount)",
                    "yieldTopSource": snapshot.yieldTopSourceLabel ?? "",
                    "lendingProtocolStatuses": snapshot.lendingProtocolStatuses
                        .map { "\($0.key):\($0.value)" }
                        .sorted()
                        .joined(separator: ","),
                    "lpProtocolStatuses": snapshot.lpProtocolStatuses
                        .map { "\($0.key):\($0.value)" }
                        .sorted()
                        .joined(separator: ","),
                    "unavailablePriceCount": "\(snapshot.unavailablePriceCount)",
                    "priceSource": snapshot.priceSource
                ]
            )
            record(
                kind: .lendingSnapshotStored,
                walletID: selectedWalletID,
                publicAddress: selectedProfile?.publicAddress,
                message: "Portfolio lending snapshot summary stored locally.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "portfolioScope": selectedPortfolioScope.rawValue,
                    "lendingPositionCount": "\(snapshot.lendingPositionCount)",
                    "lendingRiskyPositionCount": "\(snapshot.lendingRiskyPositionCount)",
                    "lendingPartialAdapterCount": "\(snapshot.lendingPartialAdapterCount)",
                    "lendingSuppliedPositionCount": "\(snapshot.lendingSuppliedPositionCount)",
                    "lendingBorrowedPositionCount": "\(snapshot.lendingBorrowedPositionCount)",
                    "lendingUnavailableAdapterCount": "\(snapshot.lendingUnavailableAdapterCount)",
                    "lendingMarketReserveCount": "\(snapshot.lendingMarketReserveCount)",
                    "lendingProtocolStatuses": snapshot.lendingProtocolStatuses
                        .map { "\($0.key):\($0.value)" }
                        .sorted()
                        .joined(separator: ",")
                ]
            )
            record(
                kind: .lpSnapshotStored,
                walletID: selectedWalletID,
                publicAddress: selectedProfile?.publicAddress,
                message: "Portfolio LP snapshot summary stored locally.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "portfolioScope": selectedPortfolioScope.rawValue,
                    "lpPositionCount": "\(snapshot.lpPositionCount)",
                    "lpPartialAdapterCount": "\(snapshot.lpPartialAdapterCount)",
                    "lpPartialPositionCount": "\(snapshot.lpPartialPositionCount)",
                    "lpUnavailableAdapterCount": "\(snapshot.lpUnavailableAdapterCount)",
                    "lpProtocolStatuses": snapshot.lpProtocolStatuses
                        .map { "\($0.key):\($0.value)" }
                        .sorted()
                        .joined(separator: ",")
                ]
            )
            record(
                kind: .yieldSnapshotStored,
                walletID: selectedWalletID,
                publicAddress: selectedProfile?.publicAddress,
                message: "Portfolio yield comparison snapshot summary stored locally.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "portfolioScope": selectedPortfolioScope.rawValue,
                    "yieldExposureUSD": snapshot.yieldExposureUSD.map(String.init(describing:)) ?? "",
                    "yieldHeldOpportunityCount": "\(snapshot.yieldHeldOpportunityCount)",
                    "yieldAPYAvailableCount": "\(snapshot.yieldAPYAvailableCount)",
                    "yieldUnavailableCount": "\(snapshot.yieldUnavailableCount)",
                    "yieldTopSource": snapshot.yieldTopSourceLabel ?? ""
                ]
            )
            record(
                kind: .pnlSnapshotGenerated,
                walletID: selectedWalletID,
                publicAddress: selectedProfile?.publicAddress,
                message: "Portfolio PnL snapshot generated from local portfolio history.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "portfolioScope": selectedPortfolioScope.rawValue,
                    "pnlStatus": portfolioPnLSummary.status.rawValue,
                    "pnlTimeframe": portfolioPnLSummary.primaryTimeframe.rawValue,
                    "pnlHistoryPointCount": "\(portfolioPnLSummary.historyPointCount)",
                    "pnlAssetPerformanceCount": "\(portfolioPnLSummary.assetPerformances.count)",
                    "pnlWalletPerformanceCount": "\(portfolioPnLSummary.walletPerformances.count)",
                    "costBasisEntryCount": "\(portfolioPnLSummary.costBasisCoverage.entryCount)",
                    "costBasisMissingAssetCount": "\(portfolioPnLSummary.costBasisCoverage.missingAssetCount)",
                    "swapActivityHintCount": "\(portfolioPnLSummary.swapActivityHintCount)",
                    "source": portfolioPnLSummary.source.rawValue
                ]
            )
            record(
                kind: .pnlRefreshed,
                walletID: selectedWalletID,
                publicAddress: selectedProfile?.publicAddress,
                message: "Portfolio PnL refreshed with snapshot-based estimates.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "portfolioScope": selectedPortfolioScope.rawValue,
                    "pnlStatus": portfolioPnLSummary.status.rawValue,
                    "pnlTimeframe": portfolioPnLSummary.primaryTimeframe.rawValue,
                    "realizedStatus": portfolioPnLSummary.realized.status.rawValue,
                    "unrealizedStatus": portfolioPnLSummary.unrealized.status.rawValue,
                    "source": portfolioPnLSummary.source.rawValue
                ]
            )
            if snapshot.stakeAccountCount > 0 || snapshot.lstHoldingCount > 0 {
                record(
                    kind: .portfolioStakeSnapshotStored,
                    walletID: selectedWalletID,
                    publicAddress: selectedProfile?.publicAddress,
                    message: "Portfolio stake and LST snapshot summary stored locally.",
                    details: [
                        "network": selectedNetwork.rawValue,
                        "portfolioScope": selectedPortfolioScope.rawValue,
                        "nativeStakeLamports": "\(snapshot.nativeStakeLamports)",
                        "stakeAccountCount": "\(snapshot.stakeAccountCount)",
                        "lstHoldingCount": "\(snapshot.lstHoldingCount)"
                    ]
                )
            }
        } catch {
            portfolioErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
        }

        statusMessage = "Portfolio refreshed."
    }

    func refreshPUSDCirculation(forceRefresh: Bool = false) async {
        pusdCirculationSnapshot = .loading()
        let snapshot = await pusdCirculationClient.fetchCirculation(forceRefresh: forceRefresh)
        pusdCirculationSnapshot = snapshot

        let success = snapshot.status == .loaded
        record(
            kind: success ? .pusdCirculationRefreshed : .pusdCirculationUnavailable,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: success
                ? "PUSD circulation data refreshed from the public Palm USD API."
                : "PUSD circulation data is unavailable.",
            details: [
                "network": selectedNetwork.rawValue,
                "pusdCirculationStatus": snapshot.status.rawValue,
                "pusdTotalCirculating": snapshot.totalCirculating.map(String.init(describing:)) ?? "",
                "pusdSolanaCirculating": snapshot.solanaCirculating.map(String.init(describing:)) ?? "",
                "pusdChainCount": "\(snapshot.chainTotals.count)",
                "source": snapshot.source,
                "error": snapshot.errorMessage ?? ""
            ]
        )
    }

    func recordPUSDTreasuryViewed() {
        record(
            kind: .pusdTreasuryViewed,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "PUSD treasury panel viewed.",
            details: [
                "network": selectedNetwork.rawValue,
                "portfolioScope": selectedPortfolioScope.rawValue,
                "pusdAmountRaw": "\(portfolioSummary.pusdTreasurySummary.totalAmountRaw)",
                "pusdWalletCount": "\(portfolioSummary.pusdTreasurySummary.holdingWalletCount)",
                "pusdPriceSource": portfolioSummary.pusdTreasurySummary.priceSource.rawValue
            ]
        )
    }

    func recordPUSDReceiveViewed() {
        record(
            kind: .pusdReceiveViewed,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "PUSD receive/payment request details viewed.",
            details: [
                "network": selectedNetwork.rawValue,
                "mint": PUSDConstants.mintAddress,
                "tokenSymbol": PUSDConstants.symbol
            ]
        )
    }

    func recordYieldPanelViewed() {
        record(
            kind: .yieldPanelViewed,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "Yield comparison panel viewed.",
            details: [
                "network": selectedNetwork.rawValue,
                "portfolioScope": selectedPortfolioScope.rawValue,
                "yieldStatus": portfolioSummary.yieldSummary.status.rawValue,
                "yieldHoldingCount": "\(portfolioSummary.yieldSummary.holdings.count)",
                "yieldHeldOpportunityCount": "\(portfolioSummary.yieldSummary.heldOpportunityCount)",
                "yieldAPYAvailableCount": "\(portfolioSummary.yieldSummary.apyAvailableCount)",
                "yieldUnavailableCount": "\(portfolioSummary.yieldSummary.unavailableCount)"
            ]
        )
    }

    func recordPnLPanelViewed() {
        record(
            kind: .pnlPanelViewed,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: "Portfolio PnL panel viewed.",
            details: [
                "network": selectedNetwork.rawValue,
                "portfolioScope": selectedPortfolioScope.rawValue,
                "pnlStatus": portfolioPnLSummary.status.rawValue,
                "pnlTimeframe": portfolioPnLSummary.primaryTimeframe.rawValue,
                "pnlHistoryPointCount": "\(portfolioPnLSummary.historyPointCount)",
                "costBasisEntryCount": "\(portfolioPnLSummary.costBasisCoverage.entryCount)",
                "costBasisMissingAssetCount": "\(portfolioPnLSummary.costBasisCoverage.missingAssetCount)",
                "swapActivityHintCount": "\(portfolioPnLSummary.swapActivityHintCount)"
            ]
        )
    }

    func upsertCostBasisEntry(_ entry: CostBasisEntry) {
        do {
            let existed = costBasisEntries.contains { $0.id == entry.id }
            costBasisEntries = try costBasisStore.upsert(entry)
            refreshPnLSummary()
            record(
                kind: existed ? .costBasisEntryUpdated : .costBasisEntryAdded,
                walletID: selectedWalletID,
                publicAddress: selectedProfile?.publicAddress,
                message: existed ? "Local cost basis entry updated." : "Local cost basis entry added.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "portfolioScope": selectedPortfolioScope.rawValue,
                    "tokenMint": entry.tokenMint,
                    "tokenSymbol": entry.tokenSymbol ?? "",
                    "costBasisMethod": entry.method.rawValue,
                    "costBasisEntryCount": "\(costBasisEntries.count)"
                ]
            )
        } catch {
            portfolioErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
        }
    }

    func removeCostBasisEntry(id: UUID) {
        do {
            costBasisEntries = try costBasisStore.remove(id: id)
            refreshPnLSummary()
            record(
                kind: .costBasisEntryRemoved,
                walletID: selectedWalletID,
                publicAddress: selectedProfile?.publicAddress,
                message: "Local cost basis entry removed.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "portfolioScope": selectedPortfolioScope.rawValue,
                    "costBasisEntryCount": "\(costBasisEntries.count)"
                ]
            )
        } catch {
            portfolioErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
        }
    }

    private func refreshPnLSummary() {
        portfolioPnLSummary = PnLCalculator.calculate(
            currentSummary: portfolioSummary,
            snapshots: portfolioHistory,
            costBasisEntries: costBasisEntries,
            swapActivityHints: PnLActivityMapper.swapHints(from: auditEvents)
        )
    }

    private func lendingAuditKind(for status: LendingAdapterStatus) -> AuditEvent.Kind {
        switch status {
        case .error:
            return .lendingAdapterError
        case .unavailable:
            return .lendingAdapterUnavailable
        case .idle, .loaded, .empty, .partial, .stale:
            return .lendingRefreshed
        }
    }

    private func lendingAuditMessage(for status: LendingAdapterStatus) -> String {
        switch status {
        case .loaded:
            return "Lending positions refreshed read-only."
        case .empty:
            return "Lending adapters returned no positions."
        case .unavailable:
            return "Lending adapters are unavailable; no positions are shown."
        case .error:
            return "Lending adapter refresh failed."
        case .partial:
            return "Lending positions refreshed with partial read-only parser data."
        case .stale:
            return "Lending positions refreshed with stale or partial data."
        case .idle:
            return "Lending dashboard is idle."
        }
    }

    private func rpcHealthAuditMessage(for snapshot: RPCHealthSnapshot) -> String {
        switch snapshot.status {
        case .healthy:
            return "RPC Fast health check succeeded."
        case .degraded:
            return "RPC Fast health check reported degraded service."
        case .unavailable:
            return "RPC Fast health check failed."
        case .tokenMissing:
            return "RPC Fast token is missing for the selected network."
        case .unchecked:
            return "RPC Fast health status is unchecked."
        }
    }

    private func recordRPCInfrastructureErrorIfNeeded(_ error: Error) {
        let normalized = RPCErrorNormalizer.normalize(error, configuration: rpcFastConfiguration)
        let kind: AuditEvent.Kind?
        switch normalized.category {
        case .tokenMissing, .unauthorized:
            kind = .rpcProviderTokenMissing
        case .rateLimited:
            kind = .rpcRateLimited
        case .planUpgradeRequired, .methodBlocked:
            kind = .rpcMethodBlocked
        case .timeout, .endpointUnavailable:
            kind = .rpcProviderDegraded
        case .invalidResponse, .unknown:
            kind = nil
        }

        guard let kind else {
            return
        }

        record(
            kind: kind,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: normalized.message,
            details: [
                "provider": RPCProviderKind.rpcFast.rawValue,
                "network": selectedNetwork.rawValue,
                "errorCategory": normalized.category.rawValue,
                "httpHost": rpcFastEndpoint.httpHost,
                "webSocketHost": rpcFastEndpoint.webSocketHost,
                "tokenStatus": rpcFastConfiguration.tokenStatus(for: selectedNetwork).rawValue,
                "beamStatus": RPCFastConfiguration.beamStatus
            ]
        )
    }

    private func lpAuditKind(for status: LPAdapterStatus, protocols: [LPProtocolSummary]) -> AuditEvent.Kind {
        if protocols.contains(where: { $0.protocolKind == .meteora && $0.status == .loaded }) {
            return .meteoraPositionsLoaded
        }
        switch status {
        case .unavailable:
            return .meteoraAdapterUnavailable
        case .idle, .loaded, .empty, .partial, .error, .stale:
            return .lpPositionsRefreshed
        }
    }

    private func lpAuditMessage(for status: LPAdapterStatus) -> String {
        switch status {
        case .loaded:
            return "LP positions refreshed read-only."
        case .empty:
            return "LP adapters returned no positions."
        case .partial:
            return "LP positions refreshed with partial read-only adapter data."
        case .unavailable:
            return "LP adapters are unavailable; no positions are shown."
        case .error:
            return "LP adapter refresh failed."
        case .stale:
            return "LP positions refreshed with stale or partial data."
        case .idle:
            return "LP tracker is idle."
        }
    }

    func clearPortfolioHistory(confirmation: String) {
        noteUserActivity()
        guard confirmation == "CLEAR HISTORY" else {
            statusMessage = "Type CLEAR HISTORY to remove local portfolio snapshots."
            return
        }

        do {
            try portfolioSnapshotStore.clear()
            portfolioHistory = []
            refreshPnLSummary()
            record(
                kind: .portfolioHistoryCleared,
                walletID: selectedWalletID,
                publicAddress: selectedProfile?.publicAddress,
                message: "Portfolio snapshot history cleared from this Mac.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "portfolioScope": selectedPortfolioScope.rawValue
                ]
            )
            statusMessage = "Portfolio history cleared."
        } catch {
            portfolioErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
        }
    }

    func resetSwapState() {
        currentSwapQuote = nil
        currentSwapBuild = nil
        currentSwapReview = nil
        swapSimulationResult = nil
        swapApprovalState = .idle
        swapErrorMessage = nil
        preparedSwapFingerprint = nil
        lastSwapSignature = nil
        lastSwapConfirmationStatus = nil
        swapPreflightBalances = [:]
        swapBalanceDeltaVerification = .notStarted
    }

    func resetOrcaHarvestState() {
        currentOrcaHarvestDraft = nil
        currentOrcaHarvestReview = nil
        orcaHarvestSimulationResult = nil
        orcaHarvestApprovalState = .idle
        orcaHarvestErrorMessage = nil
        lastOrcaHarvestSignature = nil
        preparedOrcaHarvestMessage = nil
        preparedOrcaHarvestFingerprint = nil
    }

    func prepareOrcaHarvest(position: LPPositionSummary) async {
        noteUserActivity()
        guard let profile = selectedProfile else {
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            guard selectedNetwork == .mainnetBeta else {
                throw OrcaHarvestError.invalidPosition("Orca harvest execution is mainnet-beta only.")
            }
            guard profile.canSign else {
                throw OrcaHarvestError.invalidPosition("Watch-only wallets cannot harvest Orca LP fees or rewards.")
            }
            guard position.protocolKind == .orca else {
                throw OrcaHarvestError.invalidPosition("Harvest is only enabled for Orca LP positions in this phase.")
            }
            guard position.walletID == profile.id,
                  position.walletPublicAddress == profile.publicAddress else {
                throw OrcaHarvestError.invalidPosition("Selected Orca LP position does not belong to the active wallet.")
            }
            let plan = try await orcaHelperBridge.buildHarvestPlan(position: position, network: selectedNetwork)
            let positionMint = try resolvedOrcaPositionMint(position: position, plan: plan)
            let draft = OrcaHarvestDraft(
                walletID: profile.id,
                walletPublicAddress: profile.publicAddress,
                network: selectedNetwork,
                positionMint: positionMint,
                positionAddress: position.positionAddress,
                poolAddress: plan.poolAddress ?? position.poolAddress,
                plan: plan
            )
            let blockhash = try await rpcClient.getLatestBlockhash(network: selectedNetwork)
            let message = try SolanaTransactionBuilder.makeInstructionProposalMessage(
                feePayer: profile.publicAddress,
                recentBlockhash: blockhash,
                instructions: try solanaInstructionProposals(plan.instructions)
            )
            let unsignedBase64 = SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message)
            let review = try OrcaHarvestReviewer.review(
                draft: draft,
                serializedTransactionBase64: unsignedBase64,
                expectedWallet: profile.publicAddress
            )

            currentOrcaHarvestDraft = draft
            currentOrcaHarvestReview = review
            orcaHarvestSimulationResult = nil
            preparedOrcaHarvestMessage = nil
            preparedOrcaHarvestFingerprint = nil
            orcaHarvestErrorMessage = review.canApprove ? nil : review.blockingReasons.joined(separator: " ")
            orcaHarvestApprovalState = review.canApprove ? .drafted : .failed(review.blockingReasons.joined(separator: " "))
            record(
                kind: .orcaHarvestPlanCreated,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Orca harvest plan created and reviewed.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "positionMint": positionMint,
                    "poolAddress": draft.poolAddress,
                    "instructionCount": "\(review.instructionCount)",
                    "writableAccountCount": "\(review.writableAccountCount)",
                    "warningCount": "\(review.warnings.count)",
                    "blockingReasonsCount": "\(review.blockingReasons.count)"
                ]
            )
            statusMessage = review.canApprove ? "Orca harvest plan reviewed." : "Orca harvest review blocked approval."
        } catch {
            orcaHarvestApprovalState = .failed(error.localizedDescription)
            orcaHarvestErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
            recordOrcaHarvestFailure(kind: .orcaHarvestBlockedByGuard, message: error.localizedDescription)
        }
    }

    func simulateCurrentOrcaHarvest() async {
        noteUserActivity()
        guard let profile = selectedProfile,
              let draft = currentOrcaHarvestDraft,
              let review = currentOrcaHarvestReview else {
            orcaHarvestErrorMessage = "Build and review an Orca harvest plan before simulation."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            guard review.canApprove else {
                throw OrcaHarvestError.reviewFailed(review.blockingReasons.joined(separator: " "))
            }
            guard let message = Data(base64Encoded: review.messageBase64) else {
                throw OrcaHarvestError.signingBlocked("Prepared Orca harvest message is invalid.")
            }
            let transactionBase64 = SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message)
            let fee = try? await rpcClient.getFeeForMessage(messageBase64: review.messageBase64, network: draft.network)
            var result = try await rpcClient.simulateTransaction(transactionBase64: transactionBase64, network: draft.network)
            result.estimatedFeeLamports = fee ?? result.estimatedFeeLamports
            orcaHarvestSimulationResult = result

            if result.status == .success {
                preparedOrcaHarvestMessage = message
                preparedOrcaHarvestFingerprint = OrcaHarvestApprovalGuard.fingerprint(draft: draft)
                orcaHarvestApprovalState = .simulated
                record(
                    kind: .orcaHarvestSimulationPassed,
                    walletID: profile.id,
                    publicAddress: profile.publicAddress,
                    message: "Orca harvest transaction simulated.",
                    details: [
                        "network": draft.network.rawValue,
                        "positionMint": draft.positionMint,
                        "poolAddress": draft.poolAddress,
                        "status": result.status.rawValue,
                        "estimatedFeeLamports": "\(result.estimatedFeeLamports ?? 0)"
                    ]
                )
                statusMessage = "Orca harvest simulation succeeded."
            } else {
                let message = result.errorMessage ?? "Orca harvest simulation failed."
                orcaHarvestApprovalState = .failed(message)
                recordOrcaHarvestFailure(kind: .orcaHarvestSimulationFailed, message: message)
                statusMessage = message
            }
        } catch {
            orcaHarvestSimulationResult = .unavailable(error.localizedDescription)
            orcaHarvestApprovalState = .failed(error.localizedDescription)
            orcaHarvestErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
            recordOrcaHarvestFailure(kind: .orcaHarvestSimulationFailed, message: error.localizedDescription)
        }
    }

    func approveAndSendOrcaHarvest(
        mainnetConfirmation: String,
        hasCompletedDevnetSmoke: Bool
    ) async {
        guard let profile = selectedProfile,
              let draft = currentOrcaHarvestDraft,
              let review = currentOrcaHarvestReview else {
            return
        }

        enforceAutoLockIfNeeded()
        let currentFingerprint = OrcaHarvestApprovalGuard.fingerprint(draft: draft)
        do {
            try OrcaHarvestApprovalGuard.validate(OrcaHarvestApprovalContext(
                draft: draft,
                review: review,
                simulation: orcaHarvestSimulationResult,
                network: draft.network,
                walletPublicKey: profile.publicAddress,
                mainnetConfirmation: mainnetConfirmation,
                hasCompletedDevnetSmoke: hasCompletedDevnetSmoke,
                vaultState: vaultState,
                hasUnlockedSecret: unlockedSecrets[profile.id] != nil,
                hasPreparedMessage: preparedOrcaHarvestMessage != nil,
                currentFingerprint: currentFingerprint,
                preparedFingerprint: preparedOrcaHarvestFingerprint
            ))
        } catch {
            orcaHarvestApprovalState = .failed(error.localizedDescription)
            orcaHarvestErrorMessage = error.localizedDescription
            statusMessage = "Mainnet Orca harvest requires unlock, simulation, exact confirmation, and matching approval."
            recordOrcaHarvestFailure(kind: .orcaHarvestBlockedByGuard, message: error.localizedDescription)
            return
        }

        guard await authenticateIfNeeded(
            required: securityPolicy.requireLocalAuthenticationForSigning,
            reason: "Authorize local signing for this Orca harvest."
        ) else {
            orcaHarvestApprovalState = .failed("Device authentication failed.")
            return
        }

        guard let secret = unlockedSecrets[profile.id],
              let message = preparedOrcaHarvestMessage else {
            orcaHarvestApprovalState = .failed(WalletSigningPreflightError.missingPreparedMessage.localizedDescription)
            statusMessage = WalletSigningPreflightError.missingPreparedMessage.localizedDescription
            return
        }

        noteUserActivity()
        record(
            kind: .orcaHarvestApproved,
            walletID: profile.id,
            publicAddress: profile.publicAddress,
            message: "Orca harvest approved by user.",
            details: [
                "network": draft.network.rawValue,
                "positionMint": draft.positionMint,
                "poolAddress": draft.poolAddress,
                "instructionCount": "\(review.instructionCount)",
                "warningCount": "\(review.warnings.count)"
            ]
        )

        orcaHarvestApprovalState = .approved
        isBusy = true
        defer { isBusy = false }

        do {
            orcaHarvestApprovalState = .sending
            let signedTransactionBase64 = try SolanaTransactionBuilder.makeSignedTransactionBase64(
                message: message,
                seed: secret.seed
            )
            let signature = try await rpcClient.sendTransaction(
                transactionBase64: signedTransactionBase64,
                network: draft.network
            )
            lastTransactionSignature = signature
            lastOrcaHarvestSignature = signature
            let status = try? await waitForConfirmation(signature: signature, network: draft.network, timeoutSeconds: 20)
            lastConfirmationStatus = status?.confirmationStatus
            orcaHarvestApprovalState = .sent(signature)
            record(
                kind: .orcaHarvestSent,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                transactionSignature: signature,
                message: "Orca harvest sent.",
                details: [
                    "network": draft.network.rawValue,
                    "positionMint": draft.positionMint,
                    "poolAddress": draft.poolAddress,
                    "confirmationStatus": status?.confirmationStatus ?? ""
                ]
            )
            statusMessage = "Orca harvest sent."
        } catch {
            orcaHarvestApprovalState = .failed(error.localizedDescription)
            orcaHarvestErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
            recordOrcaHarvestFailure(kind: .orcaHarvestFailed, message: error.localizedDescription)
        }
    }

    func requestSwapQuote(
        inputMint: String,
        outputMint: String,
        amountText: String,
        slippageBps: Int
    ) async {
        noteUserActivity()
        guard let profile = selectedProfile else {
            swapErrorMessage = "Select a wallet before requesting a quote."
            return
        }
        guard profile.canSign else {
            swapErrorMessage = "Watch-only wallets cannot request executable swap quotes."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            if inputMint == SwapConstants.nativeSolMint, balance == nil {
                let lamports = try await rpcClient.getBalance(address: profile.publicAddress, network: selectedNetwork)
                balance = WalletBalance(lamports: lamports, network: selectedNetwork, fetchedAt: Date(), errorMessage: nil)
            }
            if inputMint != SwapConstants.nativeSolMint, tokenBalances.isEmpty {
                tokenBalances = try await rpcClient.getTokenBalances(ownerAddress: profile.publicAddress, network: selectedNetwork)
                tokenBalancesFetchedAt = Date()
            }

            guard let input = swapInputTokenOptions.first(where: { $0.mintAddress == inputMint }) else {
                throw SwapError.invalidInput("Input token is not available in this wallet.")
            }
            guard let decimals = input.decimals else {
                throw SwapError.invalidInput("Input token decimals are unavailable.")
            }
            let amountRaw = try TokenAmountFormatter.rawAmount(fromUIAmount: amountText, decimals: decimals)
            try SwapValidation.validateQuoteRequest(
                inputMint: inputMint,
                outputMint: outputMint.trimmingCharacters(in: .whitespacesAndNewlines),
                amountRaw: amountRaw,
                availableRaw: input.balanceRaw,
                inputDecimals: input.decimals,
                slippageBps: slippageBps
            )

            resetSwapState()
            swapApprovalState = .drafted
            record(
                kind: .swapQuoteRequested,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Jupiter swap quote requested.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "apiMode": jupiterSwapAPIMode.rawValue,
                    "inputMint": inputMint,
                    "outputMint": outputMint,
                    "amountRaw": "\(amountRaw)",
                    "slippageBps": "\(slippageBps)"
                ]
            )

            let quote = try await jupiterQuoteClient.fetchQuote(
                inputMint: inputMint,
                outputMint: outputMint.trimmingCharacters(in: .whitespacesAndNewlines),
                amountRaw: amountRaw,
                slippageBps: slippageBps,
                network: selectedNetwork
            )
            currentSwapQuote = quote
            swapErrorMessage = nil
            statusMessage = "Jupiter quote received."
            record(
                kind: .swapQuoteReceived,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Jupiter swap quote received.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "apiMode": jupiterSwapAPIMode.rawValue,
                    "inputMint": quote.inputMint,
                    "outputMint": quote.outputMint,
                    "amountRaw": "\(quote.inAmount)",
                    "expectedOutputRaw": "\(quote.outAmount)",
                    "minimumOutputRaw": "\(quote.otherAmountThreshold)",
                    "slippageBps": "\(quote.slippageBps)",
                    "route": quote.routeLabel
                ]
            )
        } catch {
            swapApprovalState = .failed(error.localizedDescription)
            swapErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
            recordSwapFailure(kind: .swapQuoteFailed, message: error.localizedDescription)
        }
    }

    func buildCurrentSwapTransaction() async {
        noteUserActivity()
        guard let profile = selectedProfile else {
            return
        }
        guard let quote = currentSwapQuote else {
            swapErrorMessage = SwapError.missingQuote.localizedDescription
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            guard !quote.isStale() else {
                throw SwapError.quoteStale
            }
            let build = try await jupiterSwapClient.buildSwapTransaction(
                quote: quote,
                userPublicKey: profile.publicAddress,
                network: selectedNetwork
            )
            let review = try SwapTransactionReviewer.review(
                serializedTransactionBase64: build.swapTransactionBase64,
                expectedWallet: profile.publicAddress
            )
            currentSwapBuild = build
            currentSwapReview = review
            swapSimulationResult = nil
            preparedSwapFingerprint = nil
            swapBalanceDeltaVerification = .notStarted
            swapApprovalState = review.canApprove ? .drafted : .failed(review.blockingReasons.joined(separator: " "))
            swapErrorMessage = review.canApprove ? nil : review.blockingReasons.joined(separator: " ")
            record(
                kind: .swapTransactionBuilt,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Jupiter swap transaction built and reviewed.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "inputMint": quote.inputMint,
                    "outputMint": quote.outputMint,
                    "amountRaw": "\(quote.inAmount)",
                    "expectedOutputRaw": "\(quote.outAmount)",
                    "transactionVersion": review.transactionVersion,
                    "feePayer": review.feePayer ?? "",
                    "programCount": "\(review.programSummaries.count)",
                    "warningsCount": "\(review.warnings.count)",
                    "riskWarningsCount": "\(review.riskWarnings.count)",
                    "blockingReasonsCount": "\(review.blockingReasons.count)"
                ]
            )
            statusMessage = review.canApprove ? "Swap transaction reviewed." : "Swap transaction review blocked approval."
        } catch {
            swapApprovalState = .failed(error.localizedDescription)
            swapErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
            recordSwapFailure(kind: .swapFailed, message: error.localizedDescription)
        }
    }

    func simulateCurrentSwap() async {
        noteUserActivity()
        guard let profile = selectedProfile,
              let quote = currentSwapQuote,
              let build = currentSwapBuild,
              let review = currentSwapReview else {
            swapErrorMessage = "Build and review the swap transaction before simulation."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            guard review.canApprove else {
                throw SwapError.reviewFailed(review.blockingReasons.joined(separator: " "))
            }
            let fee = try? await rpcClient.getFeeForMessage(messageBase64: review.messageBase64, network: selectedNetwork)
            var result = try await rpcClient.simulateTransaction(
                transactionBase64: build.swapTransactionBase64,
                network: selectedNetwork
            )
            result.estimatedFeeLamports = fee ?? result.estimatedFeeLamports
            swapSimulationResult = result
            if result.status == .success {
                preparedSwapFingerprint = SwapFingerprint.approvalFingerprint(quote: quote, build: build)
                swapApprovalState = .simulated
                record(
                    kind: .swapSimulationPassed,
                    walletID: profile.id,
                    publicAddress: profile.publicAddress,
                    message: "Jupiter swap transaction simulated.",
                    details: [
                        "network": selectedNetwork.rawValue,
                        "inputMint": quote.inputMint,
                        "outputMint": quote.outputMint,
                        "amountRaw": "\(quote.inAmount)",
                        "status": result.status.rawValue,
                        "estimatedFeeLamports": "\(result.estimatedFeeLamports ?? 0)"
                    ]
                )
                statusMessage = "Swap simulation succeeded."
            } else {
                swapApprovalState = .failed(result.errorMessage ?? "Swap simulation failed.")
                recordSwapFailure(kind: .swapSimulationFailed, message: result.errorMessage ?? "Swap simulation failed.")
                statusMessage = result.errorMessage ?? "Swap simulation failed."
            }
        } catch {
            swapSimulationResult = .unavailable(error.localizedDescription)
            swapApprovalState = .failed(error.localizedDescription)
            swapErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
            recordSwapFailure(kind: .swapSimulationFailed, message: error.localizedDescription)
        }
    }

    func approveAndSendSwap(
        mainnetConfirmation: String,
        hasCompletedDevnetSmoke: Bool
    ) async {
        guard let profile = selectedProfile,
              let quote = currentSwapQuote,
              let build = currentSwapBuild,
              let review = currentSwapReview else {
            return
        }

        enforceAutoLockIfNeeded()
        let currentFingerprint = SwapFingerprint.approvalFingerprint(quote: quote, build: build)
        do {
            try SwapApprovalGuard.validate(SwapApprovalContext(
                quote: quote,
                build: build,
                review: review,
                simulation: swapSimulationResult,
                network: selectedNetwork,
                walletPublicKey: profile.publicAddress,
                mainnetConfirmation: mainnetConfirmation,
                hasCompletedDevnetSmoke: hasCompletedDevnetSmoke,
                vaultState: vaultState,
                hasUnlockedSecret: unlockedSecrets[profile.id] != nil,
                currentFingerprint: currentFingerprint,
                preparedFingerprint: preparedSwapFingerprint
            ))
        } catch {
            swapApprovalState = .failed(error.localizedDescription)
            swapErrorMessage = error.localizedDescription
            statusMessage = selectedNetwork.isMainnet
                ? "Mainnet swap requires unlock, simulation, exact confirmation, and matching approval."
                : error.localizedDescription
            recordSwapFailure(kind: .swapBlockedByGuard, message: error.localizedDescription)
            return
        }

        guard await authenticateIfNeeded(
            required: securityPolicy.requireLocalAuthenticationForSigning,
            reason: "Authorize local signing for this Jupiter swap."
        ) else {
            swapApprovalState = .failed("Device authentication failed.")
            return
        }

        guard let secret = unlockedSecrets[profile.id] else {
            swapApprovalState = .failed(WalletSigningPreflightError.missingSecret.localizedDescription)
            return
        }

        noteUserActivity()
        record(
            kind: .swapApproved,
            walletID: profile.id,
            publicAddress: profile.publicAddress,
            message: "Jupiter swap approved by user.",
            details: [
                "network": selectedNetwork.rawValue,
                "inputMint": quote.inputMint,
                "outputMint": quote.outputMint,
                "amountRaw": "\(quote.inAmount)",
                "expectedOutputRaw": "\(quote.outAmount)",
                "minimumOutputRaw": "\(quote.otherAmountThreshold)",
                "slippageBps": "\(quote.slippageBps)",
                "route": quote.routeLabel,
                "warningsCount": "\(review.warnings.count)",
                "riskWarningsCount": "\(review.riskWarnings.count)"
            ]
        )

        swapApprovalState = .approved
        isBusy = true
        defer { isBusy = false }

        do {
            swapApprovalState = .sending
            swapPreflightBalances = currentSwapBalanceSnapshot(for: quote)
            swapBalanceDeltaVerification = .pending(quote: quote)
            let signedBase64 = try SolanaSerializedTransaction.sign(
                base64: build.swapTransactionBase64,
                seed: secret.seed,
                expectedSigner: profile.publicAddress
            )
            let signature = try await rpcClient.sendTransaction(transactionBase64: signedBase64, network: selectedNetwork)
            lastTransactionSignature = signature
            let status = try? await waitForConfirmation(signature: signature, network: selectedNetwork, timeoutSeconds: 20)
            lastConfirmationStatus = status?.confirmationStatus
            lastSwapSignature = signature
            lastSwapConfirmationStatus = status?.confirmationStatus
            swapBalanceDeltaVerification = await verifySwapBalanceDeltas(profile: profile, quote: quote)
            swapApprovalState = .sent(signature)
            record(
                kind: .swapSent,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                transactionSignature: signature,
                message: "Jupiter swap sent.",
                details: [
                    "network": selectedNetwork.rawValue,
                    "inputMint": quote.inputMint,
                    "outputMint": quote.outputMint,
                    "amountRaw": "\(quote.inAmount)",
                    "expectedOutputRaw": "\(quote.outAmount)",
                    "minimumOutputRaw": "\(quote.otherAmountThreshold)",
                    "slippageBps": "\(quote.slippageBps)",
                    "route": quote.routeLabel,
                    "confirmationStatus": status?.confirmationStatus ?? "",
                    "balanceDeltaVerification": swapBalanceDeltaVerification.status.rawValue
                ]
            )
            statusMessage = "Swap sent."
        } catch {
            swapApprovalState = .failed(error.localizedDescription)
            swapErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
            recordSwapFailure(kind: .swapFailed, message: error.localizedDescription)
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
            guard profile.canSign else {
                throw TokenTransferValidationError.invalidTokenAccount("Watch-only wallets cannot draft or send SPL token transfers.")
            }
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
            guard profile.canSign else {
                throw SolanaValidationError.invalidAddress("Watch-only wallets cannot draft or send SOL transfers.")
            }
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
            vaultState = profiles.contains(where: { $0.canSign }) ? .locked : .missing
            return
        }
        guard profiles.first(where: { $0.id == selectedWalletID })?.canSign == true else {
            vaultState = .missing
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
            recordRPCInfrastructureErrorIfNeeded(error)
            recordFailure(message: error.localizedDescription)
        }
    }

    private func waitForConfirmation(
        signature: String,
        network: WalletNetwork,
        timeoutSeconds: Int
    ) async throws -> SolanaSignatureStatus {
        for _ in 0..<timeoutSeconds {
            if let status = try await rpcClient.getSignatureStatusInfo(signature: signature, network: network) {
                if let errorDescription = status.errorDescription {
                    throw SwapError.transport(errorDescription)
                }
                if status.isConfirmedOrFinalized {
                    return status
                }
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        throw SwapError.transport("Timed out waiting for swap confirmation.")
    }

    private func currentSwapBalanceSnapshot(for quote: JupiterQuoteSummary) -> [String: UInt64] {
        var snapshot: [String: UInt64] = [:]
        if quote.inputMint == SwapConstants.nativeSolMint || quote.outputMint == SwapConstants.nativeSolMint {
            snapshot[SwapConstants.nativeSolMint] = balance?.lamports ?? 0
        }
        for mint in [quote.inputMint, quote.outputMint] where mint != SwapConstants.nativeSolMint {
            snapshot[mint] = tokenBalances
                .filter { $0.mintAddress == mint }
                .reduce(UInt64(0)) { partial, balance in
                    let result = partial.addingReportingOverflow(balance.amountRaw)
                    return result.overflow ? UInt64.max : result.partialValue
                }
        }
        return snapshot
    }

    private func verifySwapBalanceDeltas(
        profile: WalletProfile,
        quote: JupiterQuoteSummary
    ) async -> SwapBalanceDeltaVerification {
        do {
            var postBalances: [String: UInt64] = [:]
            if quote.inputMint == SwapConstants.nativeSolMint || quote.outputMint == SwapConstants.nativeSolMint {
                let lamports = try await rpcClient.getBalance(address: profile.publicAddress, network: selectedNetwork)
                balance = WalletBalance(lamports: lamports, network: selectedNetwork, fetchedAt: Date(), errorMessage: nil)
                postBalances[SwapConstants.nativeSolMint] = lamports
            }

            if quote.inputMint != SwapConstants.nativeSolMint || quote.outputMint != SwapConstants.nativeSolMint {
                let refreshedTokenBalances = try await rpcClient.getTokenBalances(ownerAddress: profile.publicAddress, network: selectedNetwork)
                tokenBalances = refreshedTokenBalances
                tokenBalancesFetchedAt = Date()
                for mint in [quote.inputMint, quote.outputMint] where mint != SwapConstants.nativeSolMint {
                    postBalances[mint] = refreshedTokenBalances
                        .filter { $0.mintAddress == mint }
                        .reduce(UInt64(0)) { partial, balance in
                            let result = partial.addingReportingOverflow(balance.amountRaw)
                            return result.overflow ? UInt64.max : result.partialValue
                        }
                }
            }

            return SwapBalanceDeltaVerifier.verify(
                quote: quote,
                before: swapPreflightBalances,
                after: postBalances
            )
        } catch {
            return SwapBalanceDeltaVerifier.unavailable(
                quote: quote,
                message: "Post-swap balance verification is unavailable: \(error.localizedDescription)"
            )
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

    func recordShieldReviewEvent(
        kind: AuditEvent.Kind,
        summary: ShieldReviewSummary,
        message: String
    ) {
        record(
            kind: kind,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: message,
            details: [
                "risk": summary.riskLevel.rawValue,
                "status": summary.status.rawValue,
                "programs": summary.programLabels.prefix(6).joined(separator: ", "),
                "unknown_instruction_count": "\(summary.unknownInstructionCount)",
                "payload": "safe_summary_only"
            ]
        )
    }

    func shieldReviewStudioHandoff(for summary: ShieldReviewSummary) -> ShieldReviewStudioHandoff {
        let transactionBase64: String?
        switch summary.handoff.sourceFlow {
        case .solSend:
            transactionBase64 = preparedMessage.map { SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: $0) }
        case .splSend:
            transactionBase64 = preparedTokenMessage.map { SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: $0) }
        case .jupiterSwap:
            transactionBase64 = currentSwapBuild?.swapTransactionBase64
        case .orcaHarvest:
            if let messageBase64 = currentOrcaHarvestReview?.messageBase64,
               let message = Data(base64Encoded: messageBase64) {
                transactionBase64 = SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message)
            } else {
                transactionBase64 = nil
            }
        case .transactionStudio, .unknown:
            transactionBase64 = nil
        }

        return ShieldReviewPayloadPolicy.makeHandoff(
            sourceFlow: summary.handoff.sourceFlow,
            safeSummary: summary.handoff.safeSummary,
            transactionBase64: transactionBase64
        )
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

    private func recordSwapFailure(kind: AuditEvent.Kind = .swapFailed, message: String) {
        record(
            kind: kind,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: message,
            details: [
                "network": selectedNetwork.rawValue,
                "status": "failed"
            ]
        )
    }

    private func recordOrcaHarvestFailure(kind: AuditEvent.Kind = .orcaHarvestFailed, message: String) {
        record(
            kind: kind,
            walletID: selectedWalletID,
            publicAddress: selectedProfile?.publicAddress,
            message: message,
            details: [
                "network": selectedNetwork.rawValue,
                "status": "failed"
            ]
        )
    }

    private func resolvedOrcaPositionMint(position: LPPositionSummary, plan: OrcaHarvestPlan) throws -> String {
        let candidate = position.positionMintAddress ?? plan.positionMint
        guard SolanaAddressValidator.isValidAddress(candidate) else {
            throw OrcaHarvestError.invalidPosition("Orca LP position mint is unavailable.")
        }
        guard candidate == plan.positionMint else {
            throw OrcaHarvestError.invalidPosition("Orca harvest plan position mint does not match the selected position.")
        }
        return candidate
    }

    private func solanaInstructionProposals(_ instructions: [OrcaHarvestInstruction]) throws -> [SolanaInstructionProposal] {
        try instructions.map { instruction in
            guard SolanaAddressValidator.isValidAddress(instruction.programID) else {
                throw OrcaHarvestError.reviewFailed("Orca harvest instruction has an invalid program ID.")
            }
            guard let data = Data(base64Encoded: instruction.dataBase64) else {
                throw OrcaHarvestError.reviewFailed("Orca harvest instruction data is invalid.")
            }
            return SolanaInstructionProposal(
                programID: instruction.programID,
                accounts: try instruction.accounts.map { account in
                    guard SolanaAddressValidator.isValidAddress(account.address) else {
                        throw OrcaHarvestError.reviewFailed("Orca harvest instruction has an invalid account address.")
                    }
                    return SolanaInstructionAccountMeta(
                        address: account.address,
                        isSigner: account.isSigner,
                        isWritable: account.isWritable
                    )
                },
                data: data
            )
        }
    }
}

struct WalletMetadataStore {
    static let profilesKey = "keyslot.wallet.profiles"
    static let selectedWalletIDKey = "keyslot.wallet.selectedWalletID"
    static let selectedNetworkKey = "keyslot.wallet.selectedNetwork"
    static let legacyProfilesKey = "gorkh.wallet.profiles"
    static let legacySelectedWalletIDKey = "gorkh.wallet.selectedWalletID"
    static let legacySelectedNetworkKey = "gorkh.wallet.selectedNetwork"
    static let allowedKeys = [profilesKey, selectedWalletIDKey, selectedNetworkKey]
    static let migrationCompleteKey = "keyslot.wallet.metadataMigrationComplete"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.migrateIfNeeded(defaults: defaults)
    }

    private static func migrateIfNeeded(defaults: UserDefaults) {
        guard !defaults.bool(forKey: migrationCompleteKey) else { return }
        if let oldProfiles = defaults.data(forKey: legacyProfilesKey) {
            defaults.set(oldProfiles, forKey: profilesKey)
        }
        if let oldWalletID = defaults.object(forKey: legacySelectedWalletIDKey) {
            defaults.set(oldWalletID, forKey: selectedWalletIDKey)
        }
        if let oldNetwork = defaults.object(forKey: legacySelectedNetworkKey) {
            defaults.set(oldNetwork, forKey: selectedNetworkKey)
        }
        defaults.set(true, forKey: migrationCompleteKey)
    }

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
