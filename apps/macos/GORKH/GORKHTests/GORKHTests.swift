import CryptoKit
import Foundation
import Testing
@testable import GORKH

@MainActor
struct GORKHTests {
    @Test func walletMetadataSerializationContainsNoSecretFields() throws {
        let profile = WalletProfile(
            label: "Primary",
            publicAddress: SolanaConstants.systemProgramID,
            selectedNetwork: .devnet
        )

        let data = try JSONEncoder().encode(profile)
        let json = try #require(String(data: data, encoding: .utf8))
        let lowercased = json.lowercased()

        #expect(!lowercased.contains("secret"))
        #expect(!lowercased.contains("private"))
        #expect(!lowercased.contains("seed"))
        #expect(!lowercased.contains("mnemonic"))
        #expect(lowercased.contains("publicaddress"))
    }

    @Test func walletMetadataCanStoreRecoveryOriginWithoutSecretMaterial() throws {
        let profile = WalletProfile(
            label: "Primary",
            publicAddress: SolanaConstants.systemProgramID,
            selectedNetwork: .devnet,
            walletOrigin: .generatedRecovery,
            derivationPath: DerivationPath.defaultSolana.rawValue
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(WalletProfile.self, from: data)
        let json = try #require(String(data: data, encoding: .utf8)).lowercased()

        #expect(decoded.walletOrigin == .generatedRecovery)
        #expect(decoded.derivationPath == DerivationPath.defaultSolana.rawValue)
        #expect(!json.contains("private"))
        #expect(!json.contains("secret"))
        #expect(!json.contains("seed"))
        #expect(!json.contains("mnemonic"))
    }

    @Test func auditEventsDropSensitiveDetails() throws {
        let event = AuditEvent(
            kind: .walletImported,
            walletID: UUID(),
            network: .devnet,
            publicAddress: SolanaConstants.systemProgramID,
            message: "Imported",
            details: [
                "privateKey": "do-not-store",
                "seedPhrase": "do-not-store",
                "network": "devnet"
            ]
        )

        let data = try JSONEncoder().encode(event)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(!json.contains("do-not-store"))
        #expect(!json.contains("privateKey"))
        #expect(!json.contains("seedPhrase"))
        #expect(json.contains("devnet"))
    }

    @Test func networkSelectorUsesExpectedRPCs() {
        #expect(WalletNetwork.devnet.rpcURL.absoluteString == "https://api.devnet.solana.com")
        #expect(WalletNetwork.mainnetBeta.rpcURL.absoluteString == "https://api.mainnet-beta.solana.com")
        #expect(WalletNetwork.mainnetBeta.isMainnet)
        #expect(!WalletNetwork.devnet.isMainnet)
    }

    @Test func addressValidationAcceptsBase58PublicKeysOnly() {
        #expect(SolanaAddressValidator.isValidAddress(SolanaConstants.systemProgramID))
        #expect(!SolanaAddressValidator.isValidAddress(""))
        #expect(!SolanaAddressValidator.isValidAddress("not a solana address"))
        #expect(!SolanaAddressValidator.isValidAddress("0OIl"))
    }

    @Test func amountValidationConvertsSolToLamports() throws {
        #expect(try SolanaAmountValidator.lamports(fromSOLText: "1") == 1_000_000_000)
        #expect(try SolanaAmountValidator.lamports(fromSOLText: "0.000000001") == 1)
        #expect(try SolanaAmountValidator.lamports(fromSOLText: "2.5") == 2_500_000_000)
        #expect(throws: SolanaValidationError.self) {
            try SolanaAmountValidator.lamports(fromSOLText: "0")
        }
        #expect(throws: SolanaValidationError.self) {
            try SolanaAmountValidator.lamports(fromSOLText: "1.0000000001")
        }
    }

    @Test func bip39GenerationProducesValidTwelveWordPhrase() throws {
        let service = Bip39MnemonicService.shared
        let words = try service.generate(wordCount: 12)
        let phrase = words.joined(separator: " ")

        #expect(words.count == 12)
        #expect(service.validate(phrase))
    }

    @Test func bip39ValidationRejectsInvalidChecksumAndUnknownWords() {
        let service = Bip39MnemonicService.shared

        #expect(!service.validate("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon"))
        #expect(!service.validate("gorkh abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"))
    }

    @Test func bip39NormalizesWhitespaceAndCase() throws {
        let service = Bip39MnemonicService.shared
        let messy = "  ABANDON\nabandon  abandon abandon abandon abandon abandon abandon abandon abandon abandon ABOUT  "

        #expect(service.normalize(messy) == "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
        try service.validateOrThrow(messy)
    }

    @Test func bip39SeedMatchesOfficialVector() throws {
        let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let seed = try Bip39MnemonicService.shared.seed(from: phrase, passphrase: "TREZOR")
        let expected = Data(hex: "c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04")

        #expect(seed == expected)
    }

    @Test func solanaDerivationIsDeterministicAndPathSensitive() throws {
        let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let service = SolanaDerivationService()
        let defaultKeypair = try service.deriveKeypair(mnemonic: phrase, path: .defaultSolana)
        let sameKeypair = try service.deriveKeypair(mnemonic: phrase, path: try DerivationPath("m/44'/501'/0'/0'"))
        let differentKeypair = try service.deriveKeypair(mnemonic: phrase, path: try DerivationPath("m/44'/501'/1'/0'"))

        #expect(defaultKeypair.seed == sameKeypair.seed)
        #expect(defaultKeypair.publicKey == sameKeypair.publicKey)
        #expect(defaultKeypair.publicAddress == sameKeypair.publicAddress)
        #expect(defaultKeypair.publicKey.count == 32)
        #expect(defaultKeypair.publicAddress != differentKeypair.publicAddress)
    }

    @Test func derivationPathValidationAllowsOnlyHardenedSolanaPaths() throws {
        #expect(try DerivationPath("m/44'/501'/0'").rawValue == "m/44'/501'/0'")
        #expect(try DerivationPath("m/44'/501'/0'/0'").rawValue == "m/44'/501'/0'/0'")
        #expect(try DerivationPath("m/44'/501'/1'/0'").rawValue == "m/44'/501'/1'/0'")
        #expect(throws: DerivationPathError.self) {
            try DerivationPath("m/44'/501'/0/0'")
        }
        #expect(throws: DerivationPathError.self) {
            try DerivationPath("m/44'/60'/0'/0'")
        }
    }

    @Test func transactionDraftBuildsTransferMessage() throws {
        let from = Base58.encode(Data(repeating: 2, count: 32))
        let to = Base58.encode(Data(repeating: 3, count: 32))
        let blockhash = Base58.encode(Data(repeating: 4, count: 32))
        let draft = TransactionDraft(
            network: .devnet,
            fromAddress: from,
            toAddress: to,
            amountLamports: 42
        )

        let message = try SolanaTransactionBuilder.makeTransferMessage(draft: draft, recentBlockhash: blockhash)
        let transaction = SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message)

        #expect(!message.isEmpty)
        #expect(!transaction.isEmpty)
    }

    @Test func cryptoKitEd25519PublicKeyMatchesRFC8032AndSignaturesVerify() throws {
        let seed = Data(hex: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")
        let expectedPublicKey = Data(hex: "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a")
        let expectedSignature = Data(hex: "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b")

        let keypair = try SolanaKeypair(seed: seed)
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        let signature = try privateKey.signature(for: Data())
        let secondSignature = try privateKey.signature(for: Data())
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: expectedPublicKey)

        #expect(keypair.publicKey.count == 32)
        #expect(signature.count == 64)
        #expect(secondSignature.count == 64)
        #expect(keypair.publicKey == expectedPublicKey)
        #expect(publicKey.isValidSignature(expectedSignature, for: Data()))
        #expect(publicKey.isValidSignature(signature, for: Data()))
        #expect(publicKey.isValidSignature(secondSignature, for: Data()))
        #expect(keypair.publicAddress == Base58.encode(expectedPublicKey))
    }

    @Test func privateKeyImportMapsSeedAndSolanaKeypairArrayToSamePublicKey() throws {
        let seed = Data(hex: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")
        let expectedPublicKey = Data(hex: "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a")
        let seedBase58 = Base58.encode(seed)
        let keypairArrayBase58 = Base58.encode(seed + expectedPublicKey)
        let jsonArray = "[" + (Array(seed + expectedPublicKey).map(String.init).joined(separator: ",")) + "]"

        let seedImport = try SolanaKeypair.importPrivateKey(seedBase58)
        let base58ArrayImport = try SolanaKeypair.importPrivateKey(keypairArrayBase58)
        let jsonImport = try SolanaKeypair.importPrivateKey(jsonArray)

        #expect(seedImport.publicKey == expectedPublicKey)
        #expect(base58ArrayImport.publicKey == expectedPublicKey)
        #expect(jsonImport.publicKey == expectedPublicKey)
    }

    @Test func walletManagerImportsMnemonicAndPrivateKeyOrigins() throws {
        let vault = InMemoryWalletVault()
        let suiteName = "ai.gorkh.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let auditURL = FileManager.default.temporaryDirectory.appendingPathComponent("gorkh-test-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: auditURL) }
        let manager = WalletManager(
            vault: vault,
            rpcClient: SolanaRPCClient(),
            auditLog: AuditLog(fileURL: auditURL),
            metadataStore: WalletMetadataStore(defaults: defaults)
        )
        let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let expectedAddress = try SolanaDerivationService().deriveKeypair(mnemonic: phrase, path: .defaultSolana).publicAddress

        manager.importMnemonic(label: "Recovered", mnemonic: phrase, derivationPath: .defaultSolana)

        let recoveredProfile = try #require(manager.selectedProfile)
        #expect(recoveredProfile.publicAddress == expectedAddress)
        #expect(recoveredProfile.walletOrigin == .importedRecovery)
        #expect(recoveredProfile.derivationPath == DerivationPath.defaultSolana.rawValue)
        #expect(vault.containsSecret(for: recoveredProfile.id))

        let seed = Data(hex: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")
        manager.importPrivateKey(label: "Advanced", privateKeyText: Base58.encode(seed))
        let privateKeyProfile = try #require(manager.selectedProfile)
        #expect(privateKeyProfile.walletOrigin == .importedPrivateKey)
    }

    @Test func transferMessageSerializationIsStableForKnownInputs() throws {
        let from = Base58.encode(Data(repeating: 2, count: 32))
        let to = Base58.encode(Data(repeating: 3, count: 32))
        let blockhash = Base58.encode(Data(repeating: 4, count: 32))
        let draft = TransactionDraft(
            network: .devnet,
            fromAddress: from,
            toAddress: to,
            amountLamports: 42
        )

        let message = try SolanaTransactionBuilder.makeTransferMessage(draft: draft, recentBlockhash: blockhash)
        let expectedHex = """
        01000103\
        0202020202020202020202020202020202020202020202020202020202020202\
        0303030303030303030303030303030303030303030303030303030303030303\
        0000000000000000000000000000000000000000000000000000000000000000\
        0404040404040404040404040404040404040404040404040404040404040404\
        01020200010c020000002a00000000000000
        """
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")

        let unsigned = try #require(Data(base64Encoded: SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message)))

        #expect(message.hexString == expectedHex)
        #expect(unsigned.count == 1 + 64 + message.count)
        #expect(unsigned[0] == 1)
        #expect(unsigned[1..<65].allSatisfy { $0 == 0 })
        #expect(Data(unsigned[65...]) == message)
    }

    @Test func signedTransferContainsVerifiableSignatureOverMessage() throws {
        let seed = Data(hex: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")
        let keypair = try SolanaKeypair(seed: seed)
        let to = Base58.encode(Data(repeating: 3, count: 32))
        let blockhash = Base58.encode(Data(repeating: 4, count: 32))
        let draft = TransactionDraft(
            network: .devnet,
            fromAddress: keypair.publicAddress,
            toAddress: to,
            amountLamports: 42
        )
        let message = try SolanaTransactionBuilder.makeTransferMessage(draft: draft, recentBlockhash: blockhash)
        let signed = try #require(Data(base64Encoded: SolanaTransactionBuilder.makeSignedTransactionBase64(message: message, seed: seed)))
        let signature = Data(signed[1..<65])
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: keypair.publicKey)

        #expect(signed[0] == 1)
        #expect(Data(signed[65...]) == message)
        #expect(signature != Data(repeating: 0, count: 64))
        #expect(signature.count == 64)
        #expect(publicKey.isValidSignature(signature, for: message))
    }

    @Test func devnetAirdropRejectsMainnet() async {
        var rejectedMainnet = false
        do {
            _ = try await SolanaRPCClient().requestAirdrop(
                address: SolanaConstants.systemProgramID,
                lamports: 1,
                network: .mainnetBeta
            )
        } catch SolanaRPCError.devnetOnly {
            rejectedMainnet = true
        } catch {
            rejectedMainnet = false
        }

        #expect(rejectedMainnet)
    }

    @Test func liveDevnetWalletSmokeSkipsUnlessEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["GORKH_RUN_LIVE_DEVNET_SMOKE"] == "1" else {
            return
        }

        let rpcClient = SolanaRPCClient()
        let sender = try SolanaKeypair.generate()
        let recipient = try SolanaKeypair.generate()
        let airdropLamports: UInt64 = 50_000_000
        let transferLamports: UInt64 = 1_000_000

        let airdropSignature = try await rpcClient.requestAirdrop(
            address: sender.publicAddress,
            lamports: airdropLamports,
            network: .devnet
        )
        let airdropStatus = try await waitForSignatureConfirmation(
            signature: airdropSignature,
            rpcClient: rpcClient,
            network: .devnet,
            timeoutSeconds: 60
        )
        #expect(airdropStatus.isConfirmedOrFinalized)

        let startingBalance = try await waitForMinimumBalance(
            address: sender.publicAddress,
            minimumLamports: transferLamports + 10_000,
            rpcClient: rpcClient,
            network: .devnet,
            timeoutSeconds: 60
        )

        let blockhash = try await rpcClient.getLatestBlockhash(network: .devnet)
        let draft = TransactionDraft(
            network: .devnet,
            fromAddress: sender.publicAddress,
            toAddress: recipient.publicAddress,
            amountLamports: transferLamports
        )
        let message = try SolanaTransactionBuilder.makeTransferMessage(draft: draft, recentBlockhash: blockhash)
        let messageBase64 = SolanaTransactionBuilder.makeMessageBase64(message: message)
        let estimatedFee = try await rpcClient.getFeeForMessage(messageBase64: messageBase64, network: .devnet)
        let unsignedTransaction = SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message)
        let simulation = try await rpcClient.simulateTransaction(
            transactionBase64: unsignedTransaction,
            network: .devnet
        )
        #expect(simulation.status == .success)

        let signedTransaction = try SolanaTransactionBuilder.makeSignedTransactionBase64(
            message: message,
            seed: sender.seed
        )
        let signedBytes = try #require(Data(base64Encoded: signedTransaction))
        let signature = Data(signedBytes[1..<65])
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: sender.publicKey)

        #expect(signature.count == 64)
        #expect(Data(signedBytes[65...]) == message)
        #expect(publicKey.isValidSignature(signature, for: message))

        let transactionSignature = try await rpcClient.sendTransaction(
            transactionBase64: signedTransaction,
            network: .devnet
        )
        let transactionStatus = try await waitForSignatureConfirmation(
            signature: transactionSignature,
            rpcClient: rpcClient,
            network: .devnet,
            timeoutSeconds: 90
        )
        #expect(transactionStatus.isConfirmedOrFinalized)

        let endingSenderBalance = try await rpcClient.getBalance(address: sender.publicAddress, network: .devnet)
        let endingRecipientBalance = try await waitForMinimumBalance(
            address: recipient.publicAddress,
            minimumLamports: transferLamports,
            rpcClient: rpcClient,
            network: .devnet,
            timeoutSeconds: 30
        )

        #expect(endingSenderBalance < startingBalance)
        #expect(endingRecipientBalance >= transferLamports)

        let auditURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gorkh-live-devnet-smoke-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: auditURL) }

        let auditLog = AuditLog(fileURL: auditURL)
        auditLog.record(AuditEvent(
            kind: .transactionSent,
            walletID: UUID(),
            network: .devnet,
            publicAddress: sender.publicAddress,
            transactionSignature: transactionSignature,
            message: "Live devnet smoke transaction sent.",
            details: [
                "to": recipient.publicAddress,
                "amountLamports": "\(transferLamports)",
                "estimatedFeeLamports": estimatedFee.map(String.init) ?? "unknown"
            ]
        ))

        let auditText = try String(contentsOf: auditURL, encoding: .utf8)
        #expect(!auditText.contains(sender.seed.hexString))
        #expect(!auditText.contains(Base58.encode(sender.seed)))
        #expect(!auditText.lowercased().contains("private"))
        #expect(!auditText.lowercased().contains("mnemonic"))

        if let resultPath = environment["GORKH_LIVE_DEVNET_RESULT_PATH"] {
            let result = LiveDevnetSmokeResult(
                senderAddress: sender.publicAddress,
                recipientAddress: recipient.publicAddress,
                airdropSignature: airdropSignature,
                transactionSignature: transactionSignature,
                explorerURL: "https://explorer.solana.com/tx/\(transactionSignature)?cluster=devnet",
                startingBalanceLamports: startingBalance,
                endingSenderBalanceLamports: endingSenderBalance,
                endingRecipientBalanceLamports: endingRecipientBalance,
                estimatedFeeLamports: estimatedFee,
                confirmationStatus: transactionStatus.confirmationStatus ?? "unknown"
            )
            let data = try JSONEncoder().encode(result)
            try data.write(to: URL(fileURLWithPath: resultPath), options: .atomic)
        }
    }

    @Test func mainnetRequiresExactConfirmation() {
        let simulation = SimulationResult(
            status: .success,
            logs: [],
            estimatedFeeLamports: 5_000,
            errorMessage: nil,
            simulatedAt: Date()
        )

        #expect(TransactionApprovalPolicy.canApprove(
            network: .devnet,
            simulation: simulation,
            mainnetConfirmation: "",
            hasCompletedDevnetSmoke: false,
            allowsUnavailableSimulation: false
        ))

        #expect(!TransactionApprovalPolicy.canApprove(
            network: .mainnetBeta,
            simulation: simulation,
            mainnetConfirmation: "I understand",
            hasCompletedDevnetSmoke: true,
            allowsUnavailableSimulation: false
        ))

        #expect(!TransactionApprovalPolicy.canApprove(
            network: .mainnetBeta,
            simulation: simulation,
            mainnetConfirmation: TransactionApprovalPolicy.requiredMainnetConfirmation,
            hasCompletedDevnetSmoke: false,
            allowsUnavailableSimulation: false
        ))

        #expect(TransactionApprovalPolicy.canApprove(
            network: .mainnetBeta,
            simulation: simulation,
            mainnetConfirmation: TransactionApprovalPolicy.requiredMainnetConfirmation,
            hasCompletedDevnetSmoke: true,
            allowsUnavailableSimulation: false
        ))
    }

    @Test func mockVaultStoresAndDeletesSecrets() throws {
        let vault = InMemoryWalletVault()
        let walletID = UUID()
        let secret = try WalletSecret(seed: Data(repeating: 7, count: 32))

        #expect(!vault.containsSecret(for: walletID))
        try vault.saveSecret(secret, for: walletID)
        #expect(vault.containsSecret(for: walletID))
        #expect(try vault.loadSecret(for: walletID) == secret)
        try vault.deleteSecret(for: walletID)
        #expect(!vault.containsSecret(for: walletID))
    }

    @Test func userDefaultsStorageIsLimitedToPublicMetadataKeys() throws {
        let suiteName = "ai.gorkh.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WalletMetadataStore(defaults: defaults)
        let profile = WalletProfile(
            label: "Primary",
            publicAddress: SolanaConstants.systemProgramID,
            selectedNetwork: .mainnetBeta
        )

        store.saveProfiles([profile])
        store.saveSelectedWalletID(profile.id)
        store.saveSelectedNetwork(.mainnetBeta)

        #expect(WalletMetadataStore.allowedKeys.allSatisfy { !Redaction.isSensitiveKey($0) })

        let domain = defaults.dictionaryRepresentation()
        let persistedText = String(describing: domain)
        #expect(!persistedText.lowercased().contains("private"))
        #expect(!persistedText.lowercased().contains("mnemonic"))
        #expect(!persistedText.lowercased().contains("seedphrase"))
    }
}

