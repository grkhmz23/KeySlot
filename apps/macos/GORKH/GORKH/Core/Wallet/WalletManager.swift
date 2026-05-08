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

    private let vault: WalletVault
    private let rpcClient: SolanaRPCClient
    private let auditLog: AuditLog
    private let metadataStore: WalletMetadataStore
    private let mnemonicService: any MnemonicService
    private let derivationService: SolanaDerivationService
    private var unlockedSecrets: [UUID: WalletSecret] = [:]
    private var preparedMessage: Data?
    private var preparedTokenMessage: Data?

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
            mnemonicService: Bip39MnemonicService.shared
        )
    }

    init(
        vault: WalletVault,
        rpcClient: SolanaRPCClient,
        auditLog: AuditLog,
        metadataStore: WalletMetadataStore,
        mnemonicService: any MnemonicService
    ) {
        self.vault = vault
        self.rpcClient = rpcClient
        self.auditLog = auditLog
        self.metadataStore = metadataStore
        self.mnemonicService = mnemonicService
        self.derivationService = SolanaDerivationService(mnemonicService: mnemonicService)
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
        tokenBalances = []
        tokenBalancesFetchedAt = nil
        tokenBalanceError = nil
        currentTokenDraft = nil
        tokenSimulationResult = nil
        tokenApprovalState = .idle
        preparedTokenMessage = nil
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
        tokenBalances = []
        tokenBalancesFetchedAt = nil
        tokenBalanceError = nil
        currentTokenDraft = nil
        tokenSimulationResult = nil
        tokenApprovalState = .idle
        preparedTokenMessage = nil
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
        preparedTokenMessage = nil
        approvalState = currentDraft == nil ? .idle : .drafted
        tokenApprovalState = currentTokenDraft == nil ? .idle : .drafted
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
            preparedTokenMessage = nil
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

    func refreshTokenBalances() async {
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
            let recipientOwner = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
            guard SolanaAddressValidator.isValidAddress(recipientOwner) else {
                throw SolanaValidationError.invalidAddress("Recipient owner address is invalid.")
            }

            let amountRaw = try TokenAmountFormatter.rawAmount(fromUIAmount: amountText, decimals: token.decimals)
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
                decimals: token.decimals,
                availableAmountRaw: token.amountRaw,
                ataPlan: ataPlan
            )

            currentTokenDraft = draft
            tokenSimulationResult = nil
            preparedTokenMessage = nil
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
                    "sourceTokenAccount": token.tokenAccountAddress,
                    "recipientOwner": recipientOwner,
                    "recipientTokenAccount": destinationTokenAccount ?? "",
                    "createsAssociatedTokenAccount": "\(ataPlan.shouldCreateAssociatedTokenAccount)",
                    "amountRaw": "\(amountRaw)",
                    "decimals": "\(token.decimals)"
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
                    "status": result.status.rawValue,
                    "createsAssociatedTokenAccount": "\(draft.ataPlan.shouldCreateAssociatedTokenAccount)"
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

        guard TransactionApprovalPolicy.canApprove(
            network: draft.network,
            simulation: tokenSimulationResult,
            mainnetConfirmation: mainnetConfirmation,
            hasCompletedDevnetSmoke: hasCompletedDevnetSmoke,
            allowsUnavailableSimulation: allowsUnavailableSimulation
        ) else {
            statusMessage = draft.network.isMainnet
                ? "Mainnet token send requires simulation, exact confirmation, and a completed devnet smoke send for this build."
                : "Complete token simulation before approval."
            return
        }

        guard let secret = unlockedSecrets[profile.id] else {
            vaultState = .locked
            statusMessage = "Unlock the wallet before signing."
            return
        }

        guard let message = preparedTokenMessage else {
            tokenSimulationResult = .unavailable("Prepared token transaction message is missing. Simulate again.")
            statusMessage = "Simulate again before signing."
            return
        }

        record(
            kind: .tokenTransferApproved,
            walletID: profile.id,
            publicAddress: profile.publicAddress,
            message: "SPL token transfer approved by user.",
                details: [
                    "network": draft.network.rawValue,
                    "mint": draft.mintAddress,
                    "amountRaw": "\(draft.amountRaw)",
                    "createsAssociatedTokenAccount": "\(draft.ataPlan.shouldCreateAssociatedTokenAccount)"
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
                    "sourceTokenAccount": draft.sourceTokenAccount,
                    "recipientOwner": draft.recipientOwnerAddress,
                    "recipientTokenAccount": draft.recipientTokenAccount ?? "",
                    "createsAssociatedTokenAccount": "\(draft.ataPlan.shouldCreateAssociatedTokenAccount)",
                    "amountRaw": "\(draft.amountRaw)",
                    "decimals": "\(draft.decimals)"
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
