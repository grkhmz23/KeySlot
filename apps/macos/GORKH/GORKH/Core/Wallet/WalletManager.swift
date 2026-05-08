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
    @Published private(set) var lastTransactionSignature: String?
    @Published private(set) var lastConfirmationStatus: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var isBusy = false

    private let vault: WalletVault
    private let rpcClient: SolanaRPCClient
    private let auditLog: AuditLog
    private let metadataStore: WalletMetadataStore
    private var unlockedSecrets: [UUID: WalletSecret] = [:]
    private var preparedMessage: Data?

    var selectedProfile: WalletProfile? {
        profiles.first { $0.id == selectedWalletID }
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

    init(
        vault: WalletVault,
        rpcClient: SolanaRPCClient,
        auditLog: AuditLog,
        metadataStore: WalletMetadataStore
    ) {
        self.vault = vault
        self.rpcClient = rpcClient
        self.auditLog = auditLog
        self.metadataStore = metadataStore
        loadMetadata()
        auditEvents = auditLog.loadRecent()
        refreshVaultState()
    }

    func selectProfile(_ profileID: UUID?) {
        selectedWalletID = profileID
        if let selectedProfile {
            selectedNetwork = selectedProfile.selectedNetwork
        }
        balance = nil
        currentDraft = nil
        simulationResult = nil
        approvalState = .idle
        preparedMessage = nil
        refreshVaultState()
    }

    func setNetwork(_ network: WalletNetwork) {
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
    }

    func createWallet(label: String) {
        runSensitiveOperation {
            let keypair = try SolanaKeypair.generate()
            let profile = WalletProfile(
                label: label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "GORKH Wallet" : label,
                publicAddress: keypair.publicAddress,
                selectedNetwork: selectedNetwork
            )
            let secret = try WalletSecret(seed: keypair.seed)
            try vault.saveSecret(secret, for: profile.id)

            profiles.append(profile)
            selectedWalletID = profile.id
            unlockedSecrets[profile.id] = secret
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

    func importPrivateKey(label: String, privateKeyText: String) {
        runSensitiveOperation {
            let keypair = try SolanaKeypair.importPrivateKey(privateKeyText)
            let profile = WalletProfile(
                label: label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Imported Wallet" : label,
                publicAddress: keypair.publicAddress,
                selectedNetwork: selectedNetwork
            )
            let secret = try WalletSecret(seed: keypair.seed)
            try vault.saveSecret(secret, for: profile.id)

            profiles.append(profile)
            selectedWalletID = profile.id
            unlockedSecrets[profile.id] = secret
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
        _ = label
        _ = mnemonic
        statusMessage = WalletVaultError.unsupportedMnemonicImport.localizedDescription
        vaultState = .error(WalletVaultError.unsupportedMnemonicImport.localizedDescription)
    }

    func unlockWallet() {
        guard let profile = selectedProfile else {
            vaultState = .missing
            return
        }

        runSensitiveOperation {
            let secret = try vault.loadSecret(for: profile.id)
            unlockedSecrets[profile.id] = secret
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
        guard let profile = selectedProfile else {
            vaultState = .missing
            return
        }

        if var secret = unlockedSecrets[profile.id] {
            secret.clear()
        }
        unlockedSecrets.removeValue(forKey: profile.id)
        preparedMessage = nil
        approvalState = currentDraft == nil ? .idle : .drafted
        refreshVaultState()
        record(
            kind: .walletLocked,
            walletID: profile.id,
            publicAddress: profile.publicAddress,
            message: "Wallet locked."
        )
        statusMessage = "Wallet locked."
    }

    func deleteSelectedWallet() {
        guard let profile = selectedProfile else {
            return
        }

        runSensitiveOperation {
            try vault.deleteSecret(for: profile.id)
            unlockedSecrets.removeValue(forKey: profile.id)
            profiles.removeAll { $0.id == profile.id }
            selectedWalletID = profiles.first?.id
            saveMetadata()
            refreshVaultState()
            record(
                kind: .walletLocked,
                walletID: profile.id,
                publicAddress: profile.publicAddress,
                message: "Wallet removed from local vault."
            )
            statusMessage = "Wallet removed."
        }
    }

    func refreshBalance() async {
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

    func draftTransaction(recipient: String, amountSOLText: String) {
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

        guard TransactionApprovalPolicy.canApprove(
            network: draft.network,
            simulation: simulationResult,
            mainnetConfirmation: mainnetConfirmation,
            hasCompletedDevnetSmoke: hasCompletedDevnetSmoke,
            allowsUnavailableSimulation: allowsUnavailableSimulation
        ) else {
            statusMessage = draft.network.isMainnet
                ? "Mainnet requires simulation, exact confirmation, and a completed devnet smoke send for this build."
                : "Complete simulation before approval."
            return
        }

        guard let secret = unlockedSecrets[profile.id] else {
            vaultState = .locked
            statusMessage = "Unlock the wallet before signing."
            return
        }

        guard let message = preparedMessage else {
            simulationResult = .unavailable("Prepared transaction message is missing. Simulate again.")
            statusMessage = "Simulate again before signing."
            return
        }

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