private struct LiveDevnetSmokeResult: Codable {
    let senderAddress: String
    let recipientAddress: String
    let airdropSignature: String
    let transactionSignature: String
    let explorerURL: String
    let startingBalanceLamports: UInt64
    let endingSenderBalanceLamports: UInt64
    let endingRecipientBalanceLamports: UInt64
    let estimatedFeeLamports: UInt64?
    let confirmationStatus: String
}

private enum LiveDevnetSmokeError: LocalizedError {
    case transactionFailed(String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .transactionFailed(let message):
            return "Devnet transaction failed: \(message)"
        case .timedOut(let message):
            return message
        }
    }
}

@MainActor
private func waitForSignatureConfirmation(
    signature: String,
    rpcClient: SolanaRPCClient,
    network: WalletNetwork,
    timeoutSeconds: Int
) async throws -> SolanaSignatureStatus {
    for _ in 0..<timeoutSeconds {
        if let status = try await rpcClient.getSignatureStatusInfo(signature: signature, network: network) {
            if let errorDescription = status.errorDescription {
                throw LiveDevnetSmokeError.transactionFailed(errorDescription)
            }
            if status.isConfirmedOrFinalized {
                return status
            }
        }

        try await Task.sleep(nanoseconds: 1_000_000_000)
    }

    throw LiveDevnetSmokeError.timedOut("Timed out waiting for devnet signature confirmation.")
}

@MainActor
private func waitForMinimumBalance(
    address: String,
    minimumLamports: UInt64,
    rpcClient: SolanaRPCClient,
    network: WalletNetwork,
    timeoutSeconds: Int
) async throws -> UInt64 {
    for _ in 0..<timeoutSeconds {
        let balance = try await rpcClient.getBalance(address: address, network: network)
        if balance >= minimumLamports {
            return balance
        }

        try await Task.sleep(nanoseconds: 1_000_000_000)
    }

    throw LiveDevnetSmokeError.timedOut("Timed out waiting for devnet balance.")
}

private extension Data {
    init(hex: String) {
        var bytes = [UInt8]()
        var index = hex.startIndex

        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byte = UInt8(hex[index..<nextIndex], radix: 16)!
            bytes.append(byte)
            index = nextIndex
        }

        self.init(bytes)
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
