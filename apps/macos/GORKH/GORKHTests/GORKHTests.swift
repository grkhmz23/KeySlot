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
        #expect(WalletNetwork.devnet.rpcURL.absoluteString == "https://sol-devnet-rpc.rpcfast.com")
        #expect(WalletNetwork.mainnetBeta.rpcURL.absoluteString == "https://solana-rpc.rpcfast.com/")
        #expect(WalletNetwork.devnet.webSocketURL.absoluteString == "wss://sol-devnet-rpc.rpcfast.com")
        #expect(WalletNetwork.mainnetBeta.webSocketURL.absoluteString == "wss://solana-rpc.rpcfast.com/")
        #expect(WalletNetwork.mainnetBeta.isMainnet)
        #expect(!WalletNetwork.devnet.isMainnet)
    }

    @Test func rpcFastConfigurationLoadsEnvAndAppliesHeaderWithoutLeakingToken() throws {
        let configuration = RPCFastConfiguration(environment: [
            RPCFastConfiguration.devnetTokenEnvironmentName: "devnet-rpcfast-token",
            RPCFastConfiguration.mainnetTokenEnvironmentName: "mainnet-rpcfast-token",
            RPCFastConfiguration.fallbackDevnetTokenEnvironmentName: "fallback-devnet-token"
        ])
        var request = URLRequest(url: configuration.httpURL(for: .devnet))
        configuration.applyAuthentication(to: &request, network: .devnet)

        #expect(configuration.endpoint(for: .devnet).provider == .rpcFast)
        #expect(configuration.endpoint(for: .devnet).httpHost == "sol-devnet-rpc.rpcfast.com")
        #expect(configuration.endpoint(for: .mainnetBeta).httpHost == "solana-rpc.rpcfast.com")
        #expect(configuration.tokenStatus(for: .devnet) == .present)
        #expect(configuration.tokenStatus(for: .mainnetBeta) == .present)
        #expect(request.value(forHTTPHeaderField: "X-Token") == "devnet-rpcfast-token")
        #expect(!configuration.endpoint(for: .devnet).safeHTTPDisplay.contains("devnet-rpcfast-token"))

        let safeDetails = Redaction.safeDetails([
            "GORKH_RPCFAST_DEVNET_TOKEN": "devnet-rpcfast-token",
            "RPCFAST_MAINNET_TOKEN": "mainnet-rpcfast-token",
            "X-Token": "devnet-rpcfast-token",
            "network": WalletNetwork.devnet.rawValue
        ])
        #expect(safeDetails["network"] == WalletNetwork.devnet.rawValue)
        #expect(safeDetails["GORKH_RPCFAST_DEVNET_TOKEN"] == nil)
        #expect(safeDetails["RPCFAST_MAINNET_TOKEN"] == nil)
        #expect(safeDetails["X-Token"] == nil)

        let event = AuditEvent(
            kind: .rpcProviderHealthChecked,
            walletID: nil,
            network: .devnet,
            publicAddress: nil,
            message: "RPC health checked.",
            details: [
                "provider": RPCProviderKind.rpcFast.rawValue,
                "X-Token": "devnet-rpcfast-token",
                "GORKH_RPCFAST_DEVNET_TOKEN": "devnet-rpcfast-token"
            ]
        )
        let eventJSON = try #require(String(data: JSONEncoder().encode(event), encoding: .utf8))
        #expect(eventJSON.contains(RPCProviderKind.rpcFast.rawValue))
        #expect(!eventJSON.contains("devnet-rpcfast-token"))
        #expect(!eventJSON.contains("X-Token"))
    }

    @Test func rpcFastMissingTokenAndSecurityModelsAreSafe() throws {
        let configuration = RPCFastConfiguration(environment: [:])
        let securityStatus = configuration.securityStatus(for: .devnet)
        let snapshot = RPCHealthSnapshot.tokenMissing(network: .devnet, configuration: configuration)
        let encodedSecurity = try JSONEncoder().encode(securityStatus)
        let encodedSnapshot = try JSONEncoder().encode(snapshot)
        let securityJSON = try #require(String(data: encodedSecurity, encoding: .utf8))
        let snapshotJSON = try #require(String(data: encodedSnapshot, encoding: .utf8))

        #expect(configuration.tokenStatus(for: .devnet) == .missing)
        #expect(configuration.tokenStatus(for: .mainnetBeta) == .missing)
        #expect(securityStatus.tokenStatus == .missing)
        #expect(securityStatus.beamStatus == "locked-future")
        #expect(snapshot.status == .tokenMissing)
        #expect(snapshot.httpEndpointHost == "sol-devnet-rpc.rpcfast.com")
        #expect(snapshot.webSocketEndpointHost == "sol-devnet-rpc.rpcfast.com")
        #expect(!securityJSON.contains("devnet-rpcfast-token"))
        #expect(!snapshotJSON.contains("devnet-rpcfast-token"))
    }

    @Test func solanaRPCClientBuildsRPCFastRequestAndRequiresToken() throws {
        let configuration = RPCFastConfiguration(environment: [
            RPCFastConfiguration.devnetTokenEnvironmentName: "devnet-rpcfast-token"
        ])
        let client = SolanaRPCClient(configuration: configuration)
        let request = try client.makeRequest(method: "getBalance", params: [SolanaConstants.systemProgramID], network: .devnet)
        let body = try #require(request.httpBody)
        let bodyJSON = try #require(String(data: body, encoding: .utf8))

        #expect(request.url?.absoluteString == "https://sol-devnet-rpc.rpcfast.com")
        #expect(request.value(forHTTPHeaderField: "X-Token") == "devnet-rpcfast-token")
        #expect(bodyJSON.contains("\"getBalance\""))
        #expect(!bodyJSON.contains("devnet-rpcfast-token"))

        let missingClient = SolanaRPCClient(configuration: RPCFastConfiguration(environment: [:]))
        #expect(throws: SolanaRPCError.self) {
            try missingClient.makeRequest(method: "getBalance", params: [SolanaConstants.systemProgramID], network: .devnet)
        }
    }

    @Test func solanaRPCClientRejectsUnsupportedAndBlockedRPCFastMethods() throws {
        let client = SolanaRPCClient(configuration: RPCFastConfiguration(environment: [
            RPCFastConfiguration.devnetTokenEnvironmentName: "devnet-rpcfast-token"
        ]))

        #expect(throws: SolanaRPCError.self) {
            try client.makeRequest(method: "customUnsafeMethod", params: [], network: .devnet)
        }
        #expect(throws: SolanaRPCError.self) {
            try client.makeRequest(
                method: "getProgramAccounts",
                params: [SolanaConstants.splTokenProgramID, ["encoding": "jsonParsed"]],
                network: .devnet
            )
        }
    }

    @Test func rpcFastSmokeStyleSummaryRedactsTokenValues() throws {
        let configuration = RPCFastConfiguration(environment: [
            RPCFastConfiguration.devnetTokenEnvironmentName: "devnet-rpcfast-token",
            RPCFastConfiguration.mainnetTokenEnvironmentName: "mainnet-rpcfast-token"
        ])
        let raw = """
        {"status":"failed","header":"X-Token: devnet-rpcfast-token","env":"GORKH_RPCFAST_MAINNET_TOKEN: mainnet-rpcfast-token"}
        """
        let redacted = configuration.redact(raw)

        #expect(!redacted.contains("devnet-rpcfast-token"))
        #expect(!redacted.contains("mainnet-rpcfast-token"))
        #expect(redacted.contains("[redacted]"))
    }

    @Test func rpcFastErrorNormalizationAndMethodAvailability() {
        let configuration = RPCFastConfiguration(environment: [
            RPCFastConfiguration.devnetTokenEnvironmentName: "devnet-rpcfast-token"
        ])
        let unauthorized = RPCErrorNormalizer.normalize(
            statusCode: 401,
            message: "HTTP 401 X-Token: devnet-rpcfast-token",
            configuration: configuration
        )
        let rateLimited = RPCErrorNormalizer.normalize(statusCode: 429, message: "too many requests", configuration: configuration)
        let methodBlocked = RPCErrorNormalizer.normalize(message: "method blocked for this program", configuration: configuration)
        let planUpgrade = RPCErrorNormalizer.normalize(message: "plan upgrade required for compute unit usage", configuration: configuration)

        #expect(unauthorized.category == .unauthorized)
        #expect(!unauthorized.message.contains("devnet-rpcfast-token"))
        #expect(rateLimited.category == .rateLimited)
        #expect(methodBlocked.category == .methodBlocked)
        #expect(planUpgrade.category == .planUpgradeRequired)
        #expect(RPCMethodAvailability.evaluate(method: "getProgramAccounts", programID: SolanaConstants.splTokenProgramID) == .blocked)
        #expect(RPCMethodAvailability.evaluate(method: "getProgramAccounts", programID: StakeConstants.stakeProgramID) == .expensive)
        #expect(RPCMethodAvailability.evaluate(method: "getTokenAccountsByOwner") == .planLimited)
        #expect(RPCMethodAvailability.evaluate(method: "dangerousCustomMethod") == .unsupported)
    }

    @Test func rpcFastHealthCheckerReportsMissingTokenWithoutNetworkRequest() async {
        let client = SolanaRPCClient(configuration: RPCFastConfiguration(environment: [:]))
        let checker = RPCHealthChecker(rpcClient: client)
        let snapshot = await checker.check(network: .devnet)

        #expect(snapshot.provider == .rpcFast)
        #expect(snapshot.network == .devnet)
        #expect(snapshot.status == .tokenMissing)
        #expect(snapshot.latencyMilliseconds == nil)
        #expect(snapshot.beamStatus == "locked-future")
        #expect(snapshot.errorMessage?.contains("GORKH_RPCFAST_DEVNET_TOKEN") == true)
    }

    @Test func portfolioAggregateReportsReadHeavyRPCErrorWithoutCrashing() {
        let profile = WalletProfile(label: "RPC Fast", publicAddress: SolanaConstants.systemProgramID)
        let summary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .mainnetBeta,
            profiles: [profile],
            solBalances: [profile.id: 0],
            tokenBalances: [profile.id: []],
            prices: [:],
            stakeAccounts: [profile.id: []],
            stakeErrors: [profile.id: "RPC Fast plan does not currently allow getProgramAccounts."],
            fetchedAt: Date(timeIntervalSince1970: 0),
            errors: [profile.id: "RPC Fast blocked this RPC method or program."]
        )

        #expect(summary.status == .stale)
        #expect(summary.wallets.count == 1)
        #expect(summary.wallets[0].errorMessage?.contains("RPC Fast blocked") == true)
        #expect(summary.errorMessage?.contains("RPC Fast plan") == true)
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

    @Test func tokenAmountFormatterUsesExactIntegerMath() throws {
        #expect(TokenAmountFormatter.format(rawAmount: 1_234_500, decimals: 6) == "1.2345")
        #expect(TokenAmountFormatter.format(rawAmount: 1, decimals: 6) == "0.000001")
        #expect(TokenAmountFormatter.format(rawAmount: 42, decimals: 0) == "42")

        #expect(try TokenAmountFormatter.rawAmount(fromUIAmount: "1.2345", decimals: 6) == 1_234_500)
        #expect(try TokenAmountFormatter.rawAmount(fromUIAmount: "0.000001", decimals: 6) == 1)
        #expect(try TokenAmountFormatter.rawAmount(fromUIAmount: "42", decimals: 0) == 42)
        #expect(throws: SolanaValidationError.self) {
            try TokenAmountFormatter.rawAmount(fromUIAmount: "0", decimals: 6)
        }
        #expect(throws: SolanaValidationError.self) {
            try TokenAmountFormatter.rawAmount(fromUIAmount: "1.0000001", decimals: 6)
        }
        #expect(throws: SolanaValidationError.self) {
            try TokenAmountFormatter.rawAmount(fromUIAmount: "1e2", decimals: 6)
        }
    }

    @Test func parsedSplTokenAccountsExposeSafeBalanceFields() throws {
        let result: [String: Any] = [
            "value": [
                [
                    "pubkey": "TokenAccount111111111111111111111111111111",
                    "account": [
                        "owner": SolanaConstants.splTokenProgramID,
                        "data": [
                            "parsed": [
                                "info": [
                                    "mint": "Mint111111111111111111111111111111111111",
                                    "owner": SolanaConstants.systemProgramID,
                                    "state": "initialized",
                                    "tokenAmount": [
                                        "amount": "1234500",
                                        "decimals": 6,
                                        "uiAmountString": "1.2345"
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let balances = try SplTokenParser.parseTokenAccounts(result: result, programKind: .splToken)
        let balance = try #require(balances.first)

        #expect(balance.tokenAccountAddress == "TokenAccount111111111111111111111111111111")
        #expect(balance.mintAddress == "Mint111111111111111111111111111111111111")
        #expect(balance.ownerAddress == SolanaConstants.systemProgramID)
        #expect(balance.amountRaw == 1_234_500)
        #expect(balance.decimals == 6)
        #expect(balance.uiAmountString == "1.2345")
        #expect(balance.programKind == .splToken)
        #expect(balance.state == .initialized)
    }

    @Test func tokenMetadataRegistryResolvesKnownAndUnknownTokens() throws {
        let known = try #require(TokenMetadataRegistry.lookup(
            mintAddress: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
            network: .mainnetBeta
        ))
        #expect(known.symbol == "USDC")
        #expect(known.decimals == 6)

        let unknown = sampleTokenBalance(
            mint: Base58.encode(Data(repeating: 9, count: 32)),
            decimals: 4
        )
        let metadata = TokenMetadataResolver.resolve(balance: unknown, network: .mainnetBeta)
        #expect(metadata.source == .unknown)
        #expect(metadata.symbol == "UNKNOWN")
        #expect(metadata.decimals == 4)
        #expect(TokenMetadataResolver.warnings(for: unknown, metadata: metadata).contains(.unknownToken))
    }

    @Test func pusdRegistryMetadataIsMainnetStablecoin() throws {
        let pusd = try #require(TokenMetadataRegistry.lookup(
            mintAddress: PUSDConstants.mintAddress,
            network: .mainnetBeta
        ))

        #expect(pusd.symbol == "PUSD")
        #expect(pusd.name == "Palm USD")
        #expect(pusd.decimals == 6)
        #expect(pusd.category == .stablecoin)
        #expect(pusd.flags.nonFreezable)
        #expect(pusd.flags.noBlacklist)
        #expect(pusd.flags.noPause)
        #expect(pusd.flags.standardSPL)
        #expect(SolanaAddressValidator.isValidAddress(PUSDConstants.mintAddress))
    }

    @Test func tokenMetadataResolverUsesExpectedDecimalsPriority() {
        let knownMint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
        let parsed = sampleTokenBalance(mint: knownMint, decimals: 4)
        let parsedMetadata = TokenMetadataResolver.resolve(balance: parsed, network: .mainnetBeta, mintAccountDecimals: 2)
        #expect(parsedMetadata.decimals == 4)
        #expect(parsedMetadata.decimalsSource == .parsedAccount)

        let registryFallback = sampleTokenBalance(mint: knownMint, decimals: nil)
        let registryMetadata = TokenMetadataResolver.resolve(balance: registryFallback, network: .mainnetBeta, mintAccountDecimals: 2)
        #expect(registryMetadata.decimals == 6)
        #expect(registryMetadata.decimalsSource == .knownRegistry)

        let mintFallback = sampleTokenBalance(mint: Base58.encode(Data(repeating: 8, count: 32)), decimals: nil)
        let mintMetadata = TokenMetadataResolver.resolve(balance: mintFallback, network: .devnet, mintAccountDecimals: 3)
        #expect(mintMetadata.decimals == 3)
        #expect(mintMetadata.decimalsSource == .mintAccount)

        let unavailable = TokenMetadataResolver.resolve(balance: mintFallback, network: .devnet)
        #expect(unavailable.decimals == nil)
        #expect(TokenMetadataResolver.warnings(for: mintFallback, metadata: unavailable).contains(.decimalsUnavailable))
    }

    @Test func parsedTokenAccountWithoutDecimalsIsKeptButCannotSendUntilResolved() throws {
        let result: [String: Any] = [
            "value": [
                [
                    "pubkey": "TokenAccount111111111111111111111111111111",
                    "account": [
                        "owner": SolanaConstants.splTokenProgramID,
                        "data": [
                            "parsed": [
                                "info": [
                                    "mint": Base58.encode(Data(repeating: 9, count: 32)),
                                    "owner": SolanaConstants.systemProgramID,
                                    "state": "initialized",
                                    "tokenAmount": [
                                        "amount": "1234500",
                                        "uiAmountString": "1.2345"
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let balance = try #require(try SplTokenParser.parseTokenAccounts(result: result, programKind: .splToken).first)
        let metadata = TokenMetadataResolver.resolve(balance: balance, network: .mainnetBeta)

        #expect(balance.decimals == nil)
        #expect(metadata.decimals == nil)
        #expect(!TokenMetadataResolver.canSend(balance: balance, metadata: metadata))
    }

    @Test func tokenAccountWarningsBlockFrozenAndExposeDelegateCloseAuthority() {
        let frozen = sampleTokenBalance(
            state: .frozen,
            delegateAddress: SolanaConstants.systemProgramID,
            delegatedAmountRaw: 10,
            closeAuthorityAddress: SolanaConstants.systemProgramID
        )
        let metadata = TokenMetadataResolver.resolve(balance: frozen, network: .devnet)
        let warnings = TokenMetadataResolver.warnings(for: frozen, metadata: metadata)

        #expect(warnings.contains(.frozenAccount))
        #expect(warnings.contains(.delegatedAccount))
        #expect(warnings.contains(.closeAuthorityPresent))
        #expect(warnings.contains(.unknownToken))
        #expect(warnings.contains(.devnetToken))
        #expect(!TokenMetadataResolver.canSend(balance: frozen, metadata: metadata))
    }

    @Test func zeroBalanceIsVisibleButNotSendable() {
        let zero = sampleTokenBalance(amountRaw: 0, decimals: 6)
        let metadata = TokenMetadataResolver.resolve(balance: zero, network: .devnet)
        let warnings = TokenMetadataResolver.warnings(for: zero, metadata: metadata)

        #expect(warnings.contains(.zeroBalance))
        #expect(!TokenMetadataResolver.canSend(balance: zero, metadata: metadata))
    }

    @Test func tokenTransferDraftCarriesApprovalWarningsAndMetadata() {
        let owner = Base58.encode(Data(repeating: 2, count: 32))
        let source = Base58.encode(Data(repeating: 3, count: 32))
        let destination = Base58.encode(Data(repeating: 4, count: 32))
        let mint = Base58.encode(Data(repeating: 5, count: 32))
        let draft = TokenTransferDraft(
            network: .devnet,
            ownerAddress: owner,
            sourceTokenAccount: source,
            mintAddress: mint,
            tokenProgramKind: .splToken,
            recipientOwnerAddress: Base58.encode(Data(repeating: 7, count: 32)),
            recipientTokenAccount: destination,
            amountRaw: 42,
            amountText: "0.000042",
            decimals: 6,
            availableAmountRaw: 1_000_000,
            ataPlan: AssociatedTokenAccount.existingPlan(
                recipientOwner: Base58.encode(Data(repeating: 7, count: 32)),
                mint: mint,
                tokenProgramKind: .splToken,
                recipientTokenAccount: destination
            ),
            tokenSymbol: "UNKNOWN",
            tokenName: "Unknown Token",
            metadataSource: .unknown,
            sourceAccountState: .initialized,
            sourceDelegateAddress: SolanaConstants.systemProgramID,
            sourceCloseAuthorityAddress: nil,
            warnings: [.unknownToken, .delegatedAccount]
        )

        #expect(draft.tokenDisplayName == "UNKNOWN - Unknown Token")
        #expect(draft.warnings.contains(.unknownToken))
        #expect(draft.warnings.contains(.delegatedAccount))
        #expect(!draft.warnings.contains { $0.blocksSend })
    }

    @Test func transferCheckedInstructionEncodingIsStable() {
        let data = SplTokenInstructionBuilder.transferCheckedInstructionData(amountRaw: 42, decimals: 6)
        #expect(data.hexString == "0c2a0000000000000006")
    }

    @Test func tokenTransferMessageContainsTransferCheckedInstruction() throws {
        let owner = Base58.encode(Data(repeating: 2, count: 32))
        let source = Base58.encode(Data(repeating: 3, count: 32))
        let destination = Base58.encode(Data(repeating: 4, count: 32))
        let mint = Base58.encode(Data(repeating: 5, count: 32))
        let blockhash = Base58.encode(Data(repeating: 6, count: 32))
        let draft = TokenTransferDraft(
            network: .devnet,
            ownerAddress: owner,
            sourceTokenAccount: source,
            mintAddress: mint,
            tokenProgramKind: .splToken,
            recipientOwnerAddress: Base58.encode(Data(repeating: 7, count: 32)),
            recipientTokenAccount: destination,
            amountRaw: 42,
            amountText: "0.000042",
            decimals: 6,
            availableAmountRaw: 1_000_000,
            ataPlan: AssociatedTokenAccount.existingPlan(
                recipientOwner: Base58.encode(Data(repeating: 7, count: 32)),
                mint: mint,
                tokenProgramKind: .splToken,
                recipientTokenAccount: destination
            )
        )

        let message = try SplTokenInstructionBuilder.makeTransferCheckedMessage(
            draft: draft,
            recentBlockhash: blockhash
        )

        let parsed = try parseMessage(message)
        #expect(Data(message.prefix(3)).hexString == "010002")
        #expect(parsed.requiredSignatures == 1)
        #expect(parsed.readonlySignedAccounts == 0)
        #expect(parsed.readonlyUnsignedAccounts == 2)
        #expect(message.range(of: SplTokenInstructionBuilder.transferCheckedInstructionData(amountRaw: 42, decimals: 6)) != nil)
        #expect(parsed.instructions.count == 1)
    }

    @Test func ed25519OnCurveCheckRecognizesValidPublicKeysAndPdas() throws {
        let publicKey = Data(hex: "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a")
        #expect(Ed25519CompressedPoint.isOnCurve(publicKey))

        let pda = try ProgramDerivedAddress.findProgramAddress(
            seeds: [Data("gorkh".utf8)],
            programID: SolanaConstants.associatedTokenAccountProgramID
        )
        #expect(pda.address.count == 32)
        #expect(!Ed25519CompressedPoint.isOnCurve(pda.address))
    }

    @Test func pdaDerivationIsDeterministicAndRejectsOversizedSeeds() throws {
        let first = try ProgramDerivedAddress.findProgramAddress(
            seeds: [Data("wallet".utf8), Data("mint".utf8)],
            programID: SolanaConstants.associatedTokenAccountProgramID
        )
        let second = try ProgramDerivedAddress.findProgramAddress(
            seeds: [Data("wallet".utf8), Data("mint".utf8)],
            programID: SolanaConstants.associatedTokenAccountProgramID
        )
        let different = try ProgramDerivedAddress.findProgramAddress(
            seeds: [Data("wallet".utf8), Data("other".utf8)],
            programID: SolanaConstants.associatedTokenAccountProgramID
        )

        #expect(first == second)
        #expect(first.address != different.address)
        #expect(first.bump <= 255)
        #expect(throws: ProgramDerivedAddressError.self) {
            try ProgramDerivedAddress.createProgramAddress(
                seeds: [Data(repeating: 1, count: 33)],
                programID: SolanaConstants.associatedTokenAccountProgramID
            )
        }
    }

    @Test func associatedTokenAddressDerivationIsDeterministic() throws {
        let owner = Base58.encode(Data(repeating: 2, count: 32))
        let mint = Base58.encode(Data(repeating: 5, count: 32))

        let first = try AssociatedTokenAccount.deriveAddress(
            owner: owner,
            mint: mint,
            tokenProgramKind: .splToken
        )
        let second = try AssociatedTokenAccount.deriveAddress(
            owner: owner,
            mint: mint,
            tokenProgramKind: .splToken
        )

        #expect(first == second)
        #expect(first.address.count == 32)
        #expect(SolanaAddressValidator.isValidAddress(first.base58Address))
        #expect(!Ed25519CompressedPoint.isOnCurve(first.address))
    }

    @Test func createAtaAndTransferMessageUsesExpectedInstructionOrder() throws {
        let owner = Base58.encode(Data(repeating: 2, count: 32))
        let source = Base58.encode(Data(repeating: 3, count: 32))
        let recipientOwner = Base58.encode(Data(repeating: 7, count: 32))
        let mint = Base58.encode(Data(repeating: 5, count: 32))
        let blockhash = Base58.encode(Data(repeating: 6, count: 32))
        let ataPlan = AssociatedTokenAccount.missingPlan(
            recipientOwner: recipientOwner,
            mint: mint,
            tokenProgramKind: .splToken,
            rentExemptLamports: 2_039_280
        )
        let destination = try #require(ataPlan.associatedTokenAddress)
        let draft = TokenTransferDraft(
            network: .devnet,
            ownerAddress: owner,
            sourceTokenAccount: source,
            mintAddress: mint,
            tokenProgramKind: .splToken,
            recipientOwnerAddress: recipientOwner,
            recipientTokenAccount: destination,
            amountRaw: 42,
            amountText: "0.000042",
            decimals: 6,
            availableAmountRaw: 1_000_000,
            ataPlan: ataPlan
        )

        let message = try SplTokenInstructionBuilder.makeTransferCheckedMessage(
            draft: draft,
            recentBlockhash: blockhash
        )
        let parsed = try parseMessage(message)
        let associatedProgram = try #require(SolanaAddressValidator.decodeAddress(SolanaConstants.associatedTokenAccountProgramID))
        let tokenProgram = try #require(SolanaAddressValidator.decodeAddress(SolanaConstants.splTokenProgramID))

        #expect(parsed.requiredSignatures == 1)
        #expect(parsed.instructions.count == 2)
        #expect(parsed.accountKeys[Int(parsed.instructions[0].programIDIndex)] == associatedProgram)
        #expect(parsed.instructions[0].data.isEmpty)
        #expect(parsed.instructions[0].accountIndexes.count == 6)
        #expect(parsed.accountKeys[Int(parsed.instructions[1].programIDIndex)] == tokenProgram)
        #expect(parsed.instructions[1].data == SplTokenInstructionBuilder.transferCheckedInstructionData(amountRaw: 42, decimals: 6))
        #expect(SplTokenInstructionBuilder.instructionCount(for: draft) == 2)
    }

    @Test func tokenTransferRejectsToken2022UntilExtensionHandlingExists() throws {
        let owner = Base58.encode(Data(repeating: 2, count: 32))
        let source = Base58.encode(Data(repeating: 3, count: 32))
        let destination = Base58.encode(Data(repeating: 4, count: 32))
        let mint = Base58.encode(Data(repeating: 5, count: 32))
        let draft = TokenTransferDraft(
            network: .devnet,
            ownerAddress: owner,
            sourceTokenAccount: source,
            mintAddress: mint,
            tokenProgramKind: .token2022,
            recipientOwnerAddress: Base58.encode(Data(repeating: 7, count: 32)),
            recipientTokenAccount: destination,
            amountRaw: 42,
            amountText: "42",
            decimals: 0,
            availableAmountRaw: 100,
            ataPlan: AssociatedTokenAccount.existingPlan(
                recipientOwner: Base58.encode(Data(repeating: 7, count: 32)),
                mint: mint,
                tokenProgramKind: .token2022,
                recipientTokenAccount: destination
            )
        )

        #expect(throws: TokenTransferValidationError.self) {
            try SplTokenInstructionBuilder.makeTransferCheckedMessage(draft: draft, recentBlockhash: Base58.encode(Data(repeating: 6, count: 32)))
        }
    }

    @Test func missingAtaPlanIsVisibleAndCreationSupportedForSplToken() {
        let plan = AssociatedTokenAccount.missingPlan(
            recipientOwner: SolanaConstants.systemProgramID,
            mint: Base58.encode(Data(repeating: 5, count: 32)),
            tokenProgramKind: .splToken,
            rentExemptLamports: 2_039_280
        )

        #expect(plan.shouldCreateAssociatedTokenAccount)
        #expect(!plan.recipientTokenAccountExists)
        #expect(plan.creationSupported)
        #expect(plan.associatedTokenAddress != nil)
        #expect(plan.rentExemptLamports == 2_039_280)
        #expect(plan.message.lowercased().contains("missing"))
    }

    @Test func token2022UsesOfficialProgramIdButSendsStayBlocked() {
        #expect(SolanaConstants.token2022ProgramID == "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb")
        #expect(TokenProgramKind.token2022.programID == SolanaConstants.token2022ProgramID)
    }

    @Test func tokenAuditEventsDropSensitiveDetails() throws {
        let event = AuditEvent(
            kind: .tokenTransferSent,
            walletID: UUID(),
            network: .devnet,
            publicAddress: SolanaConstants.systemProgramID,
            transactionSignature: "signature",
            message: "Token sent",
            details: [
                "mint": "safe",
                "privateKey": "do-not-store",
                "mnemonic": "do-not-store",
                "seedPhrase": "do-not-store"
            ]
        )

        let data = try JSONEncoder().encode(event)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("safe"))
        #expect(!json.contains("do-not-store"))
        #expect(!json.contains("privateKey"))
        #expect(!json.contains("mnemonic"))
        #expect(!json.contains("seedPhrase"))
    }

    @Test func cloakFeeModelUsesIntegerMathAndKnownConstants() throws {
        #expect(CloakConstants.programID == "zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW")
        #expect(CloakConstants.minimumDepositLamports == 10_000_000)
        #expect(CloakConstants.fixedFeeLamports == 5_000_000)

        let quote = try CloakFeeModel.quote(grossLamports: 50_000_000)

        #expect(quote.variableFeeLamports == 150_000)
        #expect(quote.totalFeeLamports == 5_150_000)
        #expect(quote.netLamports == 44_850_000)
        #expect(try CloakFeeModel.calculateCloakSolFeeLamports(gross: 10_000_000) == 5_030_000)
        #expect(throws: CloakFeeError.self) {
            try CloakFeeModel.validateMinimumDeposit(9_999_999)
        }
    }

    @Test func cloakDepositDraftIsDraftOnlyAndSafeToSerialize() throws {
        let draft = try CloakDepositDraft(
            network: .mainnetBeta,
            sourceWalletAddress: SolanaConstants.systemProgramID,
            grossLamports: 50_000_000
        )

        #expect(draft.actionState == .draftOnly)
        #expect(draft.mintAddress == CloakConstants.nativeSolMint)
        #expect(draft.feeQuote.totalFeeLamports == 5_150_000)
        #expect(draft.networkWarning?.lowercased().contains("mainnet") == true)

        let data = try JSONEncoder().encode(draft)
        let json = try #require(String(data: data, encoding: .utf8)).lowercased()

        #expect(!json.contains("privatekey"))
        #expect(!json.contains("seedphrase"))
        #expect(!json.contains("mnemonic"))
        #expect(!json.contains("nullifier"))
        #expect(!json.contains("proofinput"))
    }

    @Test func cloakBridgeUnavailableCannotExecute() async {
        let bridge = CloakBridgeUnavailable()
        let request = CloakBridgeRequestSummary(
            actionKind: .deposit,
            network: .mainnetBeta,
            walletPublicAddress: SolanaConstants.systemProgramID,
            grossLamports: 50_000_000
        )

        #expect(bridge.checkAvailability() == .lockedInPhase23)
        #expect(bridge.validateEnvironment(network: .devnet).status == .locked)

        let response = await bridge.executeDeposit(request: request)
        #expect(response.status == .locked)
        #expect(response.requestID == request.id)
        #expect(response.message.contains("No SDK transaction"))
    }

    @Test func cloakBridgeContractsContainOnlySafeFields() throws {
        let quote = try CloakFeeModel.quote(grossLamports: 50_000_000)
        let request = CloakBridgeRequest(
            command: .depositPlan,
            actionKind: .deposit,
            network: .mainnetBeta,
            walletPublicAddress: SolanaConstants.systemProgramID,
            amountLamports: 50_000_000,
            mintAddress: CloakConstants.nativeSolMint,
            feeQuote: quote
        )
        let response = CloakBridgeResponse.locked(request: request)

        try CloakBridgeContractValidator.validate(request)
        try CloakBridgeContractValidator.validate(response)

        let requestJSON = try #require(String(data: JSONEncoder().encode(request), encoding: .utf8)).lowercased()
        let responseJSON = try #require(String(data: JSONEncoder().encode(response), encoding: .utf8)).lowercased()

        for forbidden in ["privatekey", "secretkey", "seedphrase", "mnemonic", "walletjson", "utxoprivatekey", "viewingkey", "nullifier", "proofinput", "serializedtransaction", "transactionpayload"] {
            #expect(!requestJSON.contains(forbidden))
            #expect(!responseJSON.contains(forbidden))
        }
    }

    @Test func cloakBridgeValidatorRejectsForbiddenFields() throws {
        #expect(CloakBridgeContractValidator.isForbiddenField("privateKey"))
        #expect(CloakBridgeContractValidator.isForbiddenField("PRIVATE_KEY"))
        #expect(CloakBridgeContractValidator.isForbiddenField("serializedTransaction"))
        #expect(CloakBridgeContractValidator.isForbiddenField("rawSignerBytes"))
        #expect(throws: CloakBridgeValidationError.self) {
            try CloakBridgeContractValidator.validate(jsonString: #"{"nested":{"viewingKey":"do-not-send"}}"#)
        }
        #expect(throws: CloakBridgeValidationError.self) {
            try CloakBridgeContractValidator.validate(jsonString: #"{"transactionPayload":"do-not-send"}"#)
        }
    }

    @Test func cloakBridgeDecodesSDKEnvironmentValidationFields() throws {
        let raw = """
        {
          "id":"33333333-3333-4333-8333-333333333333",
          "command":"env-check",
          "status":"ok",
          "errorCategory":"none",
          "message":"Environment check passed.",
          "programId":"zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW",
          "sdkValidation":{
            "sdkInstalled":true,
            "sdkImportOk":true,
            "sdkVersion":"0.1.6",
            "cloakProgramId":"zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW",
            "expectedProgramId":"zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW",
            "programIdMatches":true,
            "nativeSolMint":"So11111111111111111111111111111111111111112",
            "feeHelpersAvailable":true
          },
          "environmentValidation":{
            "solanaRpcUrlStatus":"present-redacted",
            "rpcUrlRedacted":"SOLANA_RPC_URL configured (redacted)",
            "rpcProvider":"rpcfast",
            "rpcHost":"solana-rpc.rpcfast.com",
            "rpcFastTokenStatus":"present",
            "rpcMessage":"Using RPC Fast mainnet endpoint with X-Token header.",
            "requestedNetwork":"mainnet-beta",
            "networkSupportedForFutureExecution":true,
            "helperMode":"dry-run-non-executing",
            "executionCommandsLocked":true,
            "keypairPathRequired":false,
            "walletSecretEnvAccepted":false,
            "suspiciousEnvVarNames":[]
          },
          "timestamp":"2026-01-01T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(CloakBridgeResponse.self, from: Data(raw.utf8))

        #expect(response.command == .environmentCheck)
        #expect(response.sdkValidation?.sdkVersion == "0.1.6")
        #expect(response.sdkValidation?.programIDMatches == true)
        #expect(response.environmentValidation?.solanaRPCURLStatus == .presentRedacted)
        #expect(response.environmentValidation?.rpcURLRedacted?.contains("redacted") == true)
        #expect(response.environmentValidation?.rpcProvider == "rpcfast")
        #expect(response.environmentValidation?.rpcHost == "solana-rpc.rpcfast.com")
        #expect(response.environmentValidation?.rpcFastTokenStatus == "present")
        #expect(response.environmentValidation?.walletSecretEnvAccepted == false)
    }

    @Test func cloakBridgeExecutionPolicyDisablesHelperByDefault() {
        let policy = CloakBridgeExecutionPolicy.disabled

        #expect(!policy.helperExecutionEnabled)
        #expect(policy.canInvokeHelper(command: .health, relativePath: policy.allowlistedHelperRelativePath) == false)
        #expect(policy.allowedCommands.contains(.health))
        #expect(policy.allowedCommands.contains(.environmentCheck))
        #expect(policy.allowedCommands.contains(.depositPlan))
        #expect(!policy.allowedCommands.contains(.executeDeposit))
        #expect(!CloakBridgeCommand.executeDeposit.isHelperCommandAllowedInPhase23)
    }

    @Test func cloakBridgeDepositPlanResponseStaysLocked() throws {
        let draft = try CloakDepositDraft(
            network: .mainnetBeta,
            sourceWalletAddress: SolanaConstants.systemProgramID,
            grossLamports: 50_000_000
        )
        let response = CloakBridgeUnavailable().depositPlan(draft: draft)

        #expect(response.command == .depositPlan)
        #expect(response.status == .locked)
        #expect(response.errorCategory == .lockedInPhase23)
        #expect(response.feeQuote?.totalFeeLamports == 5_150_000)
        #expect(response.transactionSignature == nil)
        #expect(response.commitmentPrefix == nil)
    }

    @Test func cloakHelperDisabledByDefaultDoesNotInvokeRunner() async {
        let runner = MockCloakHelperProcessRunner(response: .success(.okResponse(command: .health)))
        let adapter = CloakHelperInvocationAdapter(
            policy: .disabled,
            projectRoot: URL(fileURLWithPath: "/tmp/gorkh"),
            pathResolver: MockCloakHelperPathResolver(),
            processRunner: runner
        )
        let response = await adapter.invoke(CloakBridgeRequest(command: .health, network: .mainnetBeta))

        #expect(response.status == .locked)
        #expect(response.errorCategory == .lockedInPhase23)
        #expect(runner.invocationCount == 0)
    }

    @Test func cloakHelperAllowlistedCommandSucceedsWithMockRunner() async {
        let runner = MockCloakHelperProcessRunner(response: .success(.okResponse(command: .health)))
        let adapter = CloakHelperInvocationAdapter(
            policy: .dryRunEnabledForDevelopment(allowedNodeExecutablePaths: ["/usr/bin/node"]),
            projectRoot: URL(fileURLWithPath: "/tmp/gorkh"),
            pathResolver: MockCloakHelperPathResolver(),
            processRunner: runner
        )
        let response = await adapter.invoke(CloakBridgeRequest(command: .health, network: .mainnetBeta))

        #expect(response.status == .ok)
        #expect(response.command == .health)
        #expect(runner.invocationCount == 1)
        #expect(runner.lastCommand == .health)
    }

    @Test func cloakHelperDepositPlanDryRunReturnsNoExecutablePayload() async throws {
        let quote = try CloakFeeModel.quote(grossLamports: 50_000_000)
        let runner = MockCloakHelperProcessRunner(response: .success(.okResponse(
            command: .depositPlan,
            status: .locked,
            errorCategory: .lockedInPhase23,
            feeQuote: quote
        )))
        let adapter = CloakHelperInvocationAdapter(
            policy: .dryRunEnabledForDevelopment(allowedNodeExecutablePaths: ["/usr/bin/node"]),
            projectRoot: URL(fileURLWithPath: "/tmp/gorkh"),
            pathResolver: MockCloakHelperPathResolver(),
            processRunner: runner
        )
        let response = await adapter.invoke(CloakBridgeRequest(
            command: .depositPlan,
            actionKind: .deposit,
            network: .mainnetBeta,
            walletPublicAddress: SolanaConstants.systemProgramID,
            amountLamports: 50_000_000,
            mintAddress: CloakConstants.nativeSolMint,
            feeQuote: quote
        ))

        #expect(response.status == .locked)
        #expect(response.feeQuote?.totalFeeLamports == 5_150_000)
        #expect(response.transactionSignature == nil)
        #expect(response.commitmentPrefix == nil)
    }

    @Test func cloakHelperDecodesTypeScriptDepositPlanResponse() async throws {
        let raw = """
        {
          "id":"11111111-1111-4111-8111-111111111111",
          "requestId":"22222222-2222-4222-8222-222222222222",
          "command":"deposit-plan",
          "actionKind":"deposit",
          "status":"locked",
          "errorCategory":"locked-in-phase-2-3",
          "message":"Deposit plan created with SDK import validation. No transaction payload is returned in Phase 2.3.",
          "programId":"zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW",
          "feeQuote":{
            "grossLamports":"50000000",
            "fixedFeeLamports":"5000000",
            "variableFeeLamports":"150000",
            "totalFeeLamports":"5150000",
            "netLamports":"44850000",
            "minimumDepositLamports":"10000000"
          },
          "sdkValidation":{
            "sdkInstalled":true,
            "sdkImportOk":true,
            "sdkVersion":"0.1.6",
            "cloakProgramId":"zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW",
            "expectedProgramId":"zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW",
            "programIdMatches":true,
            "nativeSolMint":"So11111111111111111111111111111111111111112",
            "feeHelpersAvailable":true
          },
          "feeValidation":{
            "available":true,
            "source":"sdk",
            "samples":[
              {
                "grossLamports":"50000000",
                "gorkhFeeLamports":"5150000",
                "gorkhNetLamports":"44850000",
                "sdkFeeLamports":"5150000",
                "sdkNetLamports":"44850000",
                "matches":true
              }
            ],
            "message":"Cloak SDK SOL fee helpers match the GORKH local model for sample values."
          },
          "nextRequiredGates":["signer bridge","wallet unlock","LocalAuthentication","Shield review","explicit approval","audit log","tiny mainnet smoke"],
          "timestamp":"2026-01-01T00:00:00Z"
        }
        """
        let adapter = CloakHelperInvocationAdapter(
            policy: .dryRunEnabledForDevelopment(allowedNodeExecutablePaths: ["/usr/bin/node"]),
            projectRoot: URL(fileURLWithPath: "/tmp/gorkh"),
            pathResolver: MockCloakHelperPathResolver(),
            processRunner: MockCloakHelperProcessRunner(rawStdout: raw)
        )
        let response = await adapter.invoke(CloakBridgeRequest(
            command: .depositPlan,
            actionKind: .deposit,
            network: .mainnetBeta,
            walletPublicAddress: SolanaConstants.systemProgramID,
            amountLamports: 50_000_000,
            mintAddress: CloakConstants.nativeSolMint,
            feeQuote: try CloakFeeModel.quote(grossLamports: 50_000_000)
        ))

        #expect(response.command == .depositPlan)
        #expect(response.errorCategory == .lockedInPhase23)
        #expect(response.feeQuote?.totalFeeLamports == 5_150_000)
        #expect(response.sdkValidation?.sdkImportOk == true)
        #expect(response.sdkValidation?.programIDMatches == true)
        #expect(response.sdkValidation?.nativeSOLMint == CloakConstants.nativeSolMint)
        #expect(response.feeValidation?.allSamplesMatch == true)
        #expect(response.nextRequiredGates?.contains("Shield review") == true)
        #expect(response.transactionSignature == nil)
    }

    @Test func cloakHelperForbiddenCommandIsRejectedBeforeRunner() async {
        let runner = MockCloakHelperProcessRunner(response: .success(.okResponse(command: .executeDeposit)))
        let adapter = CloakHelperInvocationAdapter(
            policy: .dryRunEnabledForDevelopment(allowedNodeExecutablePaths: ["/usr/bin/node"]),
            projectRoot: URL(fileURLWithPath: "/tmp/gorkh"),
            pathResolver: MockCloakHelperPathResolver(),
            processRunner: runner
        )
        let response = await adapter.invoke(CloakBridgeRequest(command: .executeDeposit, actionKind: .deposit, network: .mainnetBeta))

        #expect(response.status == .locked)
        #expect(response.errorCategory == .unsupportedCommand)
        #expect(runner.invocationCount == 0)
    }

    @Test func cloakHelperRejectsUserControlledExecutableAndShellPaths() {
        let resolver = CloakHelperPathResolver()

        #expect(throws: CloakHelperPathError.self) {
            _ = try resolver.resolveNodeExecutable(candidates: ["/bin/sh"])
        }
        #expect(throws: CloakHelperPathError.self) {
            _ = try resolver.resolve(policy: CloakBridgeExecutionPolicy(
                helperExecutionEnabled: true,
                allowlistedHelperRelativePath: "../tools/cloak-bridge/src/index.ts",
                allowedNodeExecutablePaths: ["/usr/bin/node"],
                allowedCommands: [.health]
            ), projectRoot: URL(fileURLWithPath: "/tmp/gorkh"))
        }
    }

    @Test func cloakHelperForbiddenResponseIsRejectedByValidator() async {
        let runner = MockCloakHelperProcessRunner(rawStdout: #"{"command":"health","status":"ok","errorCategory":"none","programId":"zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW","message":"bad","timestamp":"2026-01-01T00:00:00Z","viewingKey":"no"}"#)
        let adapter = CloakHelperInvocationAdapter(
            policy: .dryRunEnabledForDevelopment(allowedNodeExecutablePaths: ["/usr/bin/node"]),
            projectRoot: URL(fileURLWithPath: "/tmp/gorkh"),
            pathResolver: MockCloakHelperPathResolver(),
            processRunner: runner
        )
        let response = await adapter.invoke(CloakBridgeRequest(command: .health, network: .mainnetBeta))

        #expect(response.status == .locked)
        #expect(response.errorCategory == .forbiddenField)
    }

    @Test func cloakHelperStderrRedactionRemovesSensitiveMaterial() {
        #expect(CloakHelperStderrRedactor.redact("privateKey=abc") == "[redacted cloak helper stderr]")
        #expect(CloakHelperStderrRedactor.redact("safe warning").contains("safe warning"))
    }

    @Test func cloakPrivateVaultStatusOnlyStoresNoPrivateReferences() {
        let walletID = UUID()
        let vault = CloakPrivateVaultStatusOnly()
        let status = vault.status(for: walletID)

        #expect(status.walletID == walletID)
        #expect(status.privateWalletStatus == .statusOnly)
        #expect(status.availableReferenceKinds.isEmpty)
        #expect(!status.hasViewingKeyReference)
        #expect(!status.hasUtxoReference)
        #expect(!status.hasScanCacheReference)
        #expect(!status.canClearPrivateData)
        #expect(throws: CloakPrivateVaultError.self) {
            try vault.storeReference(kind: .viewingKeyReference, referenceID: "reference-only", for: walletID)
        }
    }

    @Test func cloakAuditEventsDropPrivateMaterialKeys() throws {
        let event = AuditEvent(
            kind: .cloakDepositDraftCreated,
            walletID: UUID(),
            network: .mainnetBeta,
            publicAddress: SolanaConstants.systemProgramID,
            message: "Cloak draft",
            details: [
                "grossLamports": "50000000",
                "cloakNote": "do-not-store",
                "utxoPrivateKey": "do-not-store",
                "viewingKey": "do-not-store",
                "nullifierSecret": "do-not-store",
                "proofInput": "do-not-store"
            ]
        )

        let data = try JSONEncoder().encode(event)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("50000000"))
        #expect(!json.contains("do-not-store"))
        #expect(!json.contains("cloakNote"))
        #expect(!json.contains("utxoPrivateKey"))
        #expect(!json.contains("viewingKey"))
        #expect(!json.contains("nullifierSecret"))
        #expect(!json.contains("proofInput"))
    }

    @Test func cloakSignerRequestSummarySerializationHasNoForbiddenFields() throws {
        let draft = try CloakDepositDraft(
            network: .mainnetBeta,
            sourceWalletAddress: SolanaConstants.systemProgramID,
            grossLamports: 50_000_000
        )
        let request = CloakSignerRequestSummary.depositPreview(draft: draft)

        try CloakBridgeContractValidator.validate(request)
        try CloakSignerBridgeValidator.validate(request, expectedWalletPublicKey: SolanaConstants.systemProgramID)

        let data = try JSONEncoder().encode(request)
        let json = try #require(String(data: data, encoding: .utf8)).lowercased()

        #expect(json.contains("draftfingerprint"))
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "utxoprivatekey", "viewingkey", "nullifier", "proofinput", "serializedtransaction", "transactionpayload", "transactionbytes", "messagebytes"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func cloakSignerValidatorRejectsUnsafeOrMismatchedRequests() throws {
        let valid = CloakSignerRequestSummary(
            requestKind: .signTransactionPreview,
            walletPublicKey: SolanaConstants.systemProgramID,
            network: .mainnetBeta,
            actionKind: .deposit,
            amountLamports: 50_000_000,
            mintAddress: CloakConstants.nativeSolMint,
            feeQuote: try CloakFeeModel.quote(grossLamports: 50_000_000),
            humanReadableSummary: "safe",
            expectedTransactionPurpose: "safe",
            expectedMessagePurpose: "safe",
            draftFingerprint: "abc123"
        )

        #expect(throws: CloakSignerBridgeValidationError.self) {
            try CloakSignerBridgeValidator.validate(CloakSignerRequestSummary(
                requestKind: valid.requestKind,
                walletPublicKey: valid.walletPublicKey,
                network: valid.network,
                actionKind: valid.actionKind,
                amountLamports: valid.amountLamports,
                mintAddress: valid.mintAddress,
                programID: "bad-program",
                feeQuote: valid.feeQuote,
                humanReadableSummary: valid.humanReadableSummary,
                expectedTransactionPurpose: valid.expectedTransactionPurpose,
                expectedMessagePurpose: valid.expectedMessagePurpose,
                draftFingerprint: valid.draftFingerprint
            ))
        }
        #expect(throws: CloakSignerBridgeValidationError.self) {
            try CloakSignerBridgeValidator.validate(CloakSignerRequestSummary(
                requestKind: valid.requestKind,
                walletPublicKey: valid.walletPublicKey,
                network: .devnet,
                actionKind: valid.actionKind,
                amountLamports: valid.amountLamports,
                mintAddress: valid.mintAddress,
                feeQuote: valid.feeQuote,
                humanReadableSummary: valid.humanReadableSummary,
                expectedTransactionPurpose: valid.expectedTransactionPurpose,
                expectedMessagePurpose: valid.expectedMessagePurpose,
                draftFingerprint: valid.draftFingerprint
            ))
        }
        #expect(throws: CloakSignerBridgeValidationError.self) {
            try CloakSignerBridgeValidator.validate(CloakSignerRequestSummary(
                requestKind: valid.requestKind,
                walletPublicKey: valid.walletPublicKey,
                network: valid.network,
                actionKind: valid.actionKind,
                amountLamports: 9_999_999,
                mintAddress: valid.mintAddress,
                feeQuote: nil,
                humanReadableSummary: valid.humanReadableSummary,
                expectedTransactionPurpose: valid.expectedTransactionPurpose,
                expectedMessagePurpose: valid.expectedMessagePurpose,
                draftFingerprint: valid.draftFingerprint
            ))
        }
        #expect(throws: CloakSignerBridgeValidationError.self) {
            try CloakSignerBridgeValidator.validate(CloakSignerRequestSummary(
                requestKind: valid.requestKind,
                walletPublicKey: valid.walletPublicKey,
                network: valid.network,
                actionKind: valid.actionKind,
                amountLamports: valid.amountLamports,
                mintAddress: valid.mintAddress,
                feeQuote: valid.feeQuote,
                humanReadableSummary: valid.humanReadableSummary,
                expectedTransactionPurpose: valid.expectedTransactionPurpose,
                expectedMessagePurpose: valid.expectedMessagePurpose,
                draftFingerprint: ""
            ))
        }
        #expect(throws: CloakSignerBridgeValidationError.self) {
            try CloakSignerBridgeValidator.validate(valid, expectedWalletPublicKey: "different-wallet")
        }
    }

    @Test func cloakSignerPolicyReturnsLockedAndRequiresAllApprovalGates() throws {
        let draft = try CloakDepositDraft(
            network: .mainnetBeta,
            sourceWalletAddress: SolanaConstants.systemProgramID,
            grossLamports: 50_000_000
        )
        let request = CloakSignerRequestSummary.depositPreview(draft: draft)
        let result = CloakSignerBridgePolicy.locked.signingDecision(
            request: request,
            expectedWalletPublicKey: SolanaConstants.systemProgramID
        )

        #expect(result.state == .locked)
        #expect(result.failures.contains("Signing is not enabled for Cloak in Phase 2.4."))
        #expect(result.requirements.contains(.walletUnlocked))
        #expect(result.requirements.contains(.localAuthentication))
        #expect(result.requirements.contains(.shieldReviewCompleted))
        #expect(result.requirements.contains(.explicitUserApproval))
        #expect(result.requirements.contains(.mainnetConfirmationPhrase))
        #expect(result.requirements.contains(.draftFingerprintMatch))
        #expect(result.requirements.contains(.auditBeforeSigning))
        #expect(result.requirements.contains(.auditAfterSigning))
        #expect(result.requirements.contains(.executionLocked))
    }

    @Test func cloakBridgeDecodesLockedSignerPlaceholderFromHelper() throws {
        let raw = """
        {
          "id":"11111111-1111-4111-8111-111111111111",
          "requestId":"22222222-2222-4222-8222-222222222222",
          "command":"deposit-plan",
          "actionKind":"deposit",
          "status":"locked",
          "errorCategory":"locked-in-phase-2-3",
          "message":"Deposit plan created with locked signer preview.",
          "programId":"zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW",
          "feeQuote":{
            "grossLamports":"50000000",
            "fixedFeeLamports":"5000000",
            "variableFeeLamports":"150000",
            "totalFeeLamports":"5150000",
            "netLamports":"44850000",
            "minimumDepositLamports":"10000000"
          },
          "signerRequestSummary":{
            "id":"33333333-3333-4333-8333-333333333333",
            "requestKind":"sign_transaction_preview",
            "walletPublicKey":"11111111111111111111111111111111",
            "network":"mainnet-beta",
            "actionKind":"deposit",
            "amountLamports":"50000000",
            "mintAddress":"So11111111111111111111111111111111111111112",
            "programId":"zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW",
            "feeQuote":{
              "grossLamports":"50000000",
              "fixedFeeLamports":"5000000",
              "variableFeeLamports":"150000",
              "totalFeeLamports":"5150000",
              "netLamports":"44850000",
              "minimumDepositLamports":"10000000"
            },
            "humanReadableSummary":"Future Cloak SOL deposit review for 50000000 lamports.",
            "expectedTransactionPurpose":"Create a reviewed Cloak public deposit into a shielded balance.",
            "expectedMessagePurpose":"Future viewing-key registration may require a separately reviewed message signature.",
            "draftFingerprint":"abc123",
            "approvalState":"locked",
            "bridgeState":"locked",
            "timestamp":"2026-01-01T00:00:00Z"
          },
          "timestamp":"2026-01-01T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(CloakBridgeResponse.self, from: Data(raw.utf8))

        #expect(response.signerRequestSummary?.requestKind == .signTransactionPreview)
        #expect(response.signerRequestSummary?.amountLamports == 50_000_000)
        #expect(response.signerRequestSummary?.bridgeState == .locked)
        #expect(response.signerRequestSummary?.programID == CloakConstants.programID)
        #expect(response.transactionSignature == nil)
    }

    @Test func cloakSigningRequestValidatorRequiresExactApprovedContext() throws {
        let requestID = UUID()
        let fingerprint = "approved-fingerprint"
        let request = try CloakBridgeSigningRequest.testRequest(
            requestID: requestID,
            fingerprint: fingerprint
        )
        let context = CloakSigningApprovalContext(
            requestID: requestID,
            command: .executeDeposit,
            actionKind: .deposit,
            walletPublicKey: SolanaConstants.systemProgramID,
            network: .mainnetBeta,
            amountLamports: 50_000_000,
            mintAddress: CloakConstants.nativeSolMint,
            programID: CloakConstants.programID,
            approvedDraftFingerprint: fingerprint,
            feeAcknowledged: true,
            shieldReviewCompleted: true,
            explicitApproval: true,
            mainnetConfirmation: TransactionApprovalPolicy.requiredMainnetConfirmation
        )

        try CloakSigningRequestValidator.validate(request, context: context)

        #expect(throws: CloakExecutionBridgeError.self) {
            try CloakSigningRequestValidator.validate(
                request.replacing(programID: "bad-program"),
                context: context
            )
        }
        #expect(throws: CloakExecutionBridgeError.self) {
            try CloakSigningRequestValidator.validate(
                request.replacing(walletPublicKey: "different-wallet"),
                context: context
            )
        }
        #expect(throws: CloakExecutionBridgeError.self) {
            try CloakSigningRequestValidator.validate(
                request.replacing(amountLamports: 49_999_999),
                context: context
            )
        }
        #expect(throws: CloakExecutionBridgeError.self) {
            try CloakSigningRequestValidator.validate(
                request.replacing(expiresAt: Date().addingTimeInterval(-1)),
                context: context
            )
        }
        #expect(throws: CloakExecutionBridgeError.self) {
            try CloakSigningRequestValidator.validate(
                request,
                context: CloakSigningApprovalContext(
                    requestID: requestID,
                    command: .executeDeposit,
                    actionKind: .deposit,
                    walletPublicKey: SolanaConstants.systemProgramID,
                    network: .mainnetBeta,
                    amountLamports: 50_000_000,
                    mintAddress: CloakConstants.nativeSolMint,
                    programID: CloakConstants.programID,
                    approvedDraftFingerprint: fingerprint,
                    feeAcknowledged: true,
                    shieldReviewCompleted: true,
                    explicitApproval: false,
                    mainnetConfirmation: TransactionApprovalPolicy.requiredMainnetConfirmation
                )
            )
        }
    }

    @Test func cloakPrivateRecordMetadataAndExecutionFramesStaySafeToSerialize() throws {
        let metadata = CloakPrivateRecordMetadata(
            id: UUID(),
            walletID: UUID(),
            walletPublicKey: SolanaConstants.systemProgramID,
            mintAddress: CloakConstants.nativeSolMint,
            amountLamports: 44_850_000,
            commitmentPrefix: "abcdef123456",
            leafIndex: 7,
            depositSignature: "depositSignature",
            withdrawSignature: nil,
            requestID: UUID(),
            state: .deposited,
            createdAt: Date(),
            updatedAt: Date()
        )
        let frame = CloakExecutionResultFrame(
            type: "result",
            response: CloakBridgeResponse(
                requestID: metadata.requestID,
                command: .executeDeposit,
                actionKind: .deposit,
                status: .ok,
                message: "safe",
                transactionSignature: "depositSignature",
                commitmentPrefix: "abcdef123456"
            ),
            secureOutputStateBase64: Data([1, 2, 3]).base64EncodedString(),
            secureViewingStateBase64: Data([4, 5, 6]).base64EncodedString(),
            secureSpentStateBase64: nil,
            leafIndex: 7
        )

        try CloakBridgeContractValidator.validate(metadata)
        try CloakBridgeContractValidator.validate(frame.response)

        let combined = try #require(String(
            data: JSONEncoder().encode([String(data: JSONEncoder().encode(metadata), encoding: .utf8) ?? ""]),
            encoding: .utf8
        )).lowercased()
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "utxoprivatekey", "nullifier", "proofinput", "transactionpayload"] {
            #expect(!combined.contains(forbidden))
        }
        #expect(frame.response.transactionSignature == "depositSignature")
        #expect(frame.secureOutputStateBase64 != nil)
    }

    @Test func cloakPhase25AllowsOnlyDepositAndFullWithdrawExecutionCommands() {
        let policy = CloakBridgeExecutionPolicy.phase25Enabled(allowedNodeExecutablePaths: ["/usr/bin/node"])

        #expect(policy.allowedCommands.contains(.executeDeposit))
        #expect(policy.allowedCommands.contains(.fullWithdraw))
        #expect(CloakBridgeCommand.executeDeposit.isHelperCommandAllowedInPhase25)
        #expect(CloakBridgeCommand.fullWithdraw.isHelperCommandAllowedInPhase25)
        #expect(!policy.allowedCommands.contains(.partialWithdraw))
        #expect(!CloakBridgeCommand.partialWithdraw.isHelperCommandAllowedInPhase25)
        #expect(!CloakBridgeCommand.privateTransfer.isHelperCommandAllowedInPhase25)
        #expect(!CloakBridgeCommand.swap.isHelperCommandAllowedInPhase25)
    }

    @Test func cloakPhase26AddsReadOnlyScanWithoutPartialWithdraw() {
        let policy = CloakBridgeExecutionPolicy.phase26Enabled(allowedNodeExecutablePaths: ["/usr/bin/node"])

        #expect(policy.allowedCommands.contains(.scan))
        #expect(policy.canInvokeHelper(command: .scan, relativePath: policy.allowlistedHelperRelativePath))
        #expect(CloakBridgeCommand.scan.isHelperCommandAllowedInPhase26)
        #expect(!policy.allowedCommands.contains(.partialWithdraw))
        #expect(!CloakBridgeCommand.partialWithdraw.isHelperCommandAllowedInPhase26)
        #expect(!CloakBridgeCommand.complianceExport.isHelperCommandAllowedInPhase26)
    }

    @Test func cloakScanSummarySerializesWithoutSecretFields() throws {
        let summary = CloakScanSummary(
            status: .loaded,
            transactions: [
                CloakScanTransactionSummary(
                    signature: "scanSignature",
                    txType: "deposit",
                    amountLamports: "10000000",
                    feeLamports: "5000000",
                    netAmountLamports: "5000000",
                    runningBalanceLamports: "5000000",
                    timestampMillis: "1767225600000",
                    recipient: nil,
                    commitmentPrefix: "abcdef123456",
                    mintAddress: CloakConstants.nativeSolMint,
                    symbol: "SOL",
                    status: "scanned"
                )
            ],
            totalDepositsLamports: "10000000",
            totalWithdrawalsLamports: "0",
            totalFeesLamports: "5000000",
            netChangeLamports: "5000000",
            finalBalanceLamports: "5000000",
            transactionCount: 1,
            scannedAt: Date(),
            lastSignature: "scanSignature",
            errorMessage: nil,
            rpcProvider: "rpcfast",
            rpcHost: "solana-rpc.rpcfast.com",
            complianceSummary: CloakComplianceSummary(
                transactionCount: 1,
                totalDepositsLamports: "10000000",
                totalWithdrawalsLamports: "0",
                totalFeesLamports: "5000000",
                netChangeLamports: "5000000",
                finalBalanceLamports: "5000000",
                mintBreakdown: [
                    CloakComplianceMintBreakdown(mintAddress: CloakConstants.nativeSolMint, symbol: "SOL", netLamports: "5000000")
                ],
                dateRangeStart: "1767225600000",
                dateRangeEnd: "1767225600000",
                generatedAt: Date()
            )
        )

        try CloakBridgeContractValidator.validate(summary)
        let json = try #require(String(data: JSONEncoder().encode(summary), encoding: .utf8)).lowercased()
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "utxoprivatekey", "viewingkey", "nullifier", "proofinput", "transactionpayload", "serializedtransaction"] {
            #expect(!json.contains(forbidden))
        }
        #expect(json.contains("scansignature"))
        #expect(json.contains("solana-rpc.rpcfast.com"))
    }

    @Test func cloakScanCacheClearKeepsOnlySafeSummaries() throws {
        let suiteName = "ai.gorkh.tests.cloak.scan.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CloakScanCacheStore(defaults: defaults)
        let walletID = UUID()
        let summary = CloakScanSummary(
            status: .empty,
            transactions: [],
            totalDepositsLamports: "0",
            totalWithdrawalsLamports: "0",
            totalFeesLamports: "0",
            netChangeLamports: "0",
            finalBalanceLamports: "0",
            transactionCount: 0,
            scannedAt: Date(),
            lastSignature: nil,
            errorMessage: nil,
            rpcProvider: "fallback",
            rpcHost: "api.mainnet-beta.solana.com",
            complianceSummary: nil
        )

        store.upsert(summary: summary, walletID: walletID)
        #expect(store.load(walletID: walletID)?.status == .empty)
        let persisted = try #require(defaults.data(forKey: CloakScanCacheStore.cacheKey))
        let persistedText = try #require(String(data: persisted, encoding: .utf8)).lowercased()
        #expect(!persistedText.contains("viewingkey"))
        #expect(!persistedText.contains("utxoprivatekey"))
        #expect(!persistedText.contains("nullifier"))
        #expect(!persistedText.contains("proofinput"))

        store.clear(walletID: walletID)
        #expect(store.load(walletID: walletID) == nil)
    }

    @Test func cloakActivityReconcilerReportsMatchedLocalOnlyAndChainOnly() {
        let walletID = UUID()
        let localMatched = CloakPrivateRecordMetadata(
            id: UUID(),
            walletID: walletID,
            walletPublicKey: SolanaConstants.systemProgramID,
            mintAddress: CloakConstants.nativeSolMint,
            amountLamports: 10_000_000,
            commitmentPrefix: "localmatch",
            leafIndex: 1,
            depositSignature: "matchedSignature",
            withdrawSignature: nil,
            requestID: UUID(),
            state: .deposited,
            createdAt: Date(),
            updatedAt: Date()
        )
        let localOnly = CloakPrivateRecordMetadata(
            id: UUID(),
            walletID: walletID,
            walletPublicKey: SolanaConstants.systemProgramID,
            mintAddress: CloakConstants.nativeSolMint,
            amountLamports: 20_000_000,
            commitmentPrefix: "localonly",
            leafIndex: 2,
            depositSignature: "localOnlySignature",
            withdrawSignature: nil,
            requestID: UUID(),
            state: .deposited,
            createdAt: Date(),
            updatedAt: Date()
        )
        let summary = CloakScanSummary(
            status: .loaded,
            transactions: [
                CloakScanTransactionSummary(signature: "matchedSignature", txType: "deposit", amountLamports: "10000000", feeLamports: "0", netAmountLamports: "10000000", runningBalanceLamports: nil, timestampMillis: nil, recipient: nil, commitmentPrefix: "localmatch", mintAddress: CloakConstants.nativeSolMint, symbol: "SOL", status: "scanned"),
                CloakScanTransactionSummary(signature: "chainOnlySignature", txType: "withdraw", amountLamports: "5000000", feeLamports: "0", netAmountLamports: "-5000000", runningBalanceLamports: nil, timestampMillis: nil, recipient: nil, commitmentPrefix: "chainonly", mintAddress: CloakConstants.nativeSolMint, symbol: "SOL", status: "scanned")
            ],
            totalDepositsLamports: "10000000",
            totalWithdrawalsLamports: "5000000",
            totalFeesLamports: "0",
            netChangeLamports: "5000000",
            finalBalanceLamports: "5000000",
            transactionCount: 2,
            scannedAt: Date(),
            lastSignature: "chainOnlySignature",
            errorMessage: nil,
            rpcProvider: "rpcfast",
            rpcHost: "solana-rpc.rpcfast.com",
            complianceSummary: nil
        )

        let reconciled = CloakActivityReconciler.reconcile(localRecords: [localMatched, localOnly], scanSummary: summary)

        #expect(reconciled.contains { $0.state == .matched && $0.chainSignature == "matchedSignature" })
        #expect(reconciled.contains { $0.state == .localOnly && $0.chainSignature == "localOnlySignature" })
        #expect(reconciled.contains { $0.state == .chainOnly && $0.chainSignature == "chainOnlySignature" })
    }

    @Test func cloakScanPolicyRequiresMainnetUnlockAndScanCredential() {
        let status = CloakVaultStatus(
            walletID: UUID(),
            privateWalletStatus: .ready,
            availableReferenceKinds: [.encryptedUtxoReference, .viewingKeyReference],
            storageDescription: "ready",
            canClearPrivateData: true
        )

        #expect(CloakScanPolicy.credentialStatus(vaultStatus: status, vaultState: .unlocked) == .stored)
        #expect(CloakScanPolicy.canScan(vaultStatus: status, vaultState: .unlocked, network: .mainnetBeta))
        #expect(!CloakScanPolicy.canScan(vaultStatus: status, vaultState: .locked, network: .mainnetBeta))
        #expect(!CloakScanPolicy.canScan(vaultStatus: status, vaultState: .unlocked, network: .devnet))
    }

    @Test func portfolioModelsAndSnapshotsSerializeWithoutSecrets() throws {
        let profile = WalletProfile(label: "Portfolio", publicAddress: SolanaConstants.systemProgramID)
        let token = sampleTokenBalance(owner: profile.publicAddress, amountRaw: 1_000_000, decimals: 6)
        let prices = [
            PortfolioConstants.nativeSolMint: PortfolioPriceQuote(
                mintAddress: PortfolioConstants.nativeSolMint,
                usdPrice: 100,
                source: PortfolioConstants.priceSource,
                blockID: 1,
                priceChange24h: nil,
                fetchedAt: Date(),
                errorMessage: nil
            )
        ]
        let summary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .devnet,
            profiles: [profile],
            solBalances: [profile.id: 1_000_000_000],
            tokenBalances: [profile.id: [token]],
            prices: prices
        )
        let snapshot = PortfolioSnapshot(summary: summary)
        let json = try #require(String(data: JSONEncoder().encode(snapshot), encoding: .utf8)).lowercased()

        #expect(json.contains("portfolio"))
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func portfolioAggregationHandlesSolSplAndMissingPrices() throws {
        let profile = WalletProfile(label: "Portfolio", publicAddress: SolanaConstants.systemProgramID)
        let token = sampleTokenBalance(
            owner: profile.publicAddress,
            mint: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
            amountRaw: 2_500_000,
            decimals: 6
        )
        let prices = [
            PortfolioConstants.nativeSolMint: PortfolioPriceQuote(
                mintAddress: PortfolioConstants.nativeSolMint,
                usdPrice: 100,
                source: PortfolioConstants.priceSource,
                blockID: 1,
                priceChange24h: nil,
                fetchedAt: Date(),
                errorMessage: nil
            )
        ]

        let summary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .mainnetBeta,
            profiles: [profile],
            solBalances: [profile.id: 2_000_000_000],
            tokenBalances: [profile.id: [token]],
            prices: prices
        )

        #expect(summary.wallets.count == 1)
        #expect(summary.assetCount == 2)
        #expect(summary.totalUSD == 200)
        #expect(summary.unavailablePriceCount == 1)
        #expect(summary.wallets[0].assets.contains { $0.asset.symbol == "USDC" && $0.usdValue == nil })
    }

    @Test func pusdAggregatesAcrossWalletsWithStablecoinPegFallback() throws {
        let signer = WalletProfile(label: "Treasury", publicAddress: SolanaConstants.systemProgramID)
        let watch = WalletProfile(
            label: "Watch Treasury",
            publicAddress: Base58.encode(Data(repeating: 6, count: 32)),
            walletOrigin: .watchOnly,
            profileKind: .watchOnly
        )
        let signerPUSD = sampleTokenBalance(
            owner: signer.publicAddress,
            mint: PUSDConstants.mintAddress,
            amountRaw: 1_500_000,
            decimals: 6
        )
        let watchPUSD = sampleTokenBalance(
            owner: watch.publicAddress,
            mint: PUSDConstants.mintAddress,
            amountRaw: 2_000_000,
            decimals: 6
        )

        let summary = PortfolioAggregator.aggregate(
            scope: .allWallets,
            network: .mainnetBeta,
            profiles: [signer, watch],
            solBalances: [signer.id: 0, watch.id: 0],
            tokenBalances: [
                signer.id: [signerPUSD],
                watch.id: [watchPUSD]
            ],
            prices: [:]
        )

        let pusd = try #require(summary.consolidatedAssets.first { $0.mintAddress == PUSDConstants.mintAddress })
        #expect(pusd.totalAmountRaw == 3_500_000)
        #expect(pusd.totalUSD == Decimal(string: "3.5", locale: Locale(identifier: "en_US_POSIX")))
        #expect(pusd.priceQuote?.source == PUSDConstants.stablecoinPegEstimateSource)
        #expect(summary.pusdTreasurySummary.totalAmountRaw == 3_500_000)
        #expect(summary.pusdTreasurySummary.holdingWalletCount == 2)
        #expect(summary.pusdTreasurySummary.watchOnlyAmountRaw == 2_000_000)
        #expect(summary.pusdTreasurySummary.watchOnlyWalletCount == 1)
        #expect(summary.pusdTreasurySummary.priceSource == .stablecoinPegEstimate)
        #expect(summary.pusdTreasurySummary.priceSourceDescription == PUSDConstants.pegEstimateDescription)
    }

    @Test func pusdSendPolicyReusesExistingSPLFlowAndKeepsFutureActionsLocked() {
        let token = sampleTokenBalance(
            mint: PUSDConstants.mintAddress,
            amountRaw: 1_000_000,
            decimals: 6,
            programKind: .splToken,
            state: .initialized
        )
        let metadata = TokenMetadataResolver.resolve(balance: token, network: .mainnetBeta)

        #expect(PUSDActionPolicy.sendFlow == .existingSPLTransferApprovalFlow)
        #expect(TokenMetadataResolver.canSend(balance: token, metadata: metadata))
        #expect(PUSDActionPolicy.lockedFutureActions.contains(.mintRedeem))
        #expect(PUSDActionPolicy.lockedFutureActions.contains(.bridge))
        #expect(PUSDActionPolicy.lockedFutureActions.contains(.yield))
    }

    @Test func pusdCirculationNormalizationHandlesLoadedAndRateLimitedResponses() throws {
        let data = """
        {
          "data": {
            "totalCirculating": "1234.56",
            "updatedAt": "2026-05-09T12:00:00Z",
            "chains": [
              { "chain": "Solana", "amount": "1000.25" },
              { "chain": "Ethereum", "amount": "234.31" }
            ]
          }
        }
        """.data(using: .utf8)!

        let snapshot = try PUSDCirculationClient.normalize(
            data: data,
            statusCode: 200,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(snapshot.status == .loaded)
        #expect(snapshot.totalCirculating == Decimal(string: "1234.56", locale: Locale(identifier: "en_US_POSIX")))
        #expect(snapshot.solanaCirculating == Decimal(string: "1000.25", locale: Locale(identifier: "en_US_POSIX")))
        #expect(snapshot.chainTotals.count == 2)
        #expect(snapshot.updatedAt != nil)

        let liveShape = """
        {
          "count": 1,
          "data": [
            {
              "as_of": "2026-04-24T14:30:00Z",
              "chains": [
                { "chain": "ETHEREUM", "circulating": 2826036007.115771 },
                { "chain": "SOLANA", "circulating": 2895000 },
                { "chain": "BSC", "circulating": 20000 },
                { "chain": "ADI", "circulating": 0 }
              ],
              "total_circulating": 2828951007.115771
            }
          ]
        }
        """.data(using: .utf8)!
        let liveSnapshot = try PUSDCirculationClient.normalize(data: liveShape, statusCode: 200)
        #expect(liveSnapshot.totalCirculating != nil)
        #expect(liveSnapshot.solanaCirculating == Decimal(2_895_000))
        #expect(liveSnapshot.chainTotals.count == 4)
        #expect(liveSnapshot.updatedAt != nil)

        do {
            _ = try PUSDCirculationClient.normalize(data: Data("{}".utf8), statusCode: 429)
            Issue.record("Expected 429 response to be normalized as rate limited.")
        } catch let error as PUSDCirculationClientError {
            #expect(error == .rateLimited)
        }
    }

    @Test func portfolioPriceQuoteCanReportStaleState() {
        let quote = PortfolioPriceQuote(
            mintAddress: PortfolioConstants.nativeSolMint,
            usdPrice: 100,
            source: PortfolioConstants.priceSource,
            blockID: 1,
            priceChange24h: nil,
            fetchedAt: Date(timeIntervalSince1970: 0),
            errorMessage: nil
        )

        #expect(quote.isStale(relativeTo: Date(timeIntervalSince1970: 1_000), maxAgeSeconds: 300))
        #expect(!quote.isStale(relativeTo: Date(timeIntervalSince1970: 100), maxAgeSeconds: 300))
    }

    @Test func portfolioSnapshotStoreAppendsAndClearsHistory() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gorkh-portfolio-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = PortfolioSnapshotStore(fileURL: url)
        let profile = WalletProfile(label: "Portfolio", publicAddress: SolanaConstants.systemProgramID)
        let summary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .devnet,
            profiles: [profile],
            solBalances: [profile.id: 1],
            tokenBalances: [:],
            prices: [:]
        )

        try store.append(PortfolioSnapshot(summary: summary))
        #expect(store.load().count == 1)
        try store.clear()
        #expect(store.load().isEmpty)
    }

    @Test func pusdSnapshotStoresSafeTreasurySummaryOnly() throws {
        let profile = WalletProfile(label: "Treasury", publicAddress: SolanaConstants.systemProgramID)
        let pusd = sampleTokenBalance(
            owner: profile.publicAddress,
            mint: PUSDConstants.mintAddress,
            amountRaw: 4_200_000,
            decimals: 6
        )
        let summary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .mainnetBeta,
            profiles: [profile],
            solBalances: [profile.id: 0],
            tokenBalances: [profile.id: [pusd]],
            prices: [:]
        )
        let snapshot = PortfolioSnapshot(summary: summary)
        let json = try #require(String(data: JSONEncoder().encode(snapshot), encoding: .utf8)).lowercased()

        #expect(snapshot.pusdTotalAmountRaw == 4_200_000)
        #expect(snapshot.pusdEstimatedUSD == Decimal(string: "4.2", locale: Locale(identifier: "en_US_POSIX")))
        #expect(snapshot.pusdPriceSource == PUSDConstants.stablecoinPegEstimateSource)
        #expect(snapshot.pusdHoldingWalletCount == 1)
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload", "mintredeem"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func jupiterPriceResponseNormalizationAndEndpointGuard() throws {
        let data = """
        {
          "So11111111111111111111111111111111111111112": {
            "usdPrice": 123.45,
            "blockId": 398169359,
            "decimals": 9,
            "priceChange24h": -1.25
          }
        }
        """.data(using: .utf8)!
        let prices = try JupiterPriceClient.decodePriceResponse(data: data, fetchedAt: Date(timeIntervalSince1970: 0))
        let sol = try #require(prices[PortfolioConstants.nativeSolMint])

        #expect(sol.usdPrice == Decimal(string: "123.45", locale: Locale(identifier: "en_US_POSIX")))
        #expect(sol.blockID == 398_169_359)
        #expect(sol.priceChange24h == Decimal(string: "-1.25", locale: Locale(identifier: "en_US_POSIX")))
        #expect(try JupiterPriceClient.priceURL(
            baseURL: URL(string: "https://lite-api.jup.ag/price/v3")!,
            mintAddresses: [PortfolioConstants.nativeSolMint]
        ).absoluteString.contains("/price/v3?ids="))
        #expect(throws: PortfolioPriceClientError.self) {
            try JupiterPriceClient.priceURL(
                baseURL: URL(string: "https://lite-api.jup.ag/swap/v1/swap")!,
                mintAddresses: [PortfolioConstants.nativeSolMint]
            )
        }
    }

    @Test func jupiterAPIKeyConfigurationUsesEnvironmentWithoutPuttingKeyInURLsOrAudit() throws {
        let configuration = JupiterAPIConfiguration(environment: [
            JupiterAPIConfiguration.appSpecificAPIKeyEnvironmentName: "test-jupiter-key",
            JupiterAPIConfiguration.fallbackAPIKeyEnvironmentName: "fallback-key"
        ])
        var request = URLRequest(url: try #require(URL(string: "https://api.jup.ag/swap/v1/quote")))
        configuration.applyAuthentication(to: &request)

        #expect(configuration.apiKey == "test-jupiter-key")
        #expect(configuration.swapBaseURL.absoluteString == "https://api.jup.ag/swap/v1")
        #expect(configuration.priceBaseURL.absoluteString == "https://api.jup.ag/price/v3")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-jupiter-key")
        #expect(!configuration.swapBaseURL.absoluteString.contains("test-jupiter-key"))
        #expect(!configuration.priceBaseURL.absoluteString.contains("test-jupiter-key"))

        let safeDetails = Redaction.safeDetails([
            "x-api-key": "test-jupiter-key",
            "jupiterApiKey": "test-jupiter-key",
            "GORKH_JUPITER_API_KEY": "test-jupiter-key",
            "JUPITER_API_KEY": "test-jupiter-key",
            "inputMint": PortfolioConstants.nativeSolMint
        ])
        #expect(safeDetails["inputMint"] == PortfolioConstants.nativeSolMint)
        #expect(safeDetails["x-api-key"] == nil)
        #expect(safeDetails["jupiterApiKey"] == nil)
        #expect(safeDetails["GORKH_JUPITER_API_KEY"] == nil)
        #expect(safeDetails["JUPITER_API_KEY"] == nil)
    }

    @Test func jupiterConfigurationFallsBackToLiteEndpointsWithoutAPIKey() {
        let configuration = JupiterAPIConfiguration(environment: [:])

        #expect(configuration.apiKey == nil)
        #expect(configuration.swapBaseURL.absoluteString == "https://lite-api.jup.ag/swap/v1")
        #expect(configuration.priceBaseURL.absoluteString == "https://lite-api.jup.ag/price/v3")
    }

    @Test func jupiterAPIModeAndEndpointCompatibilityBlockV2ExecutionUntilReviewed() throws {
        let configuration = JupiterAPIConfiguration(environment: [
            JupiterAPIConfiguration.appSpecificAPIKeyEnvironmentName: "test-jupiter-key"
        ])

        #expect(configuration.swapMode == .metisV1)
        #expect(configuration.swapMode.displayName == "Metis v1 compatibility mode")
        #expect(configuration.endpointCompatibility.allSatisfy { $0.canUse })

        let v1Quote = JupiterCompatibilityValidator.validate(
            url: try #require(URL(string: "https://api.jup.ag/swap/v1/quote")),
            kind: .quote,
            hasAPIKey: true
        )
        #expect(v1Quote.canUse)
        #expect(v1Quote.mode == .metisV1)

        let paidWithoutKey = JupiterCompatibilityValidator.validate(
            url: try #require(URL(string: "https://api.jup.ag/swap/v1/quote")),
            kind: .quote,
            hasAPIKey: false
        )
        #expect(!paidWithoutKey.canUse)
        #expect(paidWithoutKey.blockingReasons.contains("Paid Jupiter endpoint requires an API key."))

        let v2Order = JupiterCompatibilityValidator.validate(
            url: try #require(URL(string: "https://api.jup.ag/swap/v2/order")),
            kind: .order,
            hasAPIKey: true
        )
        #expect(!v2Order.canUse)
        #expect(v2Order.mode == .swapV2OrderExecuteCandidate)
        #expect(v2Order.blockingReasons.contains("Swap V2 order/execute is review-only and not enabled for execution."))

        let v2Execute = JupiterCompatibilityValidator.validate(
            url: try #require(URL(string: "https://api.jup.ag/swap/v2/execute")),
            kind: .execute,
            hasAPIKey: true
        )
        #expect(!v2Execute.canUse)
        #expect(v2Execute.mode == .swapV2OrderExecuteCandidate)

        let limitOrder = JupiterCompatibilityValidator.validate(
            url: try #require(URL(string: "https://api.jup.ag/trigger/v1/createOrder")),
            kind: .limitOrder,
            hasAPIKey: true
        )
        #expect(!limitOrder.canUse)
        #expect(limitOrder.blockingReasons.contains("Limit order endpoints are forbidden in Wallet Swap."))
    }

    @Test func watchOnlyProfileMetadataHasNoSecretsAndCannotSign() throws {
        let profile = WalletProfile(
            label: "DAO Treasury",
            publicAddress: Base58.encode(Data(repeating: 7, count: 32)),
            walletOrigin: .watchOnly,
            profileKind: .watchOnly,
            colorTag: "DAO"
        )

        let data = try JSONEncoder().encode(profile)
        let json = try #require(String(data: data, encoding: .utf8)).lowercased()
        let decoded = try JSONDecoder().decode(WalletProfile.self, from: data)

        #expect(decoded.profileKind == .watchOnly)
        #expect(decoded.walletOrigin == .watchOnly)
        #expect(!decoded.canSign)
        #expect(decoded.isWatchOnly)
        #expect(json.contains("watch_only"))
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func walletManagerAddsEditsAndRemovesWatchOnlyWithoutVaultSecret() throws {
        let vault = InMemoryWalletVault()
        let suiteName = "ai.gorkh.watch.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let auditURL = FileManager.default.temporaryDirectory.appendingPathComponent("gorkh-watch-test-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: auditURL) }
        let manager = WalletManager(
            vault: vault,
            rpcClient: SolanaRPCClient(),
            auditLog: AuditLog(fileURL: auditURL),
            metadataStore: WalletMetadataStore(defaults: defaults)
        )
        let address = Base58.encode(Data(repeating: 9, count: 32))

        manager.addWatchOnlyWallet(label: "Treasury", publicAddress: "not an address", tag: nil)
        #expect(manager.profiles.isEmpty)

        manager.addWatchOnlyWallet(label: "Treasury", publicAddress: address, tag: "DAO")
        let profile = try #require(manager.selectedProfile)
        #expect(profile.profileKind == .watchOnly)
        #expect(!profile.canSign)
        #expect(!vault.containsSecret(for: profile.id))
        #expect(manager.vaultState == .missing)
        #expect(manager.auditEvents.contains { $0.kind == .watchOnlyWalletAdded })

        manager.updateWalletLabel(profileID: profile.id, label: "DAO Treasury", tag: "Ops")
        #expect(manager.selectedProfile?.label == "DAO Treasury")
        #expect(manager.selectedProfile?.colorTag == "Ops")
        #expect(manager.auditEvents.contains { $0.kind == .walletLabelUpdated })

        manager.removeWatchOnlyWallet(profileID: profile.id, confirmation: "wrong")
        #expect(manager.profiles.count == 1)

        manager.removeWatchOnlyWallet(profileID: profile.id, confirmation: "REMOVE WATCH")
        #expect(manager.profiles.isEmpty)
        #expect(manager.auditEvents.contains { $0.kind == .watchOnlyWalletRemoved })
    }

    @Test func multiWalletAggregationConsolidatesAssetsByMint() throws {
        let signer = WalletProfile(
            label: "Trading",
            publicAddress: SolanaConstants.systemProgramID,
            walletOrigin: .generatedRecovery,
            profileKind: .mnemonicDerived
        )
        let watch = WalletProfile(
            label: "Treasury",
            publicAddress: Base58.encode(Data(repeating: 8, count: 32)),
            walletOrigin: .watchOnly,
            profileKind: .watchOnly
        )
        let usdcMint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
        let signerToken = sampleTokenBalance(owner: signer.publicAddress, mint: usdcMint, amountRaw: 1_000_000, decimals: 6)
        let watchToken = sampleTokenBalance(
            tokenAccount: Base58.encode(Data(repeating: 4, count: 32)),
            owner: watch.publicAddress,
            mint: usdcMint,
            amountRaw: 2_500_000,
            decimals: 6
        )
        let prices = [
            PortfolioConstants.nativeSolMint: PortfolioPriceQuote(
                mintAddress: PortfolioConstants.nativeSolMint,
                usdPrice: 100,
                source: PortfolioConstants.priceSource,
                blockID: 1,
                priceChange24h: nil,
                fetchedAt: Date(),
                errorMessage: nil
            ),
            usdcMint: PortfolioPriceQuote(
                mintAddress: usdcMint,
                usdPrice: 1,
                source: PortfolioConstants.priceSource,
                blockID: 1,
                priceChange24h: nil,
                fetchedAt: Date(),
                errorMessage: nil
            )
        ]

        let summary = PortfolioAggregator.aggregate(
            scope: .allWallets,
            network: .mainnetBeta,
            profiles: [signer, watch],
            solBalances: [
                signer.id: 1_000_000_000,
                watch.id: 2_000_000_000
            ],
            tokenBalances: [
                signer.id: [signerToken],
                watch.id: [watchToken]
            ],
            prices: prices
        )

        #expect(summary.wallets.count == 2)
        #expect(summary.totalUSD == Decimal(string: "303.5", locale: Locale(identifier: "en_US_POSIX")))
        let usdc = try #require(summary.consolidatedAssets.first { $0.mintAddress == usdcMint })
        #expect(usdc.totalAmountRaw == 3_500_000)
        #expect(usdc.uiAmountString == "3.5")
        #expect(usdc.totalUSD == Decimal(string: "3.5", locale: Locale(identifier: "en_US_POSIX")))
        #expect(usdc.walletBreakdown.count == 2)
        #expect(usdc.walletBreakdown.contains { $0.asset.walletProfileKind == .watchOnly })
    }

    @Test func portfolioAggregationKeepsPerWalletErrorsAndSnapshotWalletKinds() throws {
        let signer = WalletProfile(label: "Signer", publicAddress: SolanaConstants.systemProgramID)
        let watch = WalletProfile(
            label: "Watch",
            publicAddress: Base58.encode(Data(repeating: 6, count: 32)),
            walletOrigin: .watchOnly,
            profileKind: .watchOnly
        )

        let summary = PortfolioAggregator.aggregate(
            scope: .allWallets,
            network: .devnet,
            profiles: [signer, watch],
            solBalances: [signer.id: 1, watch.id: 2],
            tokenBalances: [:],
            prices: [:],
            errors: [watch.id: "RPC unavailable"]
        )
        let snapshot = PortfolioSnapshot(summary: summary)
        let json = try #require(String(data: JSONEncoder().encode(snapshot), encoding: .utf8)).lowercased()

        #expect(summary.status == .stale)
        #expect(summary.wallets.first { $0.id == watch.id }?.errorMessage == "RPC unavailable")
        #expect(snapshot.assets.contains { $0.walletKind == .watchOnly })
        #expect(json.contains("watch_only"))
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func stakeParserParsesAuthorityMatchedParsedStakeAccount() throws {
        let profile = WalletProfile(label: "Staker", publicAddress: Base58.encode(Data(repeating: 12, count: 32)))
        let voteAccount = Base58.encode(Data(repeating: 13, count: 32))
        let stakeAccount = Base58.encode(Data(repeating: 14, count: 32))
        let result: [[String: Any]] = [
            [
                "pubkey": stakeAccount,
                "account": [
                    "owner": StakeConstants.stakeProgramID,
                    "data": [
                        "parsed": [
                            "type": "delegated",
                            "info": [
                                "meta": [
                                    "authorized": [
                                        "staker": profile.publicAddress,
                                        "withdrawer": Base58.encode(Data(repeating: 15, count: 32))
                                    ],
                                    "rentExemptReserve": "2282880"
                                ],
                                "stake": [
                                    "delegation": [
                                        "voter": voteAccount,
                                        "stake": "2000000000",
                                        "activationEpoch": "10",
                                        "deactivationEpoch": "\(StakeConstants.deactivationEpochNever)"
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let parsed = try StakeAccountParser.parseStakeAccounts(
            result: result,
            profile: profile,
            network: .mainnetBeta,
            currentEpoch: 20,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        let account = try #require(parsed.first)

        #expect(account.stakeAccountAddress == stakeAccount)
        #expect(account.state == .active)
        #expect(account.delegatedLamports == 2_000_000_000)
        #expect(account.validator?.voteAccount == voteAccount)
        #expect(account.stakerAuthorityMatches)
        #expect(!account.withdrawerAuthorityMatches)
    }

    @Test func stakeStateMappingHandlesActivationAndDeactivation() {
        #expect(StakeAccountParser.stateForParsedType(
            "delegated",
            delegatedLamports: 1,
            activationEpoch: 12,
            deactivationEpoch: StakeConstants.deactivationEpochNever,
            currentEpoch: 10
        ) == .activating)
        #expect(StakeAccountParser.stateForParsedType(
            "delegated",
            delegatedLamports: 1,
            activationEpoch: 5,
            deactivationEpoch: 12,
            currentEpoch: 10
        ) == .deactivating)
        #expect(StakeAccountParser.stateForParsedType(
            "delegated",
            delegatedLamports: 1,
            activationEpoch: 5,
            deactivationEpoch: 8,
            currentEpoch: 10
        ) == .inactive)
        #expect(StakeAccountParser.stateForParsedType(
            "initialized",
            delegatedLamports: 0,
            activationEpoch: nil,
            deactivationEpoch: nil,
            currentEpoch: 10
        ) == .inactive)
    }

    @Test func nativeStakeValueAddsWithoutDoubleCountingLiquidSol() throws {
        let profile = WalletProfile(label: "Stake Wallet", publicAddress: SolanaConstants.systemProgramID)
        let stakeAccount = sampleStakeAccount(profile: profile, delegatedLamports: 2_000_000_000, state: .active)
        let prices = [
            PortfolioConstants.nativeSolMint: PortfolioPriceQuote(
                mintAddress: PortfolioConstants.nativeSolMint,
                usdPrice: 100,
                source: PortfolioConstants.priceSource,
                blockID: 1,
                priceChange24h: nil,
                fetchedAt: Date(),
                errorMessage: nil
            )
        ]

        let summary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .mainnetBeta,
            profiles: [profile],
            solBalances: [profile.id: 1_000_000_000],
            tokenBalances: [:],
            prices: prices,
            stakeAccounts: [profile.id: [stakeAccount]]
        )
        let snapshot = PortfolioSnapshot(summary: summary)

        #expect(summary.liquidSolLamports == 1_000_000_000)
        #expect(summary.liquidAssetsUSD == 100)
        #expect(summary.nativeStakeSummary.totalDelegatedLamports == 2_000_000_000)
        #expect(summary.nativeStakeSummary.estimatedUSD == 200)
        #expect(summary.totalUSD == 300)
        #expect(snapshot.nativeStakeLamports == 2_000_000_000)
        #expect(snapshot.stakeAccountCount == 1)
    }

    @Test func lstHoldingsAreDetectedFromSplBalancesWithoutDoubleCounting() throws {
        let profile = WalletProfile(label: "LST Wallet", publicAddress: SolanaConstants.systemProgramID)
        let jitoMint = "J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn"
        let jito = sampleTokenBalance(owner: profile.publicAddress, mint: jitoMint, amountRaw: 1_000_000_000, decimals: 9)
        let prices = [
            PortfolioConstants.nativeSolMint: PortfolioPriceQuote(
                mintAddress: PortfolioConstants.nativeSolMint,
                usdPrice: 100,
                source: PortfolioConstants.priceSource,
                blockID: 1,
                priceChange24h: nil,
                fetchedAt: Date(),
                errorMessage: nil
            ),
            jitoMint: PortfolioPriceQuote(
                mintAddress: jitoMint,
                usdPrice: 120,
                source: PortfolioConstants.priceSource,
                blockID: 1,
                priceChange24h: nil,
                fetchedAt: Date(),
                errorMessage: nil
            )
        ]

        let summary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .mainnetBeta,
            profiles: [profile],
            solBalances: [profile.id: 1_000_000_000],
            tokenBalances: [profile.id: [jito]],
            prices: prices
        )
        let jitoHolding = try #require(summary.lstSummary.holdings.first { $0.mintAddress == jitoMint })
        let jitoComparison = try #require(summary.lstSummary.comparison.first { $0.mintAddress == jitoMint })

        #expect(summary.liquidAssetsUSD == 220)
        #expect(summary.nativeStakeSummary.totalDelegatedLamports == 0)
        #expect(summary.totalUSD == 220)
        #expect(summary.lstSummary.totalUSD == 120)
        #expect(jitoHolding.symbol == "JitoSOL")
        #expect(jitoComparison.apy == nil)
        #expect(jitoComparison.tvlUSD == nil)
        #expect(jitoComparison.exchangeRate == nil)
        #expect(jitoComparison.availability == .priceOnly)
    }

    @Test func stakeAndLSTModelsSerializeWithoutSecretFields() throws {
        let profile = WalletProfile(label: "Safe", publicAddress: SolanaConstants.systemProgramID)
        let stakeAccount = sampleStakeAccount(profile: profile, delegatedLamports: 1_000_000_000, state: .delegated)
        let stakeSummary = StakePortfolioAggregator.aggregate(
            profiles: [profile],
            accounts: [profile.id: [stakeAccount]],
            errors: [:],
            solPrice: nil,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        let lstSummary = LSTComparisonProvider.buildSummary(
            consolidatedAssets: [],
            prices: [:],
            network: .mainnetBeta,
            refreshedAt: Date(timeIntervalSince1970: 0)
        )
        let json = try #require(String(data: JSONEncoder().encode([stakeSummary, stakeSummary]), encoding: .utf8)).lowercased()
        let lstJSON = try #require(String(data: JSONEncoder().encode(lstSummary), encoding: .utf8)).lowercased()

        #expect(stakeSummary.priceUnavailable)
        #expect(lstSummary.comparison.allSatisfy { $0.apy == nil && $0.tvlUSD == nil && $0.exchangeRate == nil })
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload"] {
            #expect(!json.contains(forbidden))
            #expect(!lstJSON.contains(forbidden))
        }
    }

    @Test func portfolioVisibleRoadmapDoesNotContainNFTCopy() {
        let visibleCopy = PortfolioDeFiPlaceholderContent.items
            .flatMap { [$0.0, $0.1] }
            .joined(separator: " ")
            .lowercased()

        #expect(!visibleCopy.contains("nft"))
        #expect(visibleCopy.contains("yield"))
        #expect(visibleCopy.contains("lending"))
    }

    @Test func lendingModelsSerializeWithoutSecretsAndActionsStayLocked() throws {
        let profile = WalletProfile(label: "Lender", publicAddress: SolanaConstants.systemProgramID)
        let position = sampleLendingPosition(
            profile: profile,
            protocolKind: .kamino,
            suppliedUSD: 100,
            borrowedUSD: 25,
            healthFactor: Decimal(string: "2.0", locale: Locale(identifier: "en_US_POSIX"))
        )
        let result = LendingAdapterResult(
            protocolKind: .kamino,
            status: .loaded,
            positions: [position],
            source: .publicAPI,
            updatedAt: Date(timeIntervalSince1970: 0),
            errorMessage: nil
        )
        let summary = LendingPortfolioAggregator.aggregate(adapterResults: [result], refreshedAt: Date(timeIntervalSince1970: 0))
        let json = try #require(String(data: JSONEncoder().encode(summary), encoding: .utf8)).lowercased()

        #expect(summary.positionCount == 1)
        #expect(summary.suppliedValueUSD == 100)
        #expect(summary.borrowedValueUSD == 25)
        #expect(summary.netValueUSD == 75)
        #expect(summary.noDoubleCountNotice.lowercased().contains("separately"))
        #expect(LendingLockedAction.allCases.allSatisfy { !$0.isEnabled })
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func lendingUnavailableAdaptersAreHonestAndRiskMappingIsDeterministic() async {
        let profile = WalletProfile(label: "Read Only", publicAddress: SolanaConstants.systemProgramID)
        let kamino = await KaminoReadOnlyAdapter().fetchPositions(profiles: [profile], network: .devnet, prices: [:])
        let margin = await MarginFiReadOnlyAdapter(
            programAccountExists: { _ in true },
            accountFetcher: { _, _ in [] }
        )
            .fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:])
        let summary = LendingPortfolioAggregator.aggregate(adapterResults: [kamino, margin], refreshedAt: Date(timeIntervalSince1970: 0))

        #expect(kamino.status == .unavailable)
        #expect(margin.status == .empty)
        #expect(kamino.positions.isEmpty)
        #expect(margin.positions.isEmpty)
        #expect(summary.status == .stale)
        #expect(summary.unavailableAdapterCount == 1)
        #expect(LendingHealthSummary.riskLevel(healthFactor: Decimal(string: "2.0"), ltv: nil) == .healthy)
        #expect(LendingHealthSummary.riskLevel(healthFactor: Decimal(string: "1.3"), ltv: nil) == .caution)
        #expect(LendingHealthSummary.riskLevel(healthFactor: Decimal(string: "1.1"), ltv: nil) == .highRisk)
        #expect(LendingHealthSummary.riskLevel(healthFactor: Decimal(string: "1.0"), ltv: nil) == .liquidationRisk)
        #expect(LendingHealthSummary.riskLevel(healthFactor: nil, ltv: nil) == .unavailable)
    }

    @Test func marginFiGuardBlocksDangerousPathsAndAllowsOnlyReadOnlyProgramCheck() throws {
        try MarginFiEndpointGuard.validateProgramID(MarginFiConstants.programID)
        try MarginFiEndpointGuard.validateRPCMethod("getAccountInfo")
        try MarginFiEndpointGuard.validateRPCMethod("getProgramAccounts")

        for method in ["sendTransaction", "simulateTransaction", "getMultipleAccounts"] {
            #expect(throws: MarginFiEndpointGuardError.self) {
                try MarginFiEndpointGuard.validateRPCMethod(method)
            }
        }

        for path in [
            "/v2/account-create",
            "/marginfi/deposit",
            "/marginfi/borrow",
            "/marginfi/repay",
            "/marginfi/withdraw",
            "/marginfi/liquidate",
            "/marginfi/leverage",
            "/marginfi/transaction"
        ] {
            #expect(throws: MarginFiEndpointGuardError.self) {
                try MarginFiEndpointGuard.validateHTTPReadOnlyPath(path)
            }
        }

        #expect(throws: MarginFiEndpointGuardError.self) {
            try MarginFiEndpointGuard.validateProgramID(SolanaConstants.systemProgramID)
        }
    }

    @Test func marginFiReadOnlyAdapterReportsProgramStatusWithoutPositions() async throws {
        let profile = WalletProfile(label: "MarginFi User", publicAddress: SolanaConstants.systemProgramID)
        let adapter = MarginFiReadOnlyAdapter(
            programAccountExists: { network in
                #expect(network == .mainnetBeta)
                return true
            },
            accountFetcher: { profile, network in
                #expect(profile.publicAddress == SolanaConstants.systemProgramID)
                #expect(network == .mainnetBeta)
                return []
            }
        )
        let result = await adapter.fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:])
        let summary = LendingPortfolioAggregator.aggregate(adapterResults: [result], refreshedAt: Date(timeIntervalSince1970: 0))
        let json = try #require(String(data: JSONEncoder().encode(result), encoding: .utf8)).lowercased()

        #expect(result.protocolKind == .marginFi)
        #expect(result.status == .empty)
        #expect(result.source == .solanaRPC)
        #expect(result.positions.isEmpty)
        #expect(result.errorMessage?.contains("no MarginFi accounts were found") == true)
        #expect(summary.unavailableAdapterCount == 0)
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload", "unsignedtransaction"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func marginFiParserValidatesOfficialLayoutAndPartialBalanceSlots() throws {
        let account = try makeSyntheticMarginFiAccount(
            authority: SolanaConstants.systemProgramID,
            suppliedBank: PortfolioConstants.nativeSolMint,
            borrowedBank: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
        )

        let parsed = try MarginFiAccountParser.parse(account: account, expectedAuthority: SolanaConstants.systemProgramID)

        #expect(parsed.accountAddress == account.publicKey)
        #expect(parsed.groupAddress == MarginFiConstants.mainGroupID)
        #expect(parsed.authorityAddress == SolanaConstants.systemProgramID)
        #expect(parsed.activeBalances.count == 2)
        #expect(parsed.suppliedPositionCount == 1)
        #expect(parsed.borrowedPositionCount == 1)
        #expect(parsed.unknownPositionCount == 0)
        #expect(parsed.activeBalances[0].bankAddress == PortfolioConstants.nativeSolMint)
        #expect(parsed.activeBalances[0].side == .supplied)
        #expect(parsed.activeBalances[1].side == .borrowed)

        var invalidData = account.data
        invalidData[0] = 0
        let invalid = SolanaProgramAccountData(
            publicKey: account.publicKey,
            owner: account.owner,
            data: invalidData,
            space: account.space
        )
        #expect(throws: MarginFiAccountParserError.self) {
            try MarginFiAccountParser.parse(account: invalid, expectedAuthority: SolanaConstants.systemProgramID)
        }
        #expect(throws: MarginFiAccountParserError.self) {
            try MarginFiAccountParser.parse(account: account, expectedAuthority: PortfolioConstants.nativeSolMint)
        }
    }

    @Test func marginFiAdapterReturnsPartialWithoutFakingValuesOrHealth() async throws {
        let profile = WalletProfile(label: "MarginFi User", publicAddress: SolanaConstants.systemProgramID)
        let account = try makeSyntheticMarginFiAccount(
            authority: profile.publicAddress,
            suppliedBank: PortfolioConstants.nativeSolMint,
            borrowedBank: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
        )
        let adapter = MarginFiReadOnlyAdapter(
            programAccountExists: { _ in true },
            accountFetcher: { fetchedProfile, network in
                #expect(fetchedProfile.id == profile.id)
                #expect(network == .mainnetBeta)
                return [account]
            }
        )

        let result = await adapter.fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:])
        let summary = LendingPortfolioAggregator.aggregate(adapterResults: [result], refreshedAt: Date(timeIntervalSince1970: 0))
        let position = try #require(result.positions.first)
        let json = try #require(String(data: JSONEncoder().encode(result), encoding: .utf8)).lowercased()

        #expect(result.status == .partial)
        #expect(result.source == .solanaRPC)
        #expect(position.status == .partial)
        #expect(position.suppliedAssets.isEmpty)
        #expect(position.borrowedAssets.isEmpty)
        #expect(position.unvaluedSuppliedPositionCount == 1)
        #expect(position.unvaluedBorrowedPositionCount == 1)
        #expect(position.suppliedValueUSD == nil)
        #expect(position.borrowedValueUSD == nil)
        #expect(position.netValueUSD == nil)
        #expect(position.health.riskLevel == .unavailable)
        #expect(position.metadataStatus?.contains("bank parser not connected") == true)
        #expect(summary.status == .partial)
        #expect(summary.partialAdapterCount == 1)
        #expect(summary.suppliedPositionCount == 1)
        #expect(summary.borrowedPositionCount == 1)
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload", "unsignedtransaction"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func marginFiAdapterCanUseSDKReadOnlyHelperBoundary() async throws {
        let profile = WalletProfile(label: "MarginFi SDK User", publicAddress: SolanaConstants.systemProgramID)
        let helperPosition = sampleLendingPosition(
            profile: profile,
            protocolKind: .marginFi,
            suppliedUSD: 50,
            borrowedUSD: 10,
            healthFactor: nil
        )
        let helperResult = LendingAdapterResult(
            protocolKind: .marginFi,
            status: .loaded,
            positions: [helperPosition],
            source: .sdkReadOnly,
            updatedAt: Date(timeIntervalSince1970: 0),
            errorMessage: nil
        )
        let adapter = MarginFiReadOnlyAdapter(
            programAccountExists: { _ in
                Issue.record("Swift fallback should not be called when helper returns loaded data.")
                return false
            },
            accountFetcher: { _, _ in
                Issue.record("Swift fallback fetcher should not be called when helper returns loaded data.")
                return []
            },
            helperBridge: MockMarginFiHelperBridge(result: helperResult)
        )

        let result = await adapter.fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:])
        let json = try #require(String(data: JSONEncoder().encode(result), encoding: .utf8)).lowercased()

        #expect(result.status == .loaded)
        #expect(result.source == .sdkReadOnly)
        #expect(result.positions.count == 1)
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload", "unsignedtransaction", "instructionpayload"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func marginFiHelperBridgeMapsSDKResponseAndRejectsPayloadFields() async throws {
        let profile = WalletProfile(label: "MarginFi SDK User", publicAddress: SolanaConstants.systemProgramID)
        let policy = MarginFiHelperInvocationPolicy.readOnlyEnabledForDevelopment(
            allowedNodeExecutablePaths: ["/usr/bin/node"]
        )
        let response = MarginFiHelperResponse(
            id: UUID().uuidString,
            requestID: nil,
            command: .positions,
            status: .partial,
            errorCategory: "none",
            message: "SDK read-only partial",
            programID: MarginFiConstants.programID,
            groupID: MarginFiConstants.mainGroupID,
            sdkValidation: MarginFiHelperSDKValidation(
                sdkInstalled: true,
                sdkImportOk: true,
                sdkVersion: "test",
                programID: MarginFiConstants.programID,
                expectedProgramID: MarginFiConstants.programID,
                programIDMatches: true,
                groupID: MarginFiConstants.mainGroupID,
                groupIDSource: "sdk-config",
                readOnlyWallet: true
            ),
            positions: [
                MarginFiHelperPosition(
                    walletPublicAddress: profile.publicAddress,
                    accountAddress: "3oS3RJ8UYrYw7TAQEVh6u6ifrHi35o3DnvqyqGti4Gwa",
                    groupAddress: MarginFiConstants.mainGroupID,
                    suppliedAssets: [],
                    borrowedAssets: [],
                    suppliedPositionCount: 1,
                    borrowedPositionCount: 1,
                    suppliedValueUSD: "25",
                    borrowedValueUSD: nil,
                    netValueUSD: nil,
                    healthFactor: nil,
                    ltv: nil,
                    riskLevel: .unavailable,
                    status: .partial,
                    metadataStatus: "Official SDK read-only helper."
                )
            ],
            accountCount: 1,
            suppliedPositionCount: 1,
            borrowedPositionCount: 1,
            timestamp: Date(timeIntervalSince1970: 0)
        )
        let bridge = MarginFiHelperBridge(
            policy: policy,
            projectRoot: URL(fileURLWithPath: "/tmp/gorkh"),
            pathResolver: MockMarginFiHelperPathResolver(),
            processRunner: MockMarginFiHelperProcessRunner(response: response)
        )

        let result = try #require(await bridge.fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:]))
        let position = try #require(result.positions.first)

        #expect(result.status == .partial)
        #expect(result.source == .sdkReadOnly)
        #expect(position.suppliedValueUSD == 25)
        #expect(position.borrowedValueUSD == nil)
        #expect(position.netValueUSD == nil)
        #expect(position.unvaluedBorrowedPositionCount == 1)

        let rejectedBridge = MarginFiHelperBridge(
            policy: policy,
            projectRoot: URL(fileURLWithPath: "/tmp/gorkh"),
            pathResolver: MockMarginFiHelperPathResolver(),
            processRunner: MockMarginFiHelperProcessRunner(rawStdout: #"{"id":"1","command":"positions","status":"loaded","errorCategory":"none","message":"bad","programId":"MFv2hWf31Z9kbCa1snEPYctwafyhdvnV7FZnsebVacA","serializedTransaction":"no","timestamp":"2026-01-01T00:00:00Z"}"#)
        )
        let rejected = try #require(await rejectedBridge.fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:]))
        #expect(rejected.status == .unavailable)
        #expect(rejected.positions.isEmpty)
        #expect(rejected.errorMessage?.contains("forbidden field") == true)
    }

    @Test func marginFiHelperPathResolverRejectsArbitraryPaths() throws {
        let resolver = MarginFiHelperPathResolver()
        let badPathPolicy = MarginFiHelperInvocationPolicy(
            enabled: true,
            allowlistedHelperRelativePath: "/bin/sh",
            allowedNodeExecutablePaths: ["/usr/bin/node"],
            allowedCommands: [.positions]
        )
        let badNodePolicy = MarginFiHelperInvocationPolicy(
            enabled: true,
            allowlistedHelperRelativePath: MarginFiHelperPathResolver.allowedRelativePath,
            allowedNodeExecutablePaths: ["/tmp/node"],
            allowedCommands: [.positions]
        )

        #expect(throws: MarginFiHelperError.self) {
            _ = try resolver.resolve(policy: badPathPolicy, projectRoot: URL(fileURLWithPath: "/tmp/gorkh"))
        }
        #expect(throws: MarginFiHelperError.self) {
            _ = try resolver.resolve(policy: badNodePolicy, projectRoot: URL(fileURLWithPath: "/tmp/gorkh"))
        }
    }

    @Test func marginFiSafeModelsSerializeWithoutSecretsOrPayloads() throws {
        let metadata = MarginFiAdapterMetadata(
            programID: MarginFiConstants.programID,
            groupID: MarginFiConstants.mainGroupID,
            network: .mainnetBeta,
            programAccountReachable: true,
            source: .solanaRPC,
            updatedAt: Date(timeIntervalSince1970: 0),
            unavailableReason: MarginFiConstants.positionParsingUnavailableReason
        )
        let account = MarginFiAccountSummary(
            accountAddress: "3oS3RJ8UYrYw7TAQEVh6u6ifrHi35o3DnvqyqGti4Gwa",
            walletPublicAddress: SolanaConstants.systemProgramID,
            groupAddress: MarginFiConstants.mainGroupID,
            suppliedAssets: [],
            borrowedAssets: [],
            health: MarginFiHealthSummary(
                ltv: nil,
                healthFactor: nil,
                riskLevel: .unavailable,
                unavailableReason: "Fixture has no parsed balances."
            ),
            updatedAt: Date(timeIntervalSince1970: 0),
            source: .solanaRPC
        )
        let json = try #require(String(data: JSONEncoder().encode([metadata]), encoding: .utf8)).lowercased()
        let accountJSON = try #require(String(data: JSONEncoder().encode(account), encoding: .utf8)).lowercased()

        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload", "unsignedtransaction"] {
            #expect(!json.contains(forbidden))
            #expect(!accountJSON.contains(forbidden))
        }
    }

    @Test func kaminoEndpointGuardAllowsOnlyReviewedReadOnlyPaths() throws {
        let market = "7u3HeHxYDLhnCoErrtycNokbQYbWGzLs6JSDqGAv5PfF"
        let user = "EZC9wzVCvihCsCHEMGADYdsRhcpdRYWzSCZAVegSCfqY"

        try KaminoEndpointGuard.validate(url: URL(string: "https://api.kamino.finance/v2/kamino-market")!, kind: .marketList)
        try KaminoEndpointGuard.validate(
            url: URL(string: "https://api.kamino.finance/kamino-market/\(market)/reserves/metrics?env=mainnet-beta")!,
            kind: .reserveMetrics
        )
        try KaminoEndpointGuard.validate(
            url: URL(string: "https://api.kamino.finance/kamino-market/\(market)/users/\(user)/obligations?env=mainnet-beta")!,
            kind: .userObligations
        )

        #expect(throws: KaminoEndpointGuardError.self) {
            try KaminoEndpointGuard.validate(url: URL(string: "https://api.kamino.finance/kamino-market/\(market)/deposit")!, kind: .reserveMetrics)
        }
        #expect(throws: KaminoEndpointGuardError.self) {
            try KaminoEndpointGuard.validate(url: URL(string: "https://api.kamino.finance/kamino-market/\(market)/users/\(user)/unsignedTransaction")!, kind: .userObligations)
        }
        #expect(throws: KaminoEndpointGuardError.self) {
            try KaminoEndpointGuard.validate(url: URL(string: "https://example.com/v2/kamino-market")!, kind: .marketList)
        }
    }

    @Test func kaminoMarketAndPositionFixturesNormalizeToReadOnlyModels() throws {
        let market = KaminoMarketConfig(
            name: "Main Market",
            isPrimary: true,
            description: "Primary market on mainnet",
            lendingMarket: "7u3HeHxYDLhnCoErrtycNokbQYbWGzLs6JSDqGAv5PfF",
            lookupTable: nil,
            isCurated: false
        )
        let reserveData = """
        [
          {
            "reserve":"EVbyPKrHG6WBfm4dLxLMJpUDY43cCAcHSpV3KYjKsktW",
            "liquidityToken":"JITOSOL",
            "liquidityTokenMint":"J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn",
            "maxLtv":"0.59",
            "borrowApy":"0.0135",
            "supplyApy":"0.000005",
            "totalSupply":"800554.85",
            "totalBorrow":"7510.64",
            "totalBorrowUsd":"895962.10",
            "totalSupplyUsd":"95500052.73"
          },
          {
            "reserve":"D6q6wuQSrifJKZYpR1M8R4YawnLDtDsMmWM1NbBmgJ59",
            "liquidityToken":"USDC",
            "liquidityTokenMint":"EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
            "maxLtv":"0.8",
            "borrowApy":"0.0502",
            "supplyApy":"0.0371",
            "totalSupply":"161080133.04",
            "totalBorrow":"153106158.59",
            "totalBorrowUsd":"153087407.68",
            "totalSupplyUsd":"161060405.55"
          }
        ]
        """.data(using: .utf8)!
        let reserves = try JSONDecoder().decode([KaminoReserveMetric].self, from: reserveData)
        let marketSummary = reserves[0].marketSummary(market: market, updatedAt: Date(timeIntervalSince1970: 0))
        #expect(marketSummary.symbol == "JITOSOL")
        #expect(marketSummary.supplyAPY == Decimal(string: "0.000005"))
        #expect(marketSummary.utilization != nil)

        let obligationData = """
        [
          {
            "obligationAddress":"5Rvm48nSVMsqmNJovS4kVAWUS6HX9jRiG3UsPq5VsyPV",
            "state":{
              "lendingMarket":"7u3HeHxYDLhnCoErrtycNokbQYbWGzLs6JSDqGAv5PfF",
              "deposits":[{"depositReserve":"EVbyPKrHG6WBfm4dLxLMJpUDY43cCAcHSpV3KYjKsktW","depositedAmount":"99899438","marketValueSf":"0"}],
              "borrows":[{"borrowReserve":"D6q6wuQSrifJKZYpR1M8R4YawnLDtDsMmWM1NbBmgJ59","borrowedAmountSf":"2500000","marketValue":"2.5"}]
            },
            "refreshedStats":{
              "userTotalDeposit":"7.05",
              "userTotalBorrow":"3.98",
              "netAccountValue":"3.07",
              "loanToValue":"0.56",
              "borrowUtilization":"0.76"
            }
          }
        ]
        """.data(using: .utf8)!
        let obligations = try KaminoAPIClient.decodeUserObligations(data: obligationData)
        let profile = WalletProfile(label: "Kamino User", publicAddress: "EZC9wzVCvihCsCHEMGADYdsRhcpdRYWzSCZAVegSCfqY")
        let reserveMap = Dictionary(uniqueKeysWithValues: reserves.map { ($0.reserve, $0) })
        let obligation = try #require(obligations.first)
        let position = KaminoReadOnlyAdapter.position(
            obligation: obligation,
            market: market,
            profile: profile,
            network: .mainnetBeta,
            reserveMetrics: reserveMap,
            prices: [:],
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(position.suppliedAssets.first?.symbol == "JITOSOL")
        #expect(position.borrowedAssets.first?.symbol == "USDC")
        #expect(position.suppliedValueUSD == Decimal(string: "7.05"))
        #expect(position.borrowedValueUSD == Decimal(string: "3.98"))
        #expect(position.netValueUSD == Decimal(string: "3.07"))
        #expect(position.health.riskLevel == .caution)

        let result = LendingAdapterResult(
            protocolKind: .kamino,
            status: .loaded,
            positions: [position],
            source: .publicAPI,
            updatedAt: Date(timeIntervalSince1970: 0),
            errorMessage: nil,
            marketReserves: reserves.map { $0.marketSummary(market: market, updatedAt: Date(timeIntervalSince1970: 0)) }
        )
        let summary = LendingPortfolioAggregator.aggregate(adapterResults: [result], refreshedAt: Date(timeIntervalSince1970: 0))
        let json = try #require(String(data: JSONEncoder().encode(summary), encoding: .utf8)).lowercased()
        #expect(summary.marketReserveCount == 2)
        #expect(!json.contains("unsignedtransaction"))
        #expect(!json.contains("transactionpayload"))
        #expect(!json.contains("serializedtransaction"))
    }

    @Test func lendingSummaryStaysSeparateFromPortfolioTotalsAndSnapshotsSafely() throws {
        let profile = WalletProfile(label: "Portfolio Lender", publicAddress: SolanaConstants.systemProgramID)
        let lendingPosition = sampleLendingPosition(
            profile: profile,
            protocolKind: .marginFi,
            suppliedUSD: 200,
            borrowedUSD: 50,
            healthFactor: Decimal(string: "1.1", locale: Locale(identifier: "en_US_POSIX"))
        )
        let lendingResult = LendingAdapterResult(
            protocolKind: .marginFi,
            status: .loaded,
            positions: [lendingPosition],
            source: .publicAPI,
            updatedAt: Date(timeIntervalSince1970: 0),
            errorMessage: nil
        )
        let prices = [
            PortfolioConstants.nativeSolMint: PortfolioPriceQuote(
                mintAddress: PortfolioConstants.nativeSolMint,
                usdPrice: 100,
                source: PortfolioConstants.priceSource,
                blockID: 1,
                priceChange24h: nil,
                fetchedAt: Date(),
                errorMessage: nil
            )
        ]
        let summary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .mainnetBeta,
            profiles: [profile],
            solBalances: [profile.id: 1_000_000_000],
            tokenBalances: [:],
            prices: prices,
            lendingAdapterResults: [lendingResult]
        )
        let snapshot = PortfolioSnapshot(summary: summary)
        let json = try #require(String(data: JSONEncoder().encode(snapshot), encoding: .utf8)).lowercased()

        #expect(summary.totalUSD == 100)
        #expect(summary.lendingSummary.netValueUSD == 150)
        #expect(summary.lendingSummary.riskyPositionCount == 1)
        #expect(snapshot.lendingPositionCount == 1)
        #expect(snapshot.lendingRiskyPositionCount == 1)
        #expect(snapshot.lendingNetValueUSD == 150)
        #expect(snapshot.lendingMarketReserveCount == 0)
        #expect(snapshot.lendingProtocolStatuses["marginfi"] == "loaded")
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func lpModelsSerializeWithoutSecretsAndActionsStayLocked() throws {
        let profile = WalletProfile(label: "LP", publicAddress: SolanaConstants.systemProgramID)
        let position = sampleLPPosition(
            profile: profile,
            protocolKind: .meteora,
            estimatedValueUSD: 125
        )
        let result = LPAdapterResult(
            protocolKind: .meteora,
            status: .loaded,
            positions: [position],
            source: .sdkReadOnly,
            updatedAt: Date(timeIntervalSince1970: 0),
            errorMessage: nil
        )
        let summary = LPPortfolioAggregator.aggregate(adapterResults: [result], refreshedAt: Date(timeIntervalSince1970: 0))
        let json = try #require(String(data: JSONEncoder().encode(summary), encoding: .utf8)).lowercased()

        #expect(summary.positionCount == 1)
        #expect(summary.estimatedValueUSD == 125)
        #expect(summary.noDoubleCountNotice.lowercased().contains("separately"))
        #expect(LPLockedAction.allCases.allSatisfy { !$0.isEnabled })
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload", "instructionpayload"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func lpAdaptersReportHonestUnavailablePlaceholdersAndMeteoraHelperResults() async throws {
        let profile = WalletProfile(label: "LP", publicAddress: SolanaConstants.systemProgramID)
        let helperPosition = sampleLPPosition(
            profile: profile,
            protocolKind: .meteora,
            estimatedValueUSD: nil,
            status: .partial
        )
        let helperResult = LPAdapterResult(
            protocolKind: .meteora,
            status: .partial,
            positions: [helperPosition],
            source: .sdkReadOnly,
            updatedAt: Date(timeIntervalSince1970: 0),
            errorMessage: "partial"
        )
        let meteora = await MeteoraReadOnlyAdapter(helperBridge: MockMeteoraHelperBridge(result: helperResult))
            .fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:])
        let orca = await OrcaReadOnlyAdapter().fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:])
        let raydium = await RaydiumReadOnlyAdapter(client: MockRaydiumAPIClient.empty())
            .fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:])
        let summary = LPPortfolioAggregator.aggregate(adapterResults: [meteora, orca, raydium], refreshedAt: Date(timeIntervalSince1970: 0))

        #expect(meteora.status == .partial)
        #expect(meteora.positions.count == 1)
        #expect(orca.status == .unavailable)
        #expect(raydium.status == .empty)
        #expect(summary.status == .partial)
        #expect(summary.positionCount == 1)
        #expect(summary.partialAdapterCount == 1)
        #expect(summary.unavailableAdapterCount == 1)
    }

    @Test func lpSummaryStaysSeparateFromPortfolioTotalsAndSnapshotsSafely() throws {
        let profile = WalletProfile(label: "Portfolio LP", publicAddress: SolanaConstants.systemProgramID)
        let lpPosition = sampleLPPosition(
            profile: profile,
            protocolKind: .meteora,
            estimatedValueUSD: 1_000
        )
        let lpResult = LPAdapterResult(
            protocolKind: .meteora,
            status: .loaded,
            positions: [lpPosition],
            source: .sdkReadOnly,
            updatedAt: Date(timeIntervalSince1970: 0),
            errorMessage: nil
        )
        let prices = [
            PortfolioConstants.nativeSolMint: PortfolioPriceQuote(
                mintAddress: PortfolioConstants.nativeSolMint,
                usdPrice: 100,
                source: PortfolioConstants.priceSource,
                blockID: 1,
                priceChange24h: nil,
                fetchedAt: Date(),
                errorMessage: nil
            )
        ]
        let summary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .mainnetBeta,
            profiles: [profile],
            solBalances: [profile.id: 1_000_000_000],
            tokenBalances: [:],
            prices: prices,
            lpAdapterResults: [lpResult]
        )
        let snapshot = PortfolioSnapshot(summary: summary)
        let json = try #require(String(data: JSONEncoder().encode(snapshot), encoding: .utf8)).lowercased()

        #expect(summary.totalUSD == 100)
        #expect(summary.lpSummary.estimatedValueUSD == 1_000)
        #expect(snapshot.lpPositionCount == 1)
        #expect(snapshot.lpEstimatedValueUSD == 1_000)
        #expect(snapshot.lpProtocolStatuses["meteora"] == "loaded")
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload", "instructionpayload"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func yieldSummaryRepresentsExistingSourcesWithoutAddingExecution() throws {
        let profile = WalletProfile(label: "Yield User", publicAddress: SolanaConstants.systemProgramID)
        let jito = sampleTokenBalance(
            owner: profile.publicAddress,
            mint: "J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn",
            amountRaw: 1_000_000_000,
            decimals: 9
        )
        let pusd = sampleTokenBalance(
            owner: profile.publicAddress,
            mint: PUSDConstants.mintAddress,
            amountRaw: 2_000_000,
            decimals: PUSDConstants.decimals
        )
        let prices = [
            PortfolioConstants.nativeSolMint: PortfolioPriceQuote(
                mintAddress: PortfolioConstants.nativeSolMint,
                usdPrice: 100,
                source: PortfolioConstants.priceSource,
                blockID: 1,
                priceChange24h: nil,
                fetchedAt: Date(timeIntervalSince1970: 0),
                errorMessage: nil
            ),
            "J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn": PortfolioPriceQuote(
                mintAddress: "J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn",
                usdPrice: 120,
                source: PortfolioConstants.priceSource,
                blockID: 1,
                priceChange24h: nil,
                fetchedAt: Date(timeIntervalSince1970: 0),
                errorMessage: nil
            )
        ]
        let lendingPosition = sampleLendingPosition(
            profile: profile,
            protocolKind: .kamino,
            suppliedUSD: 100,
            borrowedUSD: 0,
            healthFactor: Decimal(string: "2.0", locale: Locale(identifier: "en_US_POSIX"))
        )
        let reserve = LendingMarketReserveSummary(
            protocolKind: .kamino,
            marketName: "Main Market",
            marketAddress: "market",
            reserveAddress: "reserve",
            symbol: "USDC",
            mintAddress: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
            supplyAPY: Decimal(string: "0.0371", locale: Locale(identifier: "en_US_POSIX")),
            borrowAPY: Decimal(string: "0.0502", locale: Locale(identifier: "en_US_POSIX")),
            maxLTV: Decimal(string: "0.8", locale: Locale(identifier: "en_US_POSIX")),
            totalSupply: nil,
            totalBorrow: nil,
            totalSupplyUSD: 1_000,
            totalBorrowUSD: nil,
            utilization: Decimal(string: "0.4", locale: Locale(identifier: "en_US_POSIX")),
            source: .publicAPI,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let lendingResult = LendingAdapterResult(
            protocolKind: .kamino,
            status: .loaded,
            positions: [lendingPosition],
            source: .publicAPI,
            updatedAt: Date(timeIntervalSince1970: 0),
            errorMessage: nil,
            marketReserves: [reserve]
        )
        let lpResult = LPAdapterResult(
            protocolKind: .raydium,
            status: .loaded,
            positions: [sampleLPPosition(profile: profile, protocolKind: .raydium, estimatedValueUSD: 50)],
            source: .publicAPI,
            updatedAt: Date(timeIntervalSince1970: 0),
            errorMessage: nil
        )

        let summary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .mainnetBeta,
            profiles: [profile],
            solBalances: [profile.id: 1_000_000_000],
            tokenBalances: [profile.id: [jito, pusd]],
            prices: prices,
            lendingAdapterResults: [lendingResult],
            lpAdapterResults: [lpResult],
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        let yield = summary.yieldSummary
        let json = try #require(String(data: JSONEncoder().encode(yield), encoding: .utf8)).lowercased()

        #expect(summary.totalUSD == 222)
        #expect(summary.lendingSummary.netValueUSD == 100)
        #expect(summary.lpSummary.estimatedValueUSD == 50)
        #expect(yield.holdings.count == 4)
        #expect(yield.heldOpportunityCount >= 4)
        #expect(yield.apyAvailableCount == 1)
        #expect(yield.totalYieldExposureUSD == 272)
        #expect(yield.opportunities.contains { $0.protocolKind == .jito && $0.rate.value == nil && $0.status == .partial })
        #expect(yield.opportunities.contains { $0.protocolKind == .kamino && $0.rate.value == Decimal(string: "0.0371", locale: Locale(identifier: "en_US_POSIX")) })
        #expect(yield.opportunities.contains { $0.protocolKind == .raydium && $0.rate.value == nil && $0.status == .partial })
        #expect(yield.opportunities.contains { $0.protocolKind == .palmUSD && $0.status == .unavailable && $0.unavailableReason == YieldConstants.pusdYieldUnavailableReason })
        #expect(yield.noDoubleCountNotice.lowercased().contains("separately"))
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload", "instructionpayload", "unsignedtransaction"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func yieldSnapshotsAndRiskLabelsRemainSafeAndDeterministic() throws {
        let profile = WalletProfile(label: "Yield Snapshot", publicAddress: SolanaConstants.systemProgramID)
        let summary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .mainnetBeta,
            profiles: [profile],
            solBalances: [profile.id: 0],
            tokenBalances: [:],
            prices: [:],
            lpAdapterResults: [
                LPAdapterResult(
                    protocolKind: .orca,
                    status: .partial,
                    positions: [sampleLPPosition(profile: profile, protocolKind: .orca, estimatedValueUSD: nil, status: .partial)],
                    source: .sdkReadOnly,
                    updatedAt: Date(timeIntervalSince1970: 0),
                    errorMessage: "Rate unavailable."
                )
            ],
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        let snapshot = PortfolioSnapshot(summary: summary)
        let snapshotJSON = try #require(String(data: JSONEncoder().encode(snapshot), encoding: .utf8)).lowercased()
        let comparisonJSON = try #require(String(data: JSONEncoder().encode(summary.yieldSummary.snapshot), encoding: .utf8)).lowercased()

        #expect(summary.yieldSummary.status == .partial)
        #expect(summary.yieldSummary.apyAvailableCount == 0)
        #expect(summary.yieldSummary.unavailableCount > 0)
        #expect(snapshot.yieldHeldOpportunityCount == summary.yieldSummary.heldOpportunityCount)
        #expect(snapshot.yieldAPYAvailableCount == 0)
        #expect(YieldRiskClassifier.classifyStablecoinYield(isActive: false) == .unavailable)
        #expect(summary.yieldSummary.opportunities.contains { $0.sourceKind == .stablecoin && $0.unavailableReason == YieldConstants.pusdYieldUnavailableReason })
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload", "instructionpayload", "unsignedtransaction"] {
            #expect(!snapshotJSON.contains(forbidden))
            #expect(!comparisonJSON.contains(forbidden))
        }
    }

    @Test func pnlSnapshotPerformanceCalculatesDeltasAndInsufficientHistory() throws {
        let profile = WalletProfile(label: "PnL User", publicAddress: SolanaConstants.systemProgramID)
        let previousDate = Date(timeIntervalSince1970: 1_000)
        let currentDate = Date(timeIntervalSince1970: 2_000)
        let previousSummary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .mainnetBeta,
            profiles: [profile],
            solBalances: [profile.id: 1_000_000_000],
            tokenBalances: [:],
            prices: [
                PortfolioConstants.nativeSolMint: PortfolioPriceQuote(
                    mintAddress: PortfolioConstants.nativeSolMint,
                    usdPrice: 100,
                    source: PortfolioConstants.priceSource,
                    blockID: 1,
                    priceChange24h: nil,
                    fetchedAt: previousDate,
                    errorMessage: nil
                )
            ],
            fetchedAt: previousDate
        )
        let currentSummary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .mainnetBeta,
            profiles: [profile],
            solBalances: [profile.id: 1_000_000_000],
            tokenBalances: [:],
            prices: [
                PortfolioConstants.nativeSolMint: PortfolioPriceQuote(
                    mintAddress: PortfolioConstants.nativeSolMint,
                    usdPrice: 125,
                    source: PortfolioConstants.priceSource,
                    blockID: 2,
                    priceChange24h: nil,
                    fetchedAt: currentDate,
                    errorMessage: nil
                )
            ],
            fetchedAt: currentDate
        )
        let previousSnapshot = PortfolioSnapshot(summary: previousSummary, createdAt: previousDate)
        let currentSnapshot = PortfolioSnapshot(summary: currentSummary, createdAt: currentDate)

        let summary = PnLCalculator.calculate(
            currentSummary: currentSummary,
            snapshots: [currentSnapshot, previousSnapshot],
            generatedAt: currentDate.addingTimeInterval(60)
        )
        let primary = try #require(summary.primaryPerformance)

        #expect(summary.status == .partial)
        #expect(primary.status == .loaded)
        #expect(primary.baselineValueUSD == 100)
        #expect(primary.currentValueUSD == 125)
        #expect(primary.valueDeltaUSD == 25)
        #expect(primary.percentageDelta == 25)
        #expect(summary.assetPerformances.first?.valueDeltaUSD == 25)
        #expect(summary.walletPerformances.first?.valueDeltaUSD == 25)
        #expect(summary.realized.status == .unavailable)
        #expect(summary.unrealized.status == .partial)

        let insufficient = PnLCalculator.calculate(
            currentSummary: currentSummary,
            snapshots: [currentSnapshot],
            generatedAt: currentDate.addingTimeInterval(60)
        )
        #expect(insufficient.primaryPerformance?.status == .unavailable)
        #expect(insufficient.primaryPerformance?.reason?.lowercased().contains("insufficient") == true)
    }

    @Test func pnlManualCostBasisAndStoreRemainLocalAndSafe() throws {
        let profile = WalletProfile(label: "Cost Basis", publicAddress: SolanaConstants.systemProgramID)
        let currentDate = Date(timeIntervalSince1970: 4_000)
        let currentSummary = PortfolioAggregator.aggregate(
            scope: .activeWallet,
            network: .mainnetBeta,
            profiles: [profile],
            solBalances: [profile.id: 1_000_000_000],
            tokenBalances: [:],
            prices: [
                PortfolioConstants.nativeSolMint: PortfolioPriceQuote(
                    mintAddress: PortfolioConstants.nativeSolMint,
                    usdPrice: 125,
                    source: PortfolioConstants.priceSource,
                    blockID: 2,
                    priceChange24h: nil,
                    fetchedAt: currentDate,
                    errorMessage: nil
                )
            ],
            fetchedAt: currentDate
        )
        let entry = CostBasisEntry(
            walletPublicAddress: profile.publicAddress,
            tokenMint: PortfolioConstants.nativeSolMint,
            tokenSymbol: "SOL",
            quantity: 1,
            totalCostUSD: 100,
            acquisitionDate: Date(timeIntervalSince1970: 3_000),
            note: "Manual local estimate"
        )
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gorkh-cost-basis-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let store = CostBasisStore(fileURL: fileURL)
        try store.upsert(entry)
        let loaded = store.load()
        let summary = PnLCalculator.calculate(
            currentSummary: currentSummary,
            snapshots: [],
            costBasisEntries: loaded,
            generatedAt: currentDate
        )
        let json = try #require(String(data: JSONEncoder().encode([entry]), encoding: .utf8)).lowercased()
        let loadedEntry = try #require(loaded.first)

        #expect(loaded.count == 1)
        #expect(loadedEntry.id == entry.id)
        #expect(loadedEntry.walletPublicAddress == entry.walletPublicAddress)
        #expect(loadedEntry.tokenMint == entry.tokenMint)
        #expect(loadedEntry.tokenSymbol == entry.tokenSymbol)
        #expect(loadedEntry.quantity == entry.quantity)
        #expect(loadedEntry.totalCostUSD == entry.totalCostUSD)
        #expect(loadedEntry.method == .manual)
        #expect(summary.costBasisCoverage.status == .loaded)
        #expect(summary.unrealized.estimatedUSD == 25)
        #expect(summary.unrealized.status == .loaded)
        #expect(summary.realized.status == .unavailable)
        #expect(fileURL.path.contains("UserDefaults") == false)
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload", "unsignedtransaction"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func pnlSwapActivityHintsArePartialAndUICopyAvoidsAccountingClaims() throws {
        let event = AuditEvent(
            kind: .swapSent,
            createdAt: Date(timeIntervalSince1970: 5_000),
            walletID: UUID(),
            network: .mainnetBeta,
            publicAddress: SolanaConstants.systemProgramID,
            transactionSignature: "swapSignature",
            message: "Swap sent",
            details: [
                "inputMint": PortfolioConstants.nativeSolMint,
                "outputMint": PUSDConstants.mintAddress,
                "amountRaw": "1000000000",
                "expectedOutputRaw": "1000000"
            ]
        )
        let hints = PnLActivityMapper.swapHints(from: [event])
        let hintJSON = try #require(String(data: JSONEncoder().encode(hints), encoding: .utf8)).lowercased()
        let activeCopy = [
            PnLConstants.notTaxGradeCopy,
            PnLConstants.costBasisMissingReason,
            PnLConstants.realizedUnavailableReason,
            PnLConstants.unrealizedPartialReason
        ]
        .joined(separator: " ")
        .lowercased()

        #expect(hints.count == 1)
        #expect(hints.first?.status == .partial)
        #expect(hints.first?.source == .swapActivity)
        #expect(!activeCopy.contains("tax report"))
        #expect(!activeCopy.contains("tax filing"))
        #expect(!activeCopy.contains("certified"))
        #expect(!activeCopy.contains("guaranteed"))
        #expect(!activeCopy.contains("nft"))
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload", "unsignedtransaction"] {
            #expect(!hintJSON.contains(forbidden))
        }
    }

    @Test func meteoraHelperBridgeMapsReadOnlyResponseAndRejectsPayloadFields() async throws {
        let profile = WalletProfile(label: "Meteora User", publicAddress: SolanaConstants.systemProgramID)
        let policy = MeteoraHelperInvocationPolicy.readOnlyEnabledForDevelopment(
            allowedNodeExecutablePaths: ["/usr/bin/node"]
        )
        let response = MeteoraHelperResponse(
            id: UUID().uuidString,
            requestID: nil,
            command: .positions,
            status: .partial,
            errorCategory: "none",
            message: "SDK read-only partial",
            sdkValidation: MeteoraHelperSDKValidation(
                sdkInstalled: true,
                sdkImportOk: true,
                sdkVersion: "1.7.5",
                readOnlyMethodAvailable: true
            ),
            positions: [
                MeteoraHelperPosition(
                    walletPublicAddress: profile.publicAddress,
                    poolAddress: "3oS3RJ8UYrYw7TAQEVh6u6ifrHi35o3DnvqyqGti4Gwa",
                    positionAddress: "4N9T5NZ7nVgT5WV5mgWbHcCxgVhM7kUWvQmr6YQb7wNo",
                    tokenAMint: PortfolioConstants.nativeSolMint,
                    tokenBMint: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
                    tokenAAmountUI: "1.5",
                    tokenBAmountUI: nil,
                    tokenAFeesUI: nil,
                    tokenBFeesUI: nil,
                    lowerBinID: 10,
                    upperBinID: 20,
                    currentBinID: 15,
                    rangeState: .inRange,
                    estimatedValueUSD: nil,
                    status: .partial,
                    metadataStatus: "Official SDK read-only helper."
                )
            ],
            positionCount: 1,
            timestamp: Date(timeIntervalSince1970: 0)
        )
        let bridge = MeteoraHelperBridge(
            policy: policy,
            projectRoot: URL(fileURLWithPath: "/tmp/gorkh"),
            pathResolver: MockMeteoraHelperPathResolver(),
            processRunner: MockMeteoraHelperProcessRunner(response: response)
        )

        let result = try #require(await bridge.fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:]))
        let position = try #require(result.positions.first)

        #expect(result.status == .partial)
        #expect(result.source == .sdkReadOnly)
        #expect(position.tokenA?.symbol == "wSOL")
        #expect(position.tokenB?.symbol == "USDC")
        #expect(position.rangeSummary.state == .inRange)

        let rejectedBridge = MeteoraHelperBridge(
            policy: policy,
            projectRoot: URL(fileURLWithPath: "/tmp/gorkh"),
            pathResolver: MockMeteoraHelperPathResolver(),
            processRunner: MockMeteoraHelperProcessRunner(rawStdout: #"{"id":"1","command":"positions","status":"loaded","errorCategory":"none","message":"bad","serializedTransaction":"no","timestamp":"2026-01-01T00:00:00Z"}"#)
        )
        let rejected = try #require(await rejectedBridge.fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:]))
        #expect(rejected.status == .unavailable)
        #expect(rejected.positions.isEmpty)
        #expect(rejected.errorMessage?.contains("forbidden field") == true)
    }

    @Test func orcaHelperBridgeMapsReadOnlyResponseAndRejectsPayloadFields() async throws {
        let profile = WalletProfile(label: "Orca User", publicAddress: SolanaConstants.systemProgramID)
        let policy = OrcaHelperInvocationPolicy.readOnlyEnabledForDevelopment(
            allowedNodeExecutablePaths: ["/usr/bin/node"]
        )
        let response = OrcaHelperResponse(
            id: UUID().uuidString,
            requestID: nil,
            command: .positions,
            status: .partial,
            errorCategory: "none",
            message: "SDK read-only partial",
            sdkValidation: OrcaHelperSDKValidation(
                sdkInstalled: true,
                sdkImportOk: true,
                sdkVersion: "7.0.2",
                kitInstalled: true,
                kitImportOk: true,
                kitVersion: "5.5.1",
                readOnlyMethodAvailable: true
            ),
            positions: [
                OrcaHelperPosition(
                    walletPublicAddress: profile.publicAddress,
                    poolAddress: "3oS3RJ8UYrYw7TAQEVh6u6ifrHi35o3DnvqyqGti4Gwa",
                    positionAddress: "4N9T5NZ7nVgT5WV5mgWbHcCxgVhM7kUWvQmr6YQb7wNo",
                    tokenAMint: PortfolioConstants.nativeSolMint,
                    tokenBMint: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
                    tokenAAmountUI: "2.0",
                    tokenBAmountUI: nil,
                    tokenAFeesUI: nil,
                    tokenBFeesUI: nil,
                    tickLowerIndex: -100,
                    tickUpperIndex: 100,
                    tickCurrentIndex: 0,
                    rangeState: .inRange,
                    estimatedValueUSD: nil,
                    status: .partial,
                    metadataStatus: "Official SDK read-only helper."
                )
            ],
            positionCount: 1,
            timestamp: Date(timeIntervalSince1970: 0)
        )
        let bridge = OrcaHelperBridge(
            policy: policy,
            projectRoot: URL(fileURLWithPath: "/tmp/gorkh"),
            pathResolver: MockOrcaHelperPathResolver(),
            processRunner: MockOrcaHelperProcessRunner(response: response)
        )

        let result = try #require(await bridge.fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:]))
        let position = try #require(result.positions.first)

        #expect(result.protocolKind == .orca)
        #expect(result.status == .partial)
        #expect(result.source == .sdkReadOnly)
        #expect(position.tokenA?.symbol == "wSOL")
        #expect(position.tokenB?.symbol == "USDC")
        #expect(position.rangeSummary.state == .inRange)

        let rejectedBridge = OrcaHelperBridge(
            policy: policy,
            projectRoot: URL(fileURLWithPath: "/tmp/gorkh"),
            pathResolver: MockOrcaHelperPathResolver(),
            processRunner: MockOrcaHelperProcessRunner(rawStdout: #"{"id":"1","command":"positions","status":"loaded","errorCategory":"none","message":"bad","transactionPayload":"no","timestamp":"2026-01-01T00:00:00Z"}"#)
        )
        let rejected = try #require(await rejectedBridge.fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:]))
        #expect(rejected.status == .unavailable)
        #expect(rejected.positions.isEmpty)
        #expect(rejected.errorMessage?.contains("forbidden field") == true)
    }

    @Test func orcaAdapterAggregatesInjectedReadOnlyPositionsWithMeteora() async throws {
        let profile = WalletProfile(label: "LP", publicAddress: SolanaConstants.systemProgramID)
        let meteoraPosition = sampleLPPosition(profile: profile, protocolKind: .meteora, estimatedValueUSD: 125)
        let orcaPosition = sampleLPPosition(profile: profile, protocolKind: .orca, estimatedValueUSD: nil, status: .partial)
        let meteoraResult = LPAdapterResult(
            protocolKind: .meteora,
            status: .loaded,
            positions: [meteoraPosition],
            source: .sdkReadOnly,
            updatedAt: Date(timeIntervalSince1970: 0),
            errorMessage: nil
        )
        let orcaResult = LPAdapterResult(
            protocolKind: .orca,
            status: .partial,
            positions: [orcaPosition],
            source: .sdkReadOnly,
            updatedAt: Date(timeIntervalSince1970: 0),
            errorMessage: "Orca value unavailable"
        )

        let meteora = await MeteoraReadOnlyAdapter(helperBridge: MockMeteoraHelperBridge(result: meteoraResult))
            .fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:])
        let orca = await OrcaReadOnlyAdapter(helperBridge: MockOrcaHelperBridge(result: orcaResult))
            .fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:])
        let raydium = await RaydiumReadOnlyAdapter(client: MockRaydiumAPIClient.empty())
            .fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:])
        let summary = LPPortfolioAggregator.aggregate(adapterResults: [meteora, orca, raydium], refreshedAt: Date(timeIntervalSince1970: 0))

        #expect(orca.status == .partial)
        #expect(orca.positions.count == 1)
        #expect(summary.status == .partial)
        #expect(summary.positionCount == 2)
        #expect(summary.partialAdapterCount == 1)
        #expect(summary.unavailableAdapterCount == 0)
        #expect(summary.estimatedValueUSD == nil)
        #expect(summary.protocols.first { $0.protocolKind == .orca }?.status == .partial)
    }

    @Test func raydiumEndpointGuardAllowsOnlyReviewedReadOnlyPaths() throws {
        let owner = SolanaConstants.systemProgramID
        let mint = PortfolioConstants.nativeSolMint
        try RaydiumEndpointGuard.validate(
            url: try #require(URL(string: "https://owner-v1.raydium.io/position/stake/\(owner)")),
            kind: .ownerStake(owner: owner)
        )
        try RaydiumEndpointGuard.validate(
            url: try #require(URL(string: "https://owner-v1-devnet.raydium.io/position/clmm-lock/\(owner)")),
            kind: .ownerCLMMLock(owner: owner)
        )
        try RaydiumEndpointGuard.validate(
            url: try #require(URL(string: "https://api-v3.raydium.io/mint/price?mints=\(mint)")),
            kind: .mintPrice(mints: [mint])
        )
        #expect(throws: RaydiumEndpointGuardError.self) {
            try RaydiumEndpointGuard.validate(
                url: try #require(URL(string: "https://api-v3.raydium.io/transaction/swap")),
                kind: .mintList
            )
        }
        #expect(throws: RaydiumEndpointGuardError.self) {
            try RaydiumEndpointGuard.validate(
                url: try #require(URL(string: "https://transaction-v1.raydium.io/anything")),
                kind: .mintList
            )
        }
    }

    @Test func raydiumOwner404AndAPIEnvelopesNormalizeSafely() throws {
        let empty = try RaydiumAPIClient.decodeOwnerEndpointResult(
            statusCode: 404,
            data: Data(),
            owner: SolanaConstants.systemProgramID,
            kind: .standardLP,
            sourceEndpoint: "/position/stake/{owner}",
            emptyMessage: "No positions."
        )
        #expect(empty.status == .empty)
        #expect(empty.positions.isEmpty)

        let positions = try RaydiumAPIClient.decodeOwnerPositions(
            data: raydiumStakeFixture(),
            owner: SolanaConstants.systemProgramID,
            kind: .standardLP,
            sourceEndpoint: "/position/stake/{owner}"
        )
        let first = try #require(positions.first)
        #expect(first.kind == .standardLP)
        #expect(first.poolAddress == "3oS3RJ8UYrYw7TAQEVh6u6ifrHi35o3DnvqyqGti4Gwa")
        #expect(first.tokenAAmountUI == "1.25")

        let prices = try RaydiumAPIClient.decodeMintPrices(data: Data(#"{"success":true,"data":{"So11111111111111111111111111111111111111112":"150.25"}}"#.utf8))
        #expect(prices[PortfolioConstants.nativeSolMint] == Decimal(string: "150.25"))
    }

    @Test func raydiumAdapterNormalizesStakeAndLockedCLMMWithoutExecution() async throws {
        let profile = WalletProfile(label: "Raydium User", publicAddress: SolanaConstants.systemProgramID)
        let adapter = RaydiumReadOnlyAdapter(client: MockRaydiumAPIClient(
            stake: try RaydiumAPIClient.decodeOwnerEndpointResult(
                statusCode: 200,
                data: raydiumStakeFixture(),
                owner: profile.publicAddress,
                kind: .standardLP,
                sourceEndpoint: "/position/stake/{owner}",
                emptyMessage: ""
            ),
            locked: try RaydiumAPIClient.decodeOwnerEndpointResult(
                statusCode: 200,
                data: raydiumCLMMLockFixture(),
                owner: profile.publicAddress,
                kind: .lockedCLMM,
                sourceEndpoint: "/position/clmm-lock/{owner}",
                emptyMessage: ""
            ),
            pools: try RaydiumAPIClient.decodePoolInfos(data: raydiumPoolFixture()),
            mints: try RaydiumAPIClient.decodeMintInfos(data: raydiumMintFixture()),
            prices: try RaydiumAPIClient.decodeMintPrices(data: raydiumPriceFixture())
        ))

        let result = await adapter.fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:])
        let summary = LPPortfolioAggregator.aggregate(adapterResults: [result], refreshedAt: Date(timeIntervalSince1970: 0))
        let json = try #require(String(data: JSONEncoder().encode(summary), encoding: .utf8)).lowercased()

        #expect(result.protocolKind == .raydium)
        #expect(result.status == .loaded)
        #expect(result.positions.count == 2)
        #expect(result.positions.contains { $0.metadataStatus?.contains("Locked CLMM") == true })
        #expect(summary.positionCount == 2)
        #expect(summary.protocols.first { $0.protocolKind == .raydium }?.status == .loaded)
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload", "unsignedtransaction", "instructionpayload"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func walletProductionNavigationUsesOverviewAndActivity() {
        #expect(WalletSection.productionOrder.map(\.title) == [
            "Overview",
            "Portfolio",
            "Send",
            "Swap",
            "Private",
            "Security",
            "Activity"
        ])
        #expect(WalletSection.productionOrder.first == .overview)
        #expect(WalletSection.watchOnlyOrder == [.overview, .portfolio, .activity])
        #expect(!WalletSection.productionOrder.map(\.title).contains("Audit"))
    }

    @Test func walletActivityCategoriesAndTechnicalDetailsRemainAvailable() throws {
        #expect(WalletActivityCategory.category(for: .swapSent) == .swap)
        #expect(WalletActivityCategory.category(for: .pusdTreasuryViewed) == .pusd)
        #expect(WalletActivityCategory.category(for: .lendingRefreshed) == .lending)
        #expect(WalletActivityCategory.category(for: .lpPositionsRefreshed) == .liquidity)
        #expect(WalletActivityCategory.category(for: .yieldComparisonRefreshed) == .yield)
        #expect(WalletActivityCategory.category(for: .pnlRefreshed) == .pnl)
        #expect(WalletActivityStatus.status(for: .swapSimulationFailed) == .failed)

        let activitySource = try sourceText(relativePath: "GORKH/Modules/Wallet/AuditLogView.swift")
        #expect(activitySource.contains("GorkhPanel(\"Activity\")"))
        #expect(activitySource.contains("DisclosureGroup(\"Technical details\")"))
        #expect(!activitySource.contains("GorkhPanel(\"Audit Log\")"))
    }

    @Test func walletSecurityStripAndReceiveStatesAreSafe() {
        let profile = WalletProfile(
            label: "Primary",
            publicAddress: SolanaConstants.systemProgramID,
            selectedNetwork: .devnet,
            walletOrigin: .generatedRecovery
        )
        let content = WalletSecurityStatusStripContent.make(
            profile: profile,
            vaultState: .unlocked,
            policy: .default,
            backupStatus: WalletBackupStatus.evaluate(profile: profile),
            network: .mainnetBeta,
            rpcHealth: RPCHealthSnapshot.unchecked(network: .mainnetBeta),
            rpcSecurity: RPCProviderSecurityStatus(
                provider: .rpcFast,
                network: .mainnetBeta,
                tokenStatus: .present,
                tokenEnvironmentNames: ["GORKH_RPCFAST_MAINNET_TOKEN"],
                beamStatus: RPCFastConfiguration.beamStatus
            )
        )

        #expect(content.lockTitle == "Unlocked")
        #expect(content.lockIsHealthy)
        #expect(content.localAuthenticationIsHealthy)
        #expect(content.backupIsHealthy)
        #expect(content.mainnetProtectionTitle == "Mainnet phrase on")
        #expect(content.signingGuardTitle == "Signing guard active")
        #expect(content.agentSignerAccessTitle == "Agent signer off")
        #expect(content.rpcIsHealthy)
        #expect(WalletEmptyStateContent.noWallet.message.lowercased().contains("private") == false)
    }

    @Test func walletProductionUXSourceDoesNotAddExecutionOrForbiddenProductCopy() throws {
        let files = [
            "GORKH/Modules/Wallet/WalletOverviewView.swift",
            "GORKH/Modules/Wallet/WalletReceiveView.swift",
            "GORKH/Modules/Wallet/WalletSectionNavigation.swift",
            "GORKH/Modules/Wallet/WalletSecurityStatusStripView.swift",
            "GORKH/Modules/Wallet/WalletEmptyStateView.swift",
            "GORKH/Modules/Wallet/WalletView.swift"
        ]
        let source = try files.map(sourceText(relativePath:)).joined(separator: "\n").lowercased()

        for forbidden in [
            "sendtransaction",
            "signtransaction",
            "transactionpayload",
            "serializedtransaction",
            "hiddensigning",
            "agent execute",
            "nft"
        ] {
            #expect(!source.contains(forbidden))
        }
        #expect(source.contains("overview"))
        #expect(source.contains("receive"))
        #expect(source.contains("activity"))
    }

    @Test func walletProductionQAChecklistAndWindowSizingArePresent() throws {
        let appSource = try sourceText(relativePath: "GORKH/App/GORKHApp.swift")
        #expect(appSource.contains(".defaultSize(width: 1360, height: 860)"))
        #expect(appSource.contains(".windowResizability(.contentMinSize)"))

        let overviewSource = try sourceText(relativePath: "GORKH/Modules/Wallet/WalletOverviewView.swift")
        let portfolioSource = try sourceText(relativePath: "GORKH/Modules/Wallet/Portfolio/WalletPortfolioView.swift")
        let receiveSource = try sourceText(relativePath: "GORKH/Modules/Wallet/WalletReceiveView.swift")
        let activitySource = try sourceText(relativePath: "GORKH/Modules/Wallet/AuditLogView.swift")
        let walletSource = try sourceText(relativePath: "GORKH/Modules/Wallet/WalletView.swift")

        #expect(overviewSource.contains("wallet.overview"))
        #expect(portfolioSource.contains("wallet.portfolio"))
        #expect(receiveSource.contains("wallet.receive"))
        #expect(activitySource.contains("wallet.activity"))
        #expect(walletSource.contains("wallet.section.navigation"))

        let checklist = try sourceText(relativePath: "../../../docs/qa/wallet-visual-regression-checklist.md")
        #expect(checklist.contains("Wallet Visual Regression Checklist"))
        #expect(checklist.contains("Overview, Portfolio, Send, Swap, Private, Security, Activity"))
        #expect(checklist.contains("No secret environment values in shared schemes."))
        #expect(checklist.contains("No new execution path or protocol integration was added."))
        #expect(checklist.lowercased().contains("w3 seeded demo-state coverage"))
        #expect(checklist.contains("mock-display-only"))

        let readiness = try sourceText(relativePath: "../../../docs/qa/wallet-release-readiness.md")
        #expect(readiness.contains("Wallet Release Readiness"))
        #expect(readiness.contains("Cloak tiny mainnet deposit/withdraw/scan"))
        #expect(readiness.contains("Orca harvest with an owned LP position"))
        #expect(readiness.contains("RPC Fast token read-path smoke"))
    }

    @Test func walletReleaseQADemoStateIsInertAndSecretFree() throws {
        let demo = WalletDemoState.releaseQA
        let data = try JSONEncoder().encode(demo)
        let json = try #require(String(data: data, encoding: .utf8))
        let lowercased = json.lowercased()

        #expect(demo.enabledByDefault == false)
        #expect(demo.allowsExecution == false)
        #expect(demo.containsOnlyWatchOnlyWallets)
        #expect(demo.screenCoverage == [
            "Overview",
            "Portfolio",
            "Send",
            "Swap",
            "Private",
            "Security",
            "Activity",
            "Receive"
        ])
        #expect(lowercased.contains("mock-display-only"))
        for forbidden in [
            "privatekey",
            "secretkey",
            "seedphrase",
            "signingseed",
            "walletjson",
            "transactionpayload",
            "serializedtransaction",
            "hiddensigning",
            "agent execute",
            "nft"
        ] {
            #expect(!lowercased.contains(forbidden))
        }
    }

    @Test func agentSectionAndZerionFoundationGateTinySwapOnly() throws {
        #expect(GORKHModule.allCases.map(\.title) == ["Wallet", "Agent", "Transaction Studio", "Settings"])

        let sourceFiles = [
            "GORKH/App/AppState.swift",
            "GORKH/App/GORKHShellView.swift",
            "GORKH/Core/Agent/AgentModels.swift",
            "GORKH/Core/Agent/AgentChatModels.swift",
            "GORKH/Core/Agent/AgentIntentClassifier.swift",
            "GORKH/Core/Agent/AgentFullAppIntent.swift",
            "GORKH/Core/Agent/AgentExecutionLaneRouter.swift",
            "GORKH/Core/Agent/AgentPolicyEngine.swift",
            "GORKH/Core/Agent/AgentProposalFactory.swift",
            "GORKH/Core/Agent/AgentProposalModels.swift",
            "GORKH/Core/Agent/AgentMemoryStore.swift",
            "GORKH/Core/Agent/AgentToolModels.swift",
            "GORKH/Core/Agent/AgentToolRegistry.swift",
            "GORKH/Core/Agent/AgentToolExecutor.swift",
            "GORKH/Core/Agent/AgentContextHydrator.swift",
            "GORKH/Core/Agent/AgentApprovalQueue.swift",
            "GORKH/Core/Agent/AgentHandoffCoordinator.swift",
            "GORKH/Core/Agent/AgentAIStatusModels.swift",
            "GORKH/Core/Agent/AgentLLMProvider.swift",
            "GORKH/Core/Agent/HostedDeepSeekAgentProvider.swift",
            "GORKH/Core/Agent/AgentHostedAPIClient.swift",
            "GORKH/Core/Agent/AgentHostedAPIContracts.swift",
            "GORKH/Core/Agent/AgentHostedAPIValidator.swift",
            "GORKH/Core/Agent/AgentHostedResponseSanitizer.swift",
            "GORKH/Core/Agent/AgentHostedAISmokeModels.swift",
            "GORKH/Core/Agent/AgentHostedErrorNormalizer.swift",
            "GORKH/Core/Agent/AgentRedactedContextBuilder.swift",
            "GORKH/Core/Agent/AgentToolBoundary.swift",
            "GORKH/Core/Agent/AgentLLMResponseModels.swift",
            "GORKH/Modules/Agent/AgentView.swift",
            "GORKH/Modules/Agent/AgentChatView.swift",
            "GORKH/Modules/Agent/AgentGuardrailBannerView.swift",
            "GORKH/Modules/Agent/AgentApprovalQueueView.swift",
            "GORKH/Modules/Agent/AgentHandoffCardView.swift",
            "GORKH/Modules/Agent/AgentFullAppHelpView.swift",
            "GORKH/Modules/Agent/AgentAIStatusView.swift",
            "GORKH/Modules/Agent/AgentIntentCardView.swift",
            "GORKH/Modules/Agent/AgentProposalCardView.swift",
            "GORKH/Modules/Agent/AgentOverviewView.swift",
            "GORKH/Modules/Agent/ZerionExecutorView.swift",
            "GORKH/Modules/Agent/ZerionPolicyCenterView.swift",
            "GORKH/Modules/Agent/ZerionProposalView.swift",
            "GORKH/Modules/Agent/ZerionExecutionReviewView.swift"
        ]
        let source = try sourceFiles.map(sourceText(relativePath:)).joined(separator: "\n").lowercased()

        #expect(source.contains("agent"))
        #expect(source.contains("chat"))
        #expect(source.contains("zerion executor"))
        #expect(source.contains("policy center"))
        #expect(source.contains("proposals only") || source.contains("tiny swap only"))
        #expect(source.contains("separate zerion wallet"))
        #expect(source.contains("main wallet disabled"))
        #expect(source.contains("no bridge / send / signing"))
        #expect(!source.contains("developer workstation"))
        #expect(!source.contains("nft"))
    }

    @Test func agentHostedAIConfigurationAndFallbackNeedNoUserModelKey() async throws {
        let configuration = AgentHostedAPIConfiguration(environment: [
            AgentHostedAPIConfiguration.baseURLEnvironmentName: "https://agent.gorkh.example"
        ])
        #expect(configuration.endpointURL?.absoluteString == "https://agent.gorkh.example/v1/agent/chat")
        #expect(configuration.apiKeyStatus == .missing)
        var request = URLRequest(url: try #require(configuration.endpointURL))
        configuration.applyAuthentication(to: &request)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(AgentHostedAPIConfiguration(environment: [
            AgentHostedAPIConfiguration.baseURLEnvironmentName: "http://agent.gorkh.example"
        ]).endpointURL == nil)

        let fallbackProvider = HostedDeepSeekProvider(client: AgentHostedAPIClient(
            configuration: AgentHostedAPIConfiguration(environment: [:]),
            transport: MockAgentHTTPTransport(payload: #"{"assistantMessage":"not used"}"#)
        ))
        let result = await fallbackProvider.respond(to: try sampleAgentLLMRequest(message: "summarize my portfolio"), redactionStatus: .clean)
        #expect(result.status.mode == .localSafeMode)
        #expect(result.response.assistantMessage.lowercased().contains("local safe mode"))
    }

    @Test func agentHostedAPIContractEncodingAndOutboundValidation() throws {
        let llmRequest = try sampleAgentLLMRequest(message: "summarize my portfolio")
        let hostedRequest = AgentHostedChatRequest(
            llmRequest: llmRequest,
            messageID: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            clientVersion: AgentHostedAPIContract.version
        )
        try AgentHostedAPIValidator.validateOutbound(hostedRequest)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try #require(String(data: encoder.encode(hostedRequest), encoding: .utf8))
        #expect(json.contains("\"conversationId\""))
        #expect(json.contains("\"messageId\""))
        #expect(json.contains("\"allowedTools\""))
        #expect(json.contains(AgentHostedAPIContract.version))
        #expect(!json.contains("enabledLocalTools"))

        let forbidden = AgentHostedChatRequest(
            conversationID: hostedRequest.conversationID,
            messageID: hostedRequest.messageID,
            userMessage: "serializedTransaction: abc",
            redactedContext: hostedRequest.redactedContext,
            deterministicIntent: hostedRequest.deterministicIntent,
            policyState: hostedRequest.policyState,
            allowedTools: hostedRequest.allowedTools,
            safetyMode: hostedRequest.safetyMode
        )
        #expect(throws: AgentHostedAPIValidationError.self) {
            try AgentHostedAPIValidator.validateOutbound(forbidden)
        }
    }

    @Test func agentHostedResponseSanitizerBlocksUnsafeToolsAndApprovalClaims() throws {
        let responseJSON = """
        {
          "assistantMessage": "I can draft this, but local policy must review it.",
          "suggestedIntent": "tokenSwapRequest",
          "missingFields": [],
          "proposalSuggestion": {
            "actionType": "mainWalletSwapDraft",
            "title": "Unsafe approval claim",
            "explanation": "This claim must not approve anything.",
            "riskNotes": [],
            "missingFields": [],
            "status": "approved",
            "executionApproved": true
          },
          "toolSuggestions": [
            {"name": "draftSwapProposal"},
            {"name": "executeSwap"},
            "sendTransaction"
          ],
          "safetyWarnings": ["Fixture includes unsafe suggestions."],
          "modelInfo": {"provider":"gorkh-hosted","model":"deepseek-backed","contractVersion":"2026-05-10.a5"},
          "requestId": "mock-unsafe"
        }
        """
        let decoded = try JSONDecoder().decode(AgentHostedChatResponse.self, from: Data(responseJSON.utf8))
        let sanitized = try AgentHostedResponseSanitizer.sanitize(decoded)
        #expect(sanitized.toolBoundaryDecision.allowed == ["draftSwapProposal"])
        #expect(sanitized.toolBoundaryDecision.blocked == ["executeSwap", "sendTransaction"])
        #expect(sanitized.ignoredProposalSuggestion)
        #expect(sanitized.response.proposalDraft == nil)
        #expect(sanitized.response.safetyWarnings.contains { $0.lowercased().contains("execution approval was ignored") })
    }

    @Test func agentHostedClientFallsBackOnNetworkErrorAndParsesFixtureResponse() async throws {
        let responseJSON = """
        {
          "assistantMessage": "I can prepare a PUSD payment draft for review.",
          "suggestedIntent": "pusdPaymentRequest",
          "missingFields": ["recipient"],
          "proposalSuggestion": {
            "actionType": "pusdPaymentDraft",
            "title": "PUSD payment draft",
            "explanation": "Review in Wallet before sending.",
            "riskNotes": ["Destination approval required"],
            "missingFields": ["recipient"]
          },
          "toolSuggestions": [{"name": "draftPUSDPayment"}],
          "safetyWarnings": [],
          "modelInfo": {"provider":"gorkh-hosted","model":"deepseek-backed","contractVersion":"2026-05-10.a5"},
          "requestId": "mock-pusd"
        }
        """
        let provider = HostedDeepSeekProvider(client: AgentHostedAPIClient(
            configuration: AgentHostedAPIConfiguration(environment: [
                AgentHostedAPIConfiguration.baseURLEnvironmentName: "https://agent.gorkh.example"
            ]),
            transport: MockAgentHTTPTransport(payload: responseJSON)
        ))
        let result = await provider.respond(to: try sampleAgentLLMRequest(message: "prepare a PUSD payment"), redactionStatus: .clean)
        #expect(result.status.mode == .hostedDeepSeek)
        #expect(result.status.providerState == .available)
        #expect(result.status.backendContractVersion == AgentHostedAPIContract.version)
        #expect(result.response.requestID == "mock-pusd")
        #expect(result.response.proposalDraft?.title == "PUSD payment draft")
        #expect(result.toolBoundaryDecision.allowed == ["draftPUSDPayment"])

        let failingProvider = HostedDeepSeekProvider(client: AgentHostedAPIClient(
            configuration: AgentHostedAPIConfiguration(environment: [
                AgentHostedAPIConfiguration.baseURLEnvironmentName: "https://agent.gorkh.example"
            ]),
            transport: MockAgentHTTPTransport(payload: "", statusCode: 503)
        ))
        let fallback = await failingProvider.respond(to: try sampleAgentLLMRequest(message: "summarize my portfolio"), redactionStatus: .clean)
        #expect(fallback.status.mode == .localSafeMode)
        #expect(fallback.response.assistantMessage.lowercased().contains("local safe mode"))
    }

    @Test func agentHostedRemoteSmokeAndErrorNormalizationStayRedacted() throws {
        let configuration = AgentHostedAPIConfiguration(environment: [
            AgentHostedAPIConfiguration.baseURLEnvironmentName: "https://agent.gorkh.example/path?token=do-not-show",
            AgentHostedAPIConfiguration.apiKeyEnvironmentName: "local-only-placeholder"
        ])
        #expect(configuration.endpointHost == "agent.gorkh.example")
        #expect(configuration.endpointURL?.absoluteString.contains("token=do-not-show") == false)
        #expect(configuration.apiKeyStatus == .presentRedacted)

        let cases: [(AgentHostedAPIError, AgentHostedBackendErrorCategory)] = [
            (.missingEndpoint, .missingEndpoint),
            (.httpStatus(401, "redacted body"), .unauthorized),
            (.httpStatus(403, "redacted body"), .forbidden),
            (.httpStatus(429, "redacted body"), .rateLimited),
            (.httpStatus(500, "redacted body"), .serverError),
            (.transport("request timed out"), .timeout),
            (.transport("The data could not be decoded"), .malformedResponse),
            (.validation("forbiddenInboundField(sendTransaction)"), .unsafeResponseBlocked)
        ]
        for (error, category) in cases {
            #expect(AgentHostedErrorNormalizer.normalize(error).category == category)
        }

        let script = try sourceText(relativePath: "../../../scripts/agent-hosted-ai-smoke.sh")
        #expect(script.contains("--remote"))
        #expect(script.contains("--endpoint"))
        #expect(script.contains("--expect-auth-failure"))
        #expect(script.contains("--expect-timeout"))
        #expect(script.contains("present-redacted"))
        #expect(script.contains("Authorization: Bearer"))
        #expect(!script.contains("echo ${GORKH_AGENT_API_KEY}"))
        #expect(!script.contains("echo \"$GORKH_AGENT_API_KEY\""))
        #expect(script.contains("unsafe"))
        #expect(script.contains("approval"))
        #expect(script.contains("malformed_json"))
        #expect(script.contains("oversized"))
    }

    @Test func agentHostedAIRequestRedactionBlocksForbiddenFieldsAndMinimizesContext() throws {
        let demoPublicAddress = "11111111111111111111111111111111"
        #expect(throws: AgentRedactedContextError.self) {
            _ = try AgentRedactedContextBuilder.redactedUserMessageForAI("use private key: abc")
        }
        #expect(throws: AgentRedactedContextError.self) {
            _ = try AgentRedactedContextBuilder.redactedUserMessageForAI("runShell now")
        }

        let redacted = try AgentRedactedContextBuilder.redactedUserMessageForAI("summarize my portfolio")
        #expect(redacted.status == .clean)

        let context = try AgentRedactedContextBuilder.build(
            portfolioSummary: .empty(),
            pnlSummary: .empty(),
            pusdCirculationSnapshot: .idle(),
            auditEvents: [
                AuditEvent(
                    kind: .walletCreated,
                    walletID: nil,
                    network: .mainnetBeta,
                    publicAddress: demoPublicAddress,
                    message: "safe event",
                    details: ["public": "ok"]
                )
            ],
            selectedProfile: WalletProfile(label: "Demo", publicAddress: demoPublicAddress, walletOrigin: .watchOnly),
            selectedNetwork: .mainnetBeta,
            rpcSecurityStatus: RPCProviderSecurityStatus(
                provider: .rpcFast,
                network: .mainnetBeta,
                tokenStatus: .missing,
                tokenEnvironmentNames: [RPCFastConfiguration.mainnetTokenEnvironmentName],
                beamStatus: "locked"
            ),
            zerionStatus: .unchecked,
            builtAt: Date(timeIntervalSince1970: 0)
        )
        let payload = try #require(String(data: JSONEncoder().encode(context), encoding: .utf8)).lowercased()
        #expect(payload.contains("context_minimized"))
        #expect(payload.contains("gorkh_rpcfast_mainnet_token") == false)
        for forbidden in ["privatekey", "secretkey", "seedphrase", "signingseed", "walletjson", "transactionpayload", "serializedtransaction", "unsignedtransaction", "agenttoken", "nft"] {
            #expect(!payload.contains(forbidden))
        }
    }

    @Test func agentHostedAIToolBoundaryBlocksExecutionSuggestions() async throws {
        let decision = AgentToolBoundary.evaluate([
            "summarizePortfolio",
            "draftSwapProposal",
            "executeSwap",
            "sendTransaction",
            "runShell",
            "arbitraryCommand"
        ])
        #expect(decision.allowed == ["summarizePortfolio", "draftSwapProposal"])
        #expect(decision.blocked == ["executeSwap", "sendTransaction", "runShell", "arbitraryCommand"])

        let responseJSON = """
        {
          "assistantMessage": "I can explain this, but execution must use review.",
          "suggestedIntent": "tokenSwapRequest",
          "missingFields": [],
          "proposalSuggestion": {"title":"Swap draft","explanation":"Review in Wallet.","riskNotes":["Policy required"],"missingFields":[]},
          "toolSuggestions": ["draftSwapProposal", "executeSwap"],
          "safetyWarnings": ["No direct execution"],
          "modelInfo": {"provider":"gorkh-hosted","model":"deepseek-backed","contractVersion":"2026-05-10.a5"},
          "requestId": "mock-swap"
        }
        """
        let provider = HostedDeepSeekProvider(client: AgentHostedAPIClient(
            configuration: AgentHostedAPIConfiguration(environment: [
                AgentHostedAPIConfiguration.baseURLEnvironmentName: "https://agent.gorkh.example"
            ]),
            transport: MockAgentHTTPTransport(payload: responseJSON)
        ))
        let result = await provider.respond(to: try sampleAgentLLMRequest(message: "swap 1 USDC to SOL"), redactionStatus: .clean)
        #expect(result.status.mode == .hostedDeepSeek)
        #expect(result.status.providerState == .degraded)
        #expect(result.toolBoundaryDecision.allowed == ["draftSwapProposal"])
        #expect(result.toolBoundaryDecision.blocked == ["executeSwap"])

        let classification = AgentIntentClassifier().classify("swap 100 USDC to SOL")
        let policy = AgentPolicyEngine.evaluate(
            classification: classification,
            lane: AgentExecutionLaneRouter.route(classification),
            context: AgentPolicyContext(walletCanSign: false, walletIsWatchOnly: true, selectedNetwork: .mainnetBeta, zerionStatus: .unchecked)
        )
        #expect(policy.status == .blocked)
    }

    @Test func zerionCommandAllowlistBlocksTradingSigningAndUnsafeArguments() throws {
        #expect(try ZerionCLICommandBuilder.command(from: ["--help"]) == .help)
        #expect(try ZerionCLICommandBuilder.command(from: ["chains"]) == .chains)
        #expect(try ZerionCLICommandBuilder.command(from: ["wallet", "list"]) == .walletList)
        #expect(try ZerionCLICommandBuilder.command(from: ["agent", "list-policies"]) == .agentListPolicies)
        #expect(try ZerionCLICommandBuilder.command(from: ["agent", "list-tokens"]) == .agentListTokens)
        #expect(try ZerionCLICommandBuilder.command(from: ["swap", "--help"]) == .swapHelp)
        #expect(try ZerionCLICommandBuilder.command(from: ["agent", "--help"]) == .agentHelp)
        #expect(try ZerionCLICommandBuilder.command(from: ["portfolio", "0x0000000000000000000000000000000000000000"]) == .portfolio(address: "0x0000000000000000000000000000000000000000"))

        for blocked in [
            ["swap"],
            ["bridge"],
            ["send"],
            ["sign-message"],
            ["sign-typed-data"],
            ["wallet", "import"],
            ["wallet", "fund"],
            ["agent", "create-policy"],
            ["agent", "create-token"],
            ["agent", "revoke-token"]
        ] {
            #expect(throws: ZerionCLICommandValidationError.self) {
                try ZerionCLICommandBuilder.command(from: blocked)
            }
        }

        #expect(throws: ZerionCLICommandValidationError.self) {
            try ZerionCLICommandBuilder.command(from: ["chains;rm"])
        }
    }

    @Test func zerionPathResolverAcceptsOnlyValidatedExecutablePaths() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("gorkh-zerion-path-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("zerion")
        FileManager.default.createFile(atPath: executable.path, contents: Data("#!/usr/bin/env node\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let resolver = ZerionCLIPathResolver(environment: ["PATH": directory.path], knownPaths: [])
        let resolution = resolver.resolve()

        #expect(resolution.status == .installed)
        #expect(resolution.executablePath == executable.path)
        #expect(resolver.isValidExecutable("zerion") == false)
        #expect(resolver.isValidExecutable("/tmp/../zerion") == false)
        #expect(resolver.isValidExecutable(executable.deletingLastPathComponent().appendingPathComponent("not-zerion").path) == false)
    }

    @Test func zerionSecretsAndAuditAreRedacted() throws {
        let apiKey = "zk_" + "unit-test-placeholder"
        #expect(ZerionRedaction.apiKeyStatus(from: ["ZERION_API_KEY": apiKey]) == .presentRedacted)
        #expect(ZerionRedaction.apiKeyStatus(from: ["ZERION_API_KEY": "bad-placeholder"]) == .malformedRedacted)
        #expect(ZerionRedaction.apiKeyStatus(from: [:]) == .missing)

        let redacted = ZerionRedaction.redact("ZERION_API_KEY=\(apiKey) agent token: spend-power")
        #expect(!redacted.contains(apiKey))
        #expect(!redacted.contains("spend-power"))
        #expect(redacted.contains("[redacted"))

        let event = AgentAuditEvent(
            kind: .zerionAPIKeyStatusChecked,
            message: "checked \(apiKey)",
            details: [
                "agentToken": "spend-power",
                "network": "base"
            ]
        )
        let json = try #require(String(data: JSONEncoder().encode(event), encoding: .utf8)).lowercased()
        #expect(!json.contains(apiKey.lowercased()))
        #expect(!json.contains("spend-power"))
        #expect(!json.contains("agenttoken"))
        #expect(json.contains("base"))
    }

    @Test func zerionProposalsAreDraftOnlyAndModelsContainNoWalletSecrets() throws {
        let proposal = ZerionProposal.sampleDraft
        #expect(proposal.canExecuteInA1 == false)
        #expect(proposal.status == .draft)
        #expect(AgentSafetyPolicy.zerionA1.mainWalletAccess == .disabled)
        #expect(AgentSafetyPolicy.zerionA1.canUseNativeSigner == false)
        #expect(AgentSafetyPolicy.zerionA1.canReadCloakVault == false)
        #expect(AgentSafetyPolicy.zerionA1.canRunTradingCommands == false)
        #expect(AgentSafetyPolicy.zerionA2.mainWalletAccess == .disabled)
        #expect(AgentSafetyPolicy.zerionA2.canUseNativeSigner == false)
        #expect(AgentSafetyPolicy.zerionA2.canReadCloakVault == false)

        let payload = try JSONEncoder().encode([
            String(data: JSONEncoder().encode(proposal), encoding: .utf8) ?? "",
            String(data: JSONEncoder().encode(AgentSafetyPolicy.zerionA1), encoding: .utf8) ?? ""
        ])
        let json = try #require(String(data: payload, encoding: .utf8)).lowercased()

        for forbidden in [
            "privatekey",
            "secretkey",
            "seedphrase",
            "signingseed",
            "walletjson",
            "zerion_api_key",
            "agenttoken",
            "transactionpayload",
            "serializedtransaction",
            "nft"
        ] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func zerionHelpParserAndTinySwapCommandBuilderValidateFixedShape() throws {
        let chainFirst = ZerionCLIHelpParser.parse(
            topHelp: "--json --wallet",
            swapHelp: "zerion swap <chain> <amount> <from-token> <to-token>\nzerion swap base 1 USDC ETH",
            agentHelp: "agent list-tokens"
        )
        #expect(chainFirst.swapCommandShape == .chainFirst)
        #expect(chainFirst.supportsJSONFlag)
        #expect(chainFirst.supportsWalletFlag)

        let proposal = ZerionTinySwapProposal.sampleBaseTinySwap
        let plan = try ZerionSwapCommandBuilder.build(proposal: proposal, helpProbe: chainFirst)
        #expect(plan.arguments == ["swap", "base", "1", "USDC", "ETH", "--wallet", "manual-zerion-wallet", "--json"])
        #expect(plan.redactedPreview.contains("zerion swap base 1 USDC ETH"))
        #expect(!plan.redactedPreview.contains("ZERION_API_KEY"))

        let tokenFirst = ZerionCLIHelpParser.parse(
            topHelp: "--json --wallet --chain",
            swapHelp: "zerion swap <from> <to> <amount> --chain <chain>\nzerion swap usdc eth 100 --chain base",
            agentHelp: ""
        )
        let tokenFirstPlan = try ZerionSwapCommandBuilder.build(proposal: proposal, helpProbe: tokenFirst)
        #expect(tokenFirstPlan.arguments == ["swap", "USDC", "ETH", "1", "--chain", "base", "--wallet", "manual-zerion-wallet", "--json"])

        #expect(throws: ZerionSwapCommandBuilderError.self) {
            try ZerionSwapCommandBuilder.build(proposal: proposal, helpProbe: .unchecked)
        }
    }

    @Test func agentIntentClassifierCoversWalletDeFiAndPrivateRequests() {
        let classifier = AgentIntentClassifier()
        let mint = "CZzgUBvxaMLwMhVSLgqJn3npmxoTo6nzMNQPAnwtHF3s"

        let buy = classifier.classify("buy \(mint) for 5 SOL")
        #expect(buy.intentType == .tokenBuyRequest)
        #expect(buy.amount == Decimal(5))
        #expect(buy.sourceAsset == "SOL")
        #expect(buy.targetAsset == mint)
        #expect(buy.chain == "solana")

        let swap = classifier.classify("swap 100 USDC to SOL")
        #expect(swap.intentType == .tokenSwapRequest)
        #expect(swap.amount == Decimal(100))
        #expect(swap.sourceAsset == "USDC")
        #expect(swap.targetAsset == "SOL")

        let pusd = classifier.classify("send 10 PUSD to \(SolanaConstants.systemProgramID)")
        #expect(pusd.intentType == .pusdPaymentRequest)
        #expect(pusd.sourceAsset == "PUSD")
        #expect(pusd.recipient == SolanaConstants.systemProgramID)

        let privatePayment = classifier.classify("prepare a private Cloak payment")
        #expect(privatePayment.intentType == .cloakPrivatePaymentRequest)
        #expect(privatePayment.missingFields.contains("amount"))
        #expect(privatePayment.missingFields.contains("recipient"))

        let lp = classifier.classify("check my LP pools and find better positions")
        #expect(lp.intentType == .lpPositionReview)
        #expect(lp.riskFlags.contains(.readOnlyOnly))

        let yield = classifier.classify("find safer yield for USDC")
        #expect(yield.intentType == .yieldSearch)
        #expect(yield.sourceAsset == "USDC")

        let recent = classifier.classify("show what changed today")
        #expect(recent.intentType == .recentActivitySummary)
    }

    @Test func agentPolicyRoutesProposalsWithoutChatExecution() throws {
        let classifier = AgentIntentClassifier()
        let status = ZerionStatusSnapshot(
            cliStatus: .installed,
            executablePath: "/opt/homebrew/bin/zerion",
            nodeStatus: .installed,
            nodeVersion: "v22.22.2",
            apiKeyStatus: .presentRedacted,
            agentTokenStatus: .presentRedacted,
            policyStatus: .loaded,
            swapHelpStatus: .succeeded,
            swapCommandShape: .chainFirst,
            walletCount: 1,
            policyCount: 1,
            tokenCount: 1,
            supportedChains: ["base", "solana"],
            errors: [],
            checkedAt: Date(timeIntervalSince1970: 0)
        )

        let mainSwap = classifier.classify("swap 1 USDC to SOL")
        let mainLane = AgentExecutionLaneRouter.route(mainSwap, walletIsWatchOnly: false)
        #expect(mainLane == .mainWallet)
        let mainDecision = AgentPolicyEngine.evaluate(
            classification: mainSwap,
            lane: mainLane,
            context: AgentPolicyContext(walletCanSign: true, walletIsWatchOnly: false, selectedNetwork: .mainnetBeta, zerionStatus: status)
        )
        let proposal = AgentProposalFactory.makeProposal(classification: mainSwap, lane: mainLane, decision: mainDecision)
        #expect(proposal.status == .readyForReview)
        #expect(proposal.handoffTarget == .walletSwap)
        #expect(proposal.policyDecision.warnings.contains { $0.contains("destination Wallet module") })

        let watchOnlyLane = AgentExecutionLaneRouter.route(mainSwap, walletIsWatchOnly: true)
        let watchOnlyDecision = AgentPolicyEngine.evaluate(
            classification: mainSwap,
            lane: watchOnlyLane,
            context: AgentPolicyContext(walletCanSign: false, walletIsWatchOnly: true, selectedNetwork: .mainnetBeta, zerionStatus: status)
        )
        #expect(watchOnlyLane == .watchOnlyAnalysis)
        #expect(watchOnlyDecision.status == .blocked)

        let highZerion = classifier.classify("zerion swap 100 USDC to ETH on base")
        let zerionDecision = AgentPolicyEngine.evaluate(
            classification: highZerion,
            lane: AgentExecutionLaneRouter.route(highZerion),
            context: AgentPolicyContext(walletCanSign: true, walletIsWatchOnly: false, selectedNetwork: .mainnetBeta, zerionStatus: status)
        )
        #expect(zerionDecision.status == .blocked)
        #expect(zerionDecision.reasons.contains { $0.lowercased().contains("cap") })

        let safeZerion = classifier.classify("zerion swap 1 USDC to ETH on base")
        let safeDecision = AgentPolicyEngine.evaluate(
            classification: safeZerion,
            lane: AgentExecutionLaneRouter.route(safeZerion),
            context: AgentPolicyContext(walletCanSign: true, walletIsWatchOnly: false, selectedNetwork: .mainnetBeta, zerionStatus: status)
        )
        let safeProposal = AgentProposalFactory.makeProposal(classification: safeZerion, lane: .zerionAgentWallet, decision: safeDecision)
        #expect(safeProposal.status == .readyForReview)
        #expect(safeProposal.handoffTarget == .zerionReview)
        let tiny = try #require(AgentProposalFactory.makeZerionTinySwap(from: safeProposal))
        #expect(tiny.chain == .base)
        #expect(tiny.fromToken == "USDC")
        #expect(tiny.toToken == "ETH")
    }

    @Test func agentBlocksUnsupportedUnsafeAndMissingFieldRequests() {
        let classifier = AgentIntentClassifier()
        let missing = classifier.classify("buy this token for 5 SOL")
        #expect(missing.intentType == .tokenBuyRequest)
        #expect(missing.missingFields.contains("token or mint"))
        let missingProposal = AgentProposalFactory.makeProposal(
            classification: missing,
            lane: .mainWallet,
            decision: AgentPolicyDecision.needsMoreInput(missing.missingFields.map { "Missing \($0)." })
        )
        #expect(missingProposal.status == .missingFields)

        let bridge = classifier.classify("bridge 5 USDC")
        #expect(bridge.intentType == .unsupported)
        #expect(AgentExecutionLaneRouter.route(bridge) == .unsupported)

        let unsafe = classifier.classify("run /bin/sh with private key: abc")
        #expect(unsafe.intentType == .unsafe)
        #expect(unsafe.riskFlags.contains(.unsafeSecretRequest))
    }

    @Test func agentFullAppIntentTaxonomyCoversWalletPortfolioPrivateAndZerion() {
        let classifier = AgentIntentClassifier()

        #expect(classifier.classify("show wallet overview").intentType == .walletOverview)
        #expect(classifier.classify("show receive address").intentType == .receiveAddress)
        #expect(classifier.classify("prepare a swap of 0.1 SOL to USDC").intentType == .prepareSwap)
        #expect(classifier.classify("is my wallet safe for mainnet?").intentType == .securityStatus)
        #expect(classifier.classify("check RPC status").intentType == .rpcStatus)
        #expect(classifier.classify("show asset breakdown").intentType == .assetBreakdown)
        #expect(classifier.classify("show PUSD treasury balance").intentType == .pusdTreasurySummary)
        #expect(classifier.classify("show stake LST summary").intentType == .stakeLstSummary)
        #expect(classifier.classify("show lending summary").intentType == .lendingSummary)
        #expect(classifier.classify("show liquidity summary").intentType == .liquiditySummary)
        #expect(classifier.classify("why is my PnL partial?").intentType == .pnlSummary)
        #expect(classifier.classify("explain private state").intentType == .explainPrivateState)
        #expect(classifier.classify("show Cloak scan history").intentType == .cloakScanSummary)
        #expect(classifier.classify("show Zerion policy status").intentType == .zerionPolicySummary)

        let full = AgentFullAppIntentClassifier.classify("find better yield for USDC")
        #expect(full.classification.intentType == .yieldSearch)
        #expect(full.appArea == .portfolio)
        #expect(full.defaultToolID == .getYieldSummary)

        let zerion = AgentFullAppIntentClassifier.classify("use my Zerion agent wallet to prepare a tiny swap of 1 USDC to ETH on base")
        #expect(zerion.classification.intentType == .zerionPrepareTinySwap || zerion.classification.intentType == .zerionTinySwapRequest)
        #expect(zerion.appArea == .zerion)
        #expect(AgentExecutionLaneRouter.route(zerion.classification) == .zerionAgentWallet)
    }

    @Test func agentToolRegistryApprovalQueueHandoffAndContextStaySafe() throws {
        #expect(AgentToolRegistry.evaluate(toolID: .getWalletOverviewSummary).allowed == ["getWalletOverviewSummary"])
        #expect(AgentToolRegistry.evaluate(toolID: .executeSwap).blocked == ["executeSwap"])

        let boundary = AgentToolBoundary.evaluate(["getRPCStatus", "draftMainWalletSwap", "executeSend", "runShell"])
        #expect(boundary.allowed == ["getRPCStatus", "draftMainWalletSwap"])
        #expect(boundary.blocked == ["executeSend", "runShell"])

        let classification = AgentIntentClassifier().classify("prepare a swap of 0.1 SOL to USDC")
        let proposal = AgentProposalFactory.makeProposal(
            classification: classification,
            lane: .mainWallet,
            decision: .allowed(warnings: ["Destination review required."])
        )
        let queue = AgentApprovalQueue(proposals: [proposal])
        #expect(queue.readyCount == 1)
        #expect(queue.filtered(by: .wallet).first?.handoffTarget == .walletSwap)
        let handoff = AgentHandoffCoordinator.instruction(for: proposal)
        #expect(handoff.walletSection == .swap)
        #expect(handoff.instruction.lowercased().contains("approval"))

        var memory = AgentMemoryStore()
        memory.remember(intent: classification, proposal: proposal)
        #expect(memory.entries.count == 1)
        memory.clear()
        #expect(memory.entries.isEmpty)

        let context = AgentToolExecutionContext(
            portfolioSummary: .empty(),
            pnlSummary: .empty(),
            pusdCirculationSnapshot: .idle(),
            auditEvents: [],
            selectedProfile: WalletProfile(label: "Demo", publicAddress: "11111111111111111111111111111111", walletOrigin: .watchOnly),
            selectedNetwork: .mainnetBeta,
            walletBalance: nil,
            vaultState: .missing,
            rpcSecurityStatus: RPCProviderSecurityStatus(
                provider: .rpcFast,
                network: .mainnetBeta,
                tokenStatus: .missing,
                tokenEnvironmentNames: [RPCFastConfiguration.mainnetTokenEnvironmentName],
                beamStatus: "locked"
            ),
            cloakAdapterStatus: .lockedInPhase23,
            cloakVaultStatus: .statusOnly(walletID: nil),
            cloakScanSummary: .idle(),
            zerionStatus: .unchecked
        )
        let rpcResult = try #require(AgentToolExecutor.execute(classification: AgentIntentClassifier().classify("check RPC status"), context: context))
        #expect(rpcResult.title == "RPC status")
        #expect(rpcResult.summary.lowercased().contains("redacted"))

        let hydrated = try AgentContextHydrator.hydrate(
            portfolioSummary: .empty(),
            pnlSummary: .empty(),
            pusdCirculationSnapshot: .idle(),
            auditEvents: [],
            selectedProfile: context.selectedProfile,
            selectedNetwork: .mainnetBeta,
            rpcSecurityStatus: context.rpcSecurityStatus,
            zerionStatus: .unchecked,
            builtAt: Date(timeIntervalSince1970: 0)
        )
        let payload = try #require(String(data: JSONEncoder().encode(hydrated), encoding: .utf8)).lowercased()
        #expect(payload.contains("hosted_ai_advisory_only"))
        #expect(payload.contains("no_direct_chat_execution"))
        for forbidden in ["privatekey", "secretkey", "seedphrase", "signingseed", "walletjson", "transactionpayload", "serializedtransaction", "unsignedtransaction", "agenttoken"] {
            #expect(!payload.contains(forbidden))
        }

        let docs = try sourceText(relativePath: "../../../docs/architecture/agent-full-app-orchestrator.md")
        let smoke = try sourceText(relativePath: "../../../docs/qa/agent-full-app-orchestrator-smoke.md")
        #expect(docs.contains("approval-based orchestrator"))
        #expect(smoke.contains("Agent Full-App Orchestrator Smoke"))
    }

    @Test func agentInteractiveHandoffQADocQueueAndBlockedStatesStaySafe() throws {
        let qa = try sourceText(relativePath: "../../../docs/qa/agent-orchestrator-interactive-qa.md")
        for phrase in [
            "summarize my portfolio",
            "show what changed today",
            "is my wallet safe?",
            "check RPC status",
            "prepare a swap of 0.1 SOL to USDC",
            "prepare a PUSD payment request",
            "prepare a private Cloak payment",
            "find safer yield for USDC",
            "check my LP positions",
            "why is my PnL partial?",
            "use Zerion to prepare a tiny swap",
            "execute this swap now from chat",
            "buy this token",
            "send 10 SOL from watch-only wallet"
        ] {
            #expect(qa.contains(phrase))
        }
        #expect(qa.contains("Queue has no execution button."))
        #expect(qa.lowercased().contains("agent chat cannot sign"))

        let handoffExpectations: [(AgentIntentType, AgentHandoffTarget, WalletSection?)] = [
            (.walletOverview, .walletOverview, .overview),
            (.receiveAddress, .walletReceive, .overview),
            (.prepareSend, .walletSend, .send),
            (.prepareSwap, .walletSwap, .swap),
            (.prepareCloakPrivatePayment, .walletPrivate, .privateWallet),
            (.securityStatus, .walletSecurity, .security),
            (.activitySummary, .walletActivity, .activity),
            (.assetBreakdown, .portfolioAssets, .portfolio),
            (.walletBreakdown, .portfolioWallets, .portfolio),
            (.pusdTreasurySummary, .portfolioPUSD, .portfolio),
            (.stakeLstSummary, .portfolioStake, .portfolio),
            (.lendingSummary, .portfolioLending, .portfolio),
            (.liquiditySummary, .portfolioLiquidity, .portfolio),
            (.yieldSummary, .portfolioYield, .portfolio),
            (.pnlSummary, .portfolioPnL, .portfolio),
            (.portfolioHistorySummary, .portfolioHistory, .portfolio),
            (.zerionPrepareTinySwap, .zerionReview, nil)
        ]
        for (intent, target, walletSection) in handoffExpectations {
            #expect(AgentHandoffCoordinator.target(for: intent) == target)
            let instruction = AgentHandoffCoordinator.instruction(for: target)
            #expect(instruction.walletSection == walletSection)
            let safeInstruction = instruction.instruction.lowercased()
            #expect(safeInstruction.contains("approval") || safeInstruction.contains("review") || safeInstruction.contains("no funds move"))
        }

        let readyClassification = AgentIntentClassifier().classify("prepare a swap of 0.1 SOL to USDC")
        let readyProposal = AgentProposalFactory.makeProposal(
            classification: readyClassification,
            lane: .mainWallet,
            decision: .allowed(warnings: ["Destination review required."])
        )
        let blockedClassification = AgentIntentClassifier().classify("send 10 SOL to 11111111111111111111111111111111")
        let blockedDecision = AgentPolicyEngine.evaluate(
            classification: blockedClassification,
            lane: .mainWallet,
            context: AgentPolicyContext(
                walletCanSign: false,
                walletIsWatchOnly: true,
                selectedNetwork: .mainnetBeta,
                zerionStatus: .unchecked
            )
        )
        let blockedProposal = AgentProposalFactory.makeProposal(classification: blockedClassification, lane: .mainWallet, decision: blockedDecision)
        let queue = AgentApprovalQueue(proposals: [readyProposal, blockedProposal])
        #expect(queue.filtered(by: .wallet).count == 2)
        #expect(queue.filtered(by: .blocked).first?.canOpenHandoff == false)
        #expect(queue.filtered(by: .blocked).first?.statusDetail.lowercased().contains("cannot sign") == true)
        #expect(queue.filtered(by: .wallet).contains(where: { $0.canOpenHandoff && $0.handoffTarget == .walletSwap }))

        let ambiguous = AgentIntentClassifier().classify("buy this token")
        #expect(ambiguous.missingFields.isEmpty == false)
        let ambiguousDecision = AgentPolicyEngine.evaluate(
            classification: ambiguous,
            lane: .mainWallet,
            context: AgentPolicyContext(walletCanSign: true, walletIsWatchOnly: false, selectedNetwork: .mainnetBeta, zerionStatus: .unchecked)
        )
        #expect(ambiguousDecision.status == .needsMoreInput)

        let hostedUnavailable = AgentAIStatus.localSafeMode(reason: "Hosted AI endpoint is not configured.")
        #expect(hostedUnavailable.mode == .localSafeMode)
        #expect(hostedUnavailable.message.contains("Hosted AI endpoint is not configured."))

        let zerion = AgentIntentClassifier().classify("use Zerion to prepare a tiny swap of 1 USDC to ETH on base")
        let zerionDecision = AgentPolicyEngine.evaluate(
            classification: zerion,
            lane: AgentExecutionLaneRouter.route(zerion),
            context: AgentPolicyContext(walletCanSign: true, walletIsWatchOnly: false, selectedNetwork: .mainnetBeta, zerionStatus: .unchecked)
        )
        #expect(zerionDecision.status == .blocked)
        #expect(zerionDecision.reasons.contains(where: { $0.contains("Zerion CLI") }))

        #expect(AgentToolRegistry.evaluate(toolID: .executeSend).blocked == ["executeSend"])
        #expect(AgentToolRegistry.evaluate(toolID: .sendTransaction).blocked == ["sendTransaction"])
    }

    @Test func transactionStudioDetectsDecodesReviewsAndStaysReadOnly() throws {
        let signature = Base58.encode(Data(repeating: 2, count: 64))
        let signatureInput = try TransactionStudioInputDetector.detect(signature)
        #expect(signatureInput.kind == .signature)
        #expect(signatureInput.encoding == .base58)

        let addressInput = try TransactionStudioInputDetector.detect(SolanaConstants.systemProgramID)
        #expect(addressInput.kind == .address)

        let blockhash = Base58.encode(Data(repeating: 7, count: 32))
        let recipient = Base58.encode(Data(repeating: 9, count: 32))
        let draft = TransactionDraft(
            network: .devnet,
            fromAddress: SolanaConstants.systemProgramID,
            toAddress: recipient,
            amountLamports: 5_000
        )
        let message = try SolanaTransactionBuilder.makeTransferMessage(draft: draft, recentBlockhash: blockhash)
        let rawBase64 = SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message)
        let rawInput = try TransactionStudioInputDetector.detect(rawBase64)
        #expect(rawInput.kind == .rawTransaction)
        #expect(rawInput.encoding == .base64)

        let decoded = try TransactionDecoder.decode(input: rawInput, network: .mainnetBeta)
        #expect(decoded.transactionVersion == "legacy")
        #expect(decoded.instructions.count == 1)
        #expect(decoded.instructions.first?.programLabel == "System Program")
        #expect(decoded.instructions.first?.decodedAction.contains("System transfer") == true)
        #expect(decoded.instructions.first?.parseStatus == .recognized)
        #expect(decoded.signerSummaries.first?.address == SolanaConstants.systemProgramID)
        #expect(decoded.writableAccounts.contains { $0.address == recipient })

        #expect(TransactionInstructionLabeler.label(for: SolanaConstants.splTokenProgramID) == "SPL Token")
        #expect(TransactionInstructionLabeler.label(for: TransactionInstructionLabeler.orcaWhirlpoolProgramID) == "Orca Whirlpool")
        #expect(TransactionInstructionLabeler.label(for: "Bad111111111111111111111111111111111111111") == "Unknown Program")

        let unavailableSimulation = TransactionStudioSimulationSummary.unavailable("RPC unavailable")
        let risk = TransactionRiskAnalyzer.review(decoded: decoded, simulation: unavailableSimulation)
        #expect(risk.flags.contains { $0.kind == .nativeSOLTransfer })
        #expect(risk.flags.contains { $0.kind == .mainnetTransaction })
        #expect(risk.flags.contains { $0.kind == .missingSimulation })

        let explanation = TransactionExplanationBuilder.build(decoded: decoded, simulation: unavailableSimulation, risk: risk)
        #expect(explanation.summary.contains("System Program"))
        #expect(explanation.reviewChecklist.contains { $0.contains("does not sign") })

        let entry = TransactionStudioHistoryEntry(
            inputKind: .rawTransaction,
            publicReference: rawInput.safePreview,
            summary: explanation.summary,
            riskLevel: risk.level,
            simulationStatus: unavailableSimulation.status
        )
        let json = try #require(String(data: JSONEncoder().encode(entry), encoding: .utf8)).lowercased()
        for forbidden in ["privatekey", "secretkey", "seedphrase", "mnemonic", "walletjson", "signingseed", "transactionpayload", "serializedtransaction"] {
            #expect(!json.contains(forbidden))
        }

        let studioCoreFiles = try [
            "GORKH/Core/TransactionStudio/TransactionStudioModels.swift",
            "GORKH/Core/TransactionStudio/TransactionStudioInputDetector.swift",
            "GORKH/Core/TransactionStudio/TransactionDecoder.swift",
            "GORKH/Core/TransactionStudio/TransactionInstructionParser.swift",
            "GORKH/Core/TransactionStudio/TransactionAddressLookupModels.swift",
            "GORKH/Core/TransactionStudio/TransactionAccountEnrichmentModels.swift",
            "GORKH/Core/TransactionStudio/TransactionAccountEnrichmentService.swift",
            "GORKH/Core/TransactionStudio/TransactionAccountWatchListBuilder.swift",
            "GORKH/Core/TransactionStudio/TransactionSimulationDiffModels.swift",
            "GORKH/Core/TransactionStudio/TransactionSimulationDiffBuilder.swift",
            "GORKH/Core/TransactionStudio/TransactionProgramCatalog.swift",
            "GORKH/Core/TransactionStudio/SystemInstructionParser.swift",
            "GORKH/Core/TransactionStudio/SPLTokenInstructionParser.swift",
            "GORKH/Core/TransactionStudio/Token2022InstructionParser.swift",
            "GORKH/Core/TransactionStudio/ATAInstructionParser.swift",
            "GORKH/Core/TransactionStudio/ComputeBudgetInstructionParser.swift",
            "GORKH/Core/TransactionStudio/MemoInstructionParser.swift",
            "GORKH/Core/TransactionStudio/JupiterInstructionLabeler.swift",
            "GORKH/Core/TransactionStudio/TransactionStudioSmokeModels.swift",
            "GORKH/Core/TransactionStudio/TransactionInstructionLabeler.swift",
            "GORKH/Core/TransactionStudio/TransactionRiskAnalyzer.swift",
            "GORKH/Core/TransactionStudio/TransactionSimulationService.swift",
            "GORKH/Core/TransactionStudio/TransactionExplanationBuilder.swift",
            "GORKH/Core/TransactionStudio/TransactionStudioHistoryStore.swift",
            "GORKH/Core/TransactionStudio/TransactionStudioHandoffModels.swift",
            "GORKH/Modules/TransactionStudio/TransactionStudioView.swift",
            "GORKH/Modules/TransactionStudio/TransactionStudioInputView.swift",
            "GORKH/Modules/TransactionStudio/TransactionInstructionTimelineView.swift",
            "GORKH/Modules/TransactionStudio/TransactionRiskReviewView.swift",
            "GORKH/Modules/TransactionStudio/TransactionSimulationView.swift",
            "GORKH/Modules/TransactionStudio/TransactionExplanationView.swift",
            "GORKH/Modules/TransactionStudio/TransactionStudioHistoryView.swift"
        ].map { try sourceText(relativePath: $0) }.joined(separator: "\n").lowercased()
        for forbidden in ["sendtransaction(", "requestairdrop(", "signtransaction(", "getprogramaccounts", "jito", "beam", "buildbundle", "/bin/sh", "eval("] {
            #expect(!studioCoreFiles.contains(forbidden))
        }
        #expect(!studioCoreFiles.contains("nft"))

        let architecture = try sourceText(relativePath: "../../../docs/architecture/transaction-studio.md").lowercased()
        let smoke = try sourceText(relativePath: "../../../docs/qa/transaction-studio-smoke.md").lowercased()
        let liveSmoke = try sourceText(relativePath: "../../../docs/qa/transaction-studio-live-smoke.md").lowercased()
        #expect(architecture.contains("decode, simulation, explanation, risk review"))
        #expect(smoke.contains("transaction studio v0.1 is decode/simulate/review only"))
        #expect(liveSmoke.contains("gettransaction"))
        #expect(liveSmoke.contains("getparsedaccountinfo"))
        #expect(!architecture.contains("nft"))
        #expect(!smoke.contains("nft"))
        #expect(!liveSmoke.contains("nft"))
    }

    @Test func transactionStudioCommonParsersRiskExplanationAndHandoffStaySafe() throws {
        func u32(_ value: UInt32) -> Data {
            Data([
                UInt8(value & 0xff),
                UInt8((value >> 8) & 0xff),
                UInt8((value >> 16) & 0xff),
                UInt8((value >> 24) & 0xff)
            ])
        }
        func u64(_ value: UInt64) -> Data {
            Data((0..<8).map { UInt8((value >> UInt64($0 * 8)) & 0xff) })
        }
        func meta(_ index: Int) -> DecodedAccountMeta {
            DecodedAccountMeta(index: index, address: Base58.encode(Data(repeating: UInt8(index + 1), count: 32)), isSigner: index == 0, isWritable: index < 3)
        }
        let accounts = (0..<8).map(meta)

        let systemTransfer = SystemInstructionParser.parse(accounts: accounts, data: u32(2) + u64(1_500_000_000))
        #expect(systemTransfer.status == .recognized)
        #expect(systemTransfer.action.contains("1.5 SOL"))
        #expect(systemTransfer.details.contains { $0.label == "Lamports" && $0.value == "1500000000" })

        let splTransfer = SPLTokenInstructionParser.parse(accounts: accounts, data: Data([3]) + u64(42), tokenProgramLabel: "SPL Token")
        #expect(splTransfer.status == .recognized)
        #expect(splTransfer.riskHints.contains("Token transfer"))
        #expect(splTransfer.details.contains { $0.label == "Raw amount" && $0.value == "42" })

        let splChecked = SPLTokenInstructionParser.parse(accounts: accounts, data: Data([12]) + u64(1_234_500) + Data([6]), tokenProgramLabel: "SPL Token")
        #expect(splChecked.action.contains("1.2345"))
        #expect(splChecked.details.contains { $0.label == "Decimals" && $0.value == "6" })

        let approve = SPLTokenInstructionParser.parse(accounts: accounts, data: Data([4]) + u64(10), tokenProgramLabel: "SPL Token")
        #expect(approve.riskHints.contains("Token delegate approval"))
        let revoke = SPLTokenInstructionParser.parse(accounts: accounts, data: Data([5]), tokenProgramLabel: "SPL Token")
        #expect(revoke.action.contains("Revoke"))
        let close = SPLTokenInstructionParser.parse(accounts: accounts, data: Data([9]), tokenProgramLabel: "SPL Token")
        #expect(close.riskHints.contains("Token account close"))
        let setAuthority = SPLTokenInstructionParser.parse(accounts: accounts, data: Data([6, 2]), tokenProgramLabel: "SPL Token")
        #expect(setAuthority.riskHints.contains("Authority change"))

        let token2022 = Token2022InstructionParser.parse(accounts: accounts, data: Data([12]) + u64(100) + Data([2]))
        #expect(token2022.action.contains("Token-2022"))
        #expect(token2022.riskHints.contains("Token-2022 extensions may affect transfers"))

        let ata = ATAInstructionParser.parse(accounts: accounts, data: Data())
        #expect(ata.action.contains("Create associated token account"))
        #expect(ata.details.contains { $0.label == "Associated token account" })

        let computeLimit = ComputeBudgetInstructionParser.parse(data: Data([2]) + u32(1_400_000))
        #expect(computeLimit.riskHints.contains("High compute unit limit"))
        let computePrice = ComputeBudgetInstructionParser.parse(data: Data([3]) + u64(200_000))
        #expect(computePrice.riskHints.contains("High compute unit price"))

        let memo = MemoInstructionParser.parse(data: Data("hello".utf8))
        #expect(memo.status == .recognized)
        let longMemo = MemoInstructionParser.parse(data: Data(String(repeating: "a", count: 220).utf8))
        #expect(longMemo.status == .partial)
        #expect(longMemo.details.first?.value.contains("[truncated]") == true)

        let jupiter = JupiterInstructionLabeler.parse(programLabel: "Jupiter", accounts: accounts, data: Data([1, 2, 3]))
        #expect(jupiter.action == "Jupiter route instruction")
        #expect(jupiter.riskHints.contains("DeFi aggregator route"))

        func instruction(_ index: Int, programID: String, data: Data) -> DecodedInstruction {
            let label = TransactionInstructionLabeler.label(for: programID)
            let parsed = TransactionInstructionParser.parse(programID: programID, programLabel: label, accounts: accounts, data: data)
            return DecodedInstruction(
                index: index,
                programID: programID,
                programLabel: label,
                accounts: accounts,
                dataLength: data.count,
                decodedAction: parsed.action,
                riskHints: parsed.riskHints,
                parseStatus: parsed.status,
                parsedSummary: parsed
            )
        }

        let decoded = DecodedTransaction(
            inputKind: .rawTransaction,
            network: .mainnetBeta,
            transactionVersion: "legacy",
            signatureCount: 1,
            signatures: [Base58.encode(Data(repeating: 1, count: 64))],
            feePayer: accounts[0].address,
            recentBlockhash: Base58.encode(Data(repeating: 7, count: 32)),
            staticAccountCount: accounts.count,
            accountMetas: accounts,
            instructions: [
                instruction(0, programID: SolanaConstants.systemProgramID, data: u32(2) + u64(1_500_000_000)),
                instruction(1, programID: SolanaConstants.splTokenProgramID, data: Data([4]) + u64(10)),
                instruction(2, programID: TransactionInstructionLabeler.computeBudgetProgramID, data: Data([2]) + u32(1_400_000)),
                instruction(3, programID: TransactionInstructionLabeler.jupiterV6ProgramID, data: Data([1, 2, 3])),
                instruction(4, programID: "Bad111111111111111111111111111111111111111", data: Data([9]))
            ],
            programSummaries: [
                ProgramSummary(programID: SolanaConstants.systemProgramID, label: "System Program", instructionCount: 1),
                ProgramSummary(programID: SolanaConstants.splTokenProgramID, label: "SPL Token", instructionCount: 1),
                ProgramSummary(programID: TransactionInstructionLabeler.computeBudgetProgramID, label: "Compute Budget", instructionCount: 1),
                ProgramSummary(programID: TransactionInstructionLabeler.jupiterV6ProgramID, label: "Jupiter", instructionCount: 1),
                ProgramSummary(programID: "Bad111111111111111111111111111111111111111", label: "Unknown Program", instructionCount: 1)
            ],
            signerSummaries: [SignerSummary(address: accounts[0].address, isFeePayer: true)],
            writableAccounts: accounts.prefix(3).map { WritableAccountSummary(address: $0.address, isSigner: $0.isSigner) },
            addressLookupTables: [],
            addressLookupOverview: .empty,
            feeSummary: TransactionFeeSummary(requiredSignatureCount: 1, estimatedFeeLamports: nil),
            messageBase64: "safe-message-summary",
            simulationTransactionBase64: "raw-payload-not-used-in-handoff",
            fetchedSignature: nil,
            slot: nil,
            blockTime: nil,
            fingerprint: "unit-fingerprint",
            decodedAt: Date(timeIntervalSince1970: 0)
        )
        let risk = TransactionRiskAnalyzer.review(decoded: decoded, simulation: .unavailable("stale blockhash"))
        #expect(risk.flags.contains { $0.kind == .nativeSOLTransfer })
        #expect(risk.flags.contains { $0.kind == .approveDelegate })
        #expect(risk.flags.contains { $0.kind == .highComputeUsage })
        #expect(risk.flags.contains { $0.kind == .defiProtocolInteraction })
        #expect(risk.flags.contains { $0.kind == .unknownProgram })

        let explanation = TransactionExplanationBuilder.build(decoded: decoded, simulation: .unavailable("stale blockhash"), risk: risk)
        #expect(explanation.summary.contains("transfers 1.5 SOL"))
        #expect(explanation.summary.contains("unknown"))

        let handoff = TransactionStudioHandoff(
            target: .agentExplanation,
            summary: "Risk flags: \(risk.flags.map(\.message).joined(separator: " | ")). No raw transaction payload is included."
        )
        let handoffJSON = try #require(String(data: JSONEncoder().encode(handoff), encoding: .utf8)).lowercased()
        #expect(!handoffJSON.contains("raw-payload-not-used-in-handoff"))
        #expect(!handoffJSON.contains("serializedtransaction"))
        #expect(!handoffJSON.contains("transactionpayload"))

        let history = TransactionStudioHistoryEntry(
            inputKind: .rawTransaction,
            publicReference: "unit-fingerprint",
            summary: explanation.summary,
            riskLevel: risk.level,
            simulationStatus: .unavailable,
            recognizedInstructionCount: decoded.instructions.filter { $0.parseStatus == .recognized }.count,
            unknownInstructionCount: decoded.instructions.filter { $0.parseStatus == .unknown }.count
        )
        let historyJSON = try #require(String(data: JSONEncoder().encode(history), encoding: .utf8)).lowercased()
        #expect(historyJSON.contains("recognizedinstructioncount"))
        #expect(historyJSON.contains("unknowninstructioncount"))
        for forbidden in ["privatekey", "secretkey", "seedphrase", "mnemonic", "walletjson", "signingseed", "transactionpayload", "serializedtransaction"] {
            #expect(!historyJSON.contains(forbidden))
        }
    }

    @Test func transactionStudioALTAccountDiffAndProgramCatalogStayReadOnly() throws {
        func address(_ byte: UInt8) -> String {
            Base58.encode(Data(repeating: byte, count: 32))
        }

        let writableLoaded = (20..<34).map { address(UInt8($0)) }
        let readonlyLoaded = [address(40), address(41)]
        let alt = AddressLookupTableSummary(
            tableAddress: address(9),
            writableIndexCount: writableLoaded.count,
            readonlyIndexCount: readonlyLoaded.count,
            writableIndexes: Array(0..<writableLoaded.count),
            readonlyIndexes: [1, 2],
            loadedWritableAddresses: writableLoaded,
            loadedReadonlyAddresses: readonlyLoaded,
            resolutionStatus: .loaded
        )
        #expect(alt.resolutionStatus == .loaded)
        #expect(alt.loadedWritableAddresses.count == 14)

        let unresolved = AddressLookupTableSummary(
            tableAddress: address(10),
            writableIndexCount: 2,
            readonlyIndexCount: 1,
            writableIndexes: [0, 2],
            readonlyIndexes: [1],
            resolutionStatus: .unresolved,
            resolutionReason: "unit unresolved"
        )
        #expect(unresolved.resolutionStatus == .unresolved)

        let metas = (0..<4).map {
            DecodedAccountMeta(index: $0, address: address(UInt8($0 + 1)), isSigner: $0 == 0, isWritable: true)
        } + writableLoaded.enumerated().map {
            DecodedAccountMeta(index: 4 + $0.offset, address: $0.element, isSigner: false, isWritable: true)
        }
        let decoded = DecodedTransaction(
            inputKind: .signature,
            network: .mainnetBeta,
            transactionVersion: "v0",
            signatureCount: 1,
            signatures: [Base58.encode(Data(repeating: 1, count: 64))],
            feePayer: metas[0].address,
            recentBlockhash: address(7),
            staticAccountCount: 4,
            accountMetas: metas,
            instructions: [],
            programSummaries: [
                ProgramSummary(programID: SolanaConstants.systemProgramID, label: "System Program", instructionCount: 1),
                ProgramSummary(programID: TransactionInstructionLabeler.jupiterV6ProgramID, label: "Jupiter", instructionCount: 1)
            ],
            signerSummaries: [SignerSummary(address: metas[0].address, isFeePayer: true)],
            writableAccounts: metas.map { WritableAccountSummary(address: $0.address, isSigner: $0.isSigner) },
            addressLookupTables: [alt, unresolved],
            addressLookupOverview: TransactionAddressLookupOverview(
                tableCount: 2,
                loadedWritableCount: writableLoaded.count,
                loadedReadonlyCount: readonlyLoaded.count,
                unresolvedTableCount: 1
            ),
            feeSummary: TransactionFeeSummary(requiredSignatureCount: 1, estimatedFeeLamports: nil),
            messageBase64: "safe-message-summary",
            simulationTransactionBase64: "raw-payload-not-in-history",
            fetchedSignature: Base58.encode(Data(repeating: 2, count: 64)),
            slot: 10,
            blockTime: nil,
            fingerprint: "alt-unit",
            decodedAt: Date(timeIntervalSince1970: 0)
        )

        let watchList = TransactionAccountWatchListBuilder.build(decoded: decoded, maxCount: 5)
        #expect(watchList.accounts.count == 5)
        #expect(watchList.truncated)

        let before = TransactionAccountEnrichment(
            address: watchList.accounts[0].address,
            ownerProgram: SolanaConstants.systemProgramID,
            ownerLabel: "System Program",
            lamports: 10,
            executable: false,
            dataLength: 0,
            tokenMint: nil,
            tokenOwner: nil,
            tokenAmountRaw: nil,
            tokenDecimals: nil,
            tokenUIAmount: nil,
            source: "unit-before"
        )
        let after = TransactionAccountEnrichment(
            address: watchList.accounts[0].address,
            ownerProgram: SolanaConstants.systemProgramID,
            ownerLabel: "System Program",
            lamports: 15,
            executable: false,
            dataLength: 0,
            tokenMint: nil,
            tokenOwner: nil,
            tokenAmountRaw: nil,
            tokenDecimals: nil,
            tokenUIAmount: nil,
            source: "unit-after"
        )
        let diff = TransactionSimulationDiffBuilder.build(watchList: watchList, before: [before], after: [after])
        #expect(diff.status == .available)
        #expect(diff.rows.first?.lamportsDelta == 5)

        let simulation = TransactionStudioSimulationSummary(
            status: .success,
            logs: [],
            unitsConsumed: 1_300_000,
            errorMessage: nil,
            replacementBlockhashUsed: false,
            watchList: watchList,
            accountDiff: diff,
            simulatedAt: Date(timeIntervalSince1970: 1)
        )
        let risk = TransactionRiskAnalyzer.review(decoded: decoded, simulation: simulation)
        #expect(risk.flags.contains { $0.kind == .addressLookupTableUse })
        #expect(risk.flags.contains { $0.kind == .addressLookupTableUnavailable })
        #expect(risk.flags.contains { $0.kind == .manyLoadedWritableAccounts })

        let explanation = TransactionExplanationBuilder.build(decoded: decoded, simulation: simulation, risk: risk)
        #expect(explanation.summary.contains("address lookup table"))
        #expect(explanation.summary.contains("Account diff is available"))
        #expect(TransactionProgramCatalog.entry(for: TransactionInstructionLabeler.jupiterV6ProgramID).category == .aggregator)

        let history = TransactionStudioHistoryEntry(
            inputKind: .signature,
            publicReference: decoded.fetchedSignature ?? "unit",
            summary: explanation.summary,
            riskLevel: risk.level,
            simulationStatus: simulation.status,
            transactionVersion: decoded.transactionVersion,
            altUsed: true,
            accountDiffAvailable: true,
            loadedAccountCount: decoded.addressLookupOverview.loadedWritableCount + decoded.addressLookupOverview.loadedReadonlyCount,
            topProgramCategories: decoded.programSummaries.map(\.category.title)
        )
        let historyJSON = try #require(String(data: JSONEncoder().encode(history), encoding: .utf8)).lowercased()
        #expect(historyJSON.contains("transactionversion"))
        #expect(historyJSON.contains("altused"))
        #expect(historyJSON.contains("accountdiffavailable"))
        #expect(!historyJSON.contains("raw-payload-not-in-history"))

        let handoffSummary = "Version: \(decoded.transactionVersion). ALT tables: \(decoded.addressLookupOverview.tableCount). Account diff: \(simulation.accountDiff.status.title). No raw transaction payload is included."
        #expect(!handoffSummary.lowercased().contains("raw-payload-not-in-history"))

        let script = try sourceText(relativePath: "../../../scripts/transaction-studio-smoke.sh")
        #expect(script.contains("--signature"))
        #expect(script.contains("--address"))
        #expect(script.contains("GORKH_TX_STUDIO_SMOKE_RPC_URL"))
        #expect(!script.contains(#""method":"sendTransaction""#))
        #expect(!script.contains(#""method":"requestAirdrop""#))

        let fixtures = try sourceText(relativePath: "../../../docs/qa/transaction-studio-public-fixtures.md").lowercased()
        #expect(fixtures.contains("gorkh_tx_studio_alt_signature"))
        #expect(!fixtures.contains("nft"))
    }

    @Test func shieldReviewSummarizesApprovalsWithoutSigningOrPersistingPayloads() throws {
        let recipient = Base58.encode(Data(repeating: 8, count: 32))
        let sender = Base58.encode(Data(repeating: 9, count: 32))
        let solDraft = TransactionDraft(
            network: .mainnetBeta,
            fromAddress: sender,
            toAddress: recipient,
            amountLamports: 1_000_000
        )
        let failedSimulation = SimulationResult(
            status: .failed,
            logs: ["Program failed"],
            estimatedFeeLamports: 5_000,
            errorMessage: "unit simulation failed",
            simulatedAt: Date(timeIntervalSince1970: 1)
        )
        let solReview = ShieldReviewService.reviewSOLTransfer(draft: solDraft, simulation: failedSimulation)
        #expect(solReview.title.contains("SOL"))
        #expect(solReview.programLabels.contains("System Program"))
        #expect(solReview.parsedActions.contains { $0.label.contains("System transfer") })
        #expect(solReview.riskFlags.contains { $0.kind == TransactionRiskFlagKind.nativeSOLTransfer.rawValue })
        #expect(solReview.riskFlags.contains { $0.kind == TransactionRiskFlagKind.simulationFailed.rawValue })
        #expect(!ShieldReviewPolicy.canContinueAfterReview(summary: solReview, simulationRequired: true))

        let ataPlan = AssociatedTokenAccountPlan(
            recipientOwnerAddress: recipient,
            mintAddress: Base58.encode(Data(repeating: 10, count: 32)),
            tokenProgramKind: .token2022,
            associatedTokenAddress: Base58.encode(Data(repeating: 11, count: 32)),
            recipientTokenAccountExists: false,
            shouldCreateAssociatedTokenAccount: true,
            creationSupported: true,
            rentExemptLamports: 2_039_280,
            message: "Create recipient ATA."
        )
        let tokenDraft = TokenTransferDraft(
            network: .mainnetBeta,
            ownerAddress: sender,
            sourceTokenAccount: Base58.encode(Data(repeating: 12, count: 32)),
            mintAddress: ataPlan.mintAddress,
            tokenProgramKind: .token2022,
            recipientOwnerAddress: recipient,
            recipientTokenAccount: ataPlan.associatedTokenAddress,
            amountRaw: 1_234_500,
            amountText: "1.2345",
            decimals: 6,
            availableAmountRaw: 2_000_000,
            ataPlan: ataPlan,
            tokenSymbol: "UNIT",
            tokenName: "Unit Token"
        )
        let tokenReview = ShieldReviewService.reviewTokenTransfer(
            draft: tokenDraft,
            simulation: SimulationResult(status: .success, logs: [], estimatedFeeLamports: 6_000, errorMessage: nil, simulatedAt: Date(timeIntervalSince1970: 2))
        )
        #expect(tokenReview.programLabels.contains("Token-2022"))
        #expect(tokenReview.programLabels.contains("Associated Token Account"))
        #expect(tokenReview.parsedActions.contains { $0.label.contains("Token transferChecked") })
        #expect(tokenReview.riskFlags.contains { $0.kind == TransactionRiskFlagKind.token2022TransferHook.rawValue })
        #expect(tokenReview.riskFlags.contains { $0.kind == TransactionRiskFlagKind.token2022TransferFee.rawValue })

        let quote = JupiterQuoteSummary(
            inputMint: SwapConstants.nativeSolMint,
            outputMint: ataPlan.mintAddress,
            inAmount: 100_000_000,
            outAmount: 99_000,
            otherAmountThreshold: 98_000,
            swapMode: "ExactIn",
            slippageBps: 50,
            priceImpactPct: Decimal(string: "0.01"),
            routePlan: [
                SwapRouteLeg(
                    ammKey: "unit-amm",
                    label: "Jupiter",
                    inputMint: SwapConstants.nativeSolMint,
                    outputMint: ataPlan.mintAddress,
                    inAmount: 100_000_000,
                    outAmount: 99_000,
                    feeAmount: nil,
                    feeMint: nil,
                    percent: 100,
                    bps: nil
                )
            ],
            contextSlot: nil,
            timeTaken: nil,
            rawQuoteJSON: Data("{}".utf8)
        )
        let swapReview = SwapTransactionReview(
            transactionVersion: "v0",
            feePayer: sender,
            signerAccounts: [sender],
            writableAccounts: [sender, recipient],
            programSummaries: [
                SwapInstructionProgramSummary(programID: TransactionInstructionLabeler.jupiterV6ProgramID, label: "Jupiter", instructionCount: 1)
            ],
            accountSummaries: [],
            requiredSignatureCount: 1,
            messageBase64: "safe-message-summary",
            transactionFingerprint: "unit-swap",
            addressLookupTableCount: 1,
            riskWarnings: [
                SwapRouteRiskWarning(severity: .warning, message: "Unit route warning.")
            ],
            warnings: [],
            blockingReasons: []
        )
        let swapShield = ShieldReviewService.reviewSwap(
            quote: quote,
            review: swapReview,
            simulation: failedSimulation,
            network: .mainnetBeta
        )
        #expect(swapShield.programLabels.contains("Jupiter"))
        #expect(swapShield.riskFlags.contains { $0.kind == TransactionRiskFlagKind.addressLookupTableUse.rawValue })
        #expect(swapShield.riskFlags.contains { $0.message.contains("Unit route warning") })

        let orcaPlan = OrcaHarvestPlan(
            walletPublicAddress: sender,
            positionMint: Base58.encode(Data(repeating: 13, count: 32)),
            positionAddress: Base58.encode(Data(repeating: 14, count: 32)),
            poolAddress: Base58.encode(Data(repeating: 15, count: 32)),
            tokenAMint: Base58.encode(Data(repeating: 16, count: 32)),
            tokenBMint: Base58.encode(Data(repeating: 17, count: 32)),
            feeOwedA: nil,
            feeOwedB: nil,
            rewardOwed: nil,
            instructionCount: 1,
            writableAccountCount: 3,
            signerAccounts: [sender],
            programIDs: [OrcaHarvestConstants.whirlpoolProgramID],
            instructions: [],
            source: OrcaHarvestConstants.source,
            expiresAt: Date(timeIntervalSince1970: 300),
            warning: "unit warning"
        )
        let orcaDraft = OrcaHarvestDraft(
            walletID: UUID(),
            walletPublicAddress: sender,
            network: .mainnetBeta,
            positionMint: orcaPlan.positionMint,
            positionAddress: orcaPlan.positionAddress ?? "",
            poolAddress: orcaPlan.poolAddress ?? "",
            plan: orcaPlan,
            createdAt: Date(timeIntervalSince1970: 3)
        )
        let orcaShield = ShieldReviewService.reviewOrcaHarvest(draft: orcaDraft, review: nil, simulation: failedSimulation)
        #expect(orcaShield.programLabels.contains("Orca Whirlpool"))
        #expect(orcaShield.riskFlags.contains { $0.kind == TransactionRiskFlagKind.defiProtocolInteraction.rawValue })

        let cloakDraft = try CloakDepositDraft(network: .mainnetBeta, sourceWalletAddress: sender, grossLamports: 20_000_000)
        let cloakShield = ShieldReviewService.reviewCloakDeposit(draft: cloakDraft)
        #expect(cloakShield.riskLevel == .high)
        #expect(cloakShield.explanation.lowercased().contains("private proof") == false)
        #expect(cloakShield.explanation.lowercased().contains("raw cloak transaction bytes are not exposed"))

        let zerionShield = ShieldReviewService.reviewZerionTinySwap(
            proposal: .sampleBaseTinySwap,
            decision: .blocked(["unit policy missing"], cap: 5),
            commandPlan: .unavailable(reason: "command unavailable")
        )
        #expect(zerionShield.status == .externalSummary)
        #expect(zerionShield.explanation.contains("raw transaction decode unavailable"))
        #expect(zerionShield.explanation.contains("GORKH main wallet") == false || zerionShield.riskFlags.contains { $0.message.contains("main-wallet") || $0.message.contains("main wallet") })

        let unavailable = ShieldReviewSummary.unavailable(title: "Unit unavailable", reason: "internal decode error", requirements: [.review])
        #expect(ShieldReviewPolicy.requiresBlockingReview(unavailable))

        let handoff = ShieldReviewHandoffBuilder.safeSummary(for: tokenReview).lowercased()
        #expect(handoff.contains("no raw transaction payload"))
        #expect(!handoff.contains("serializedtransaction"))
        #expect(!handoff.contains("transactionpayload"))

        let encoded = try #require(String(data: JSONEncoder().encode(tokenReview), encoding: .utf8)).lowercased()
        for forbidden in ["privatekey", "secretkey", "seedphrase", "mnemonic", "walletjson", "signingseed", "serializedtransaction", "transactionpayload"] {
            #expect(!encoded.contains(forbidden))
        }

        let shieldSource = try [
            "GORKH/Core/ShieldReview/ShieldReviewModels.swift",
            "GORKH/Core/ShieldReview/ShieldReviewService.swift",
            "GORKH/Core/ShieldReview/ShieldReviewPolicy.swift",
            "GORKH/Core/ShieldReview/ShieldReviewHandoff.swift",
            "GORKH/Modules/ShieldReview/ShieldReviewCard.swift",
            "GORKH/Modules/ShieldReview/ShieldReviewDetailView.swift"
        ].map { try sourceText(relativePath: $0) }.joined(separator: "\n").lowercased()
        for forbidden in ["sendtransaction(", "requestairdrop(", "signtransaction(", "broadcast(", "buildbundle", "/bin/sh", "eval("] {
            #expect(!shieldSource.contains(forbidden))
        }
        #expect(!shieldSource.contains("nft"))

        let architecture = try sourceText(relativePath: "../../../docs/architecture/shield-review-integration.md").lowercased()
        let smoke = try sourceText(relativePath: "../../../docs/qa/shield-review-approval-smoke.md").lowercased()
        #expect(architecture.contains("review-only"))
        #expect(architecture.contains("no external dapp signing"))
        #expect(smoke.contains("sol send"))
        #expect(smoke.contains("zerion"))
        #expect(!architecture.contains("nft"))
        #expect(!smoke.contains("nft"))
    }

    @Test func agentMemoryAndAuditRedactionContainNoSecrets() throws {
        let sensitive = "ZERION_API_KEY=zk_unit_test_secret agent token: spend-power private key: abc"
        let message = AgentChatMessage(role: .user, text: sensitive)
        #expect(!message.text.contains("zk_unit_test_secret"))
        #expect(!message.text.contains("spend-power"))
        #expect(!message.text.contains("abc"))

        let classification = AgentIntentClassifier().classify("swap 1 USDC to SOL")
        let decision = AgentPolicyDecision.allowed(warnings: ["Agent cannot execute from chat."])
        let proposal = AgentProposalFactory.makeProposal(classification: classification, lane: .mainWallet, decision: decision)
        var memory = AgentMemoryStore()
        memory.remember(intent: classification, proposal: proposal)

        let event = AgentAuditEvent(kind: .agentChatMessageReceived, message: sensitive, details: ["agentToken": "spend-power"])
        let json = try #require(String(data: JSONEncoder().encode([message, AgentChatMessage(role: .assistant, text: event.message)]), encoding: .utf8)).lowercased()
        let memoryJSON = try #require(String(data: JSONEncoder().encode(memory), encoding: .utf8)).lowercased()
        let eventJSON = try #require(String(data: JSONEncoder().encode(event), encoding: .utf8)).lowercased()

        for payload in [json, memoryJSON, eventJSON] {
            #expect(!payload.contains("zk_unit_test_secret"))
            #expect(!payload.contains("spend-power"))
            #expect(!payload.contains("privatekey"))
            #expect(!payload.contains("walletjson"))
            #expect(!payload.contains("serializedtransaction"))
            #expect(!payload.contains("transactionpayload"))
            #expect(!payload.contains("nft"))
        }
    }

    @Test func zerionTinySwapPolicyBlocksUnsafeOrUnreadyExecution() {
        let now = Date(timeIntervalSince1970: 1_000)
        let policy = ZerionPolicySummary(
            id: "manual-policy",
            name: "manual-policy",
            allowedChains: ["base"],
            expiresAt: Date(timeIntervalSince1970: 2_000),
            deniesTransfers: true,
            deniesApprovals: true,
            allowlistCount: 1,
            walletBinding: "manual-zerion-wallet",
            status: .loaded
        )
        let token = ZerionAgentTokenSummary(id: "token-redacted", policyID: "manual-policy", status: .presentRedacted, expiresAt: nil)
        let policySnapshot = ZerionPolicyCenterSnapshot(
            policies: [policy],
            tokens: [token],
            status: .loaded,
            unavailableReason: nil,
            updatedAt: now
        )
        let status = ZerionStatusSnapshot(
            cliStatus: .installed,
            executablePath: "/opt/homebrew/bin/zerion",
            nodeStatus: .installed,
            nodeVersion: "v22.22.2",
            apiKeyStatus: .presentRedacted,
            agentTokenStatus: .presentRedacted,
            policyStatus: .loaded,
            swapHelpStatus: .succeeded,
            swapCommandShape: .chainFirst,
            walletCount: 1,
            policyCount: 1,
            tokenCount: 1,
            supportedChains: ["base"],
            errors: [],
            checkedAt: now
        )
        let help = ZerionCLIHelpProbe(
            topHelpAvailable: true,
            swapHelpAvailable: true,
            agentHelpAvailable: true,
            swapCommandShape: .chainFirst,
            supportsJSONFlag: true,
            supportsWalletFlag: true,
            supportsChainFlag: true,
            checkedAt: now
        )
        let proposal = ZerionTinySwapProposal(
            zerionWalletName: "manual-zerion-wallet",
            chain: .base,
            fromToken: "USDC",
            toToken: "ETH",
            amount: 1,
            estimatedNotionalUSD: 1,
            policyID: "manual-policy",
            policyName: "manual-policy",
            expiresAt: nil,
            riskNotes: [],
            createdAt: now
        )
        let approval = ZerionExecutionApproval(
            proposalID: proposal.id,
            proposalFingerprint: proposal.fingerprint,
            confirmationPhrase: ZerionTinySwapProposal.requiredConfirmationPhrase,
            unknownValueAcknowledged: false,
            approvedAt: now
        )
        let context = ZerionExecutionPolicyContext(
            statusSnapshot: status,
            policySnapshot: policySnapshot,
            helpProbe: help,
            now: now
        )
        #expect(ZerionExecutionPolicy.validate(proposal: proposal, approval: approval, context: context).canExecute)

        let wrongChain = ZerionTinySwapProposal(
            zerionWalletName: "manual-zerion-wallet",
            chain: .solana,
            fromToken: "SOL",
            toToken: "USDC",
            amount: Decimal(string: "0.001") ?? 0,
            estimatedNotionalUSD: 1,
            policyID: "manual-policy",
            policyName: "manual-policy",
            expiresAt: nil,
            riskNotes: [],
            createdAt: now
        )
        let wrongChainDecision = ZerionExecutionPolicy.validate(proposal: wrongChain, approval: ZerionExecutionApproval(
            proposalID: wrongChain.id,
            proposalFingerprint: wrongChain.fingerprint,
            confirmationPhrase: ZerionTinySwapProposal.requiredConfirmationPhrase,
            unknownValueAcknowledged: false,
            approvedAt: now
        ), context: context)
        #expect(!wrongChainDecision.canExecute)
        #expect(wrongChainDecision.blockingReasons.contains { $0.lowercased().contains("chain") })

        let aboveCap = ZerionTinySwapProposal(
            zerionWalletName: "manual-zerion-wallet",
            chain: .base,
            fromToken: "USDC",
            toToken: "ETH",
            amount: 10,
            estimatedNotionalUSD: 10,
            policyID: "manual-policy",
            policyName: "manual-policy",
            expiresAt: nil,
            riskNotes: [],
            createdAt: now
        )
        #expect(!ZerionExecutionPolicy.validate(proposal: aboveCap, approval: ZerionExecutionApproval(
            proposalID: aboveCap.id,
            proposalFingerprint: aboveCap.fingerprint,
            confirmationPhrase: ZerionTinySwapProposal.requiredConfirmationPhrase,
            unknownValueAcknowledged: false,
            approvedAt: now
        ), context: context).canExecute)

        let stale = ZerionTinySwapProposal(
            zerionWalletName: "manual-zerion-wallet",
            chain: .base,
            fromToken: "USDC",
            toToken: "ETH",
            amount: 1,
            estimatedNotionalUSD: 1,
            policyID: "manual-policy",
            policyName: "manual-policy",
            expiresAt: nil,
            riskNotes: [],
            createdAt: now.addingTimeInterval(-3600)
        )
        #expect(!ZerionExecutionPolicy.validate(proposal: stale, approval: ZerionExecutionApproval(
            proposalID: stale.id,
            proposalFingerprint: "mismatch",
            confirmationPhrase: ZerionTinySwapProposal.requiredConfirmationPhrase,
            unknownValueAcknowledged: false,
            approvedAt: now
        ), context: context).canExecute)

        var missingAPI = status
        missingAPI = ZerionStatusSnapshot(
            cliStatus: missingAPI.cliStatus,
            executablePath: missingAPI.executablePath,
            nodeStatus: missingAPI.nodeStatus,
            nodeVersion: missingAPI.nodeVersion,
            apiKeyStatus: .missing,
            agentTokenStatus: missingAPI.agentTokenStatus,
            policyStatus: missingAPI.policyStatus,
            swapHelpStatus: missingAPI.swapHelpStatus,
            swapCommandShape: missingAPI.swapCommandShape,
            walletCount: missingAPI.walletCount,
            policyCount: missingAPI.policyCount,
            tokenCount: missingAPI.tokenCount,
            supportedChains: missingAPI.supportedChains,
            errors: [],
            checkedAt: now
        )
        #expect(!ZerionExecutionPolicy.validate(proposal: proposal, approval: approval, context: ZerionExecutionPolicyContext(
            statusSnapshot: missingAPI,
            policySnapshot: policySnapshot,
            helpProbe: help,
            now: now
        )).canExecute)
    }

    @Test func zerionExecutionResultParsingAndModelsStaySafe() throws {
        let success = ZerionCommandResult(
            command: "zerion_tiny_swap",
            status: .succeeded,
            exitCode: 0,
            stdoutSummary: #"{"status":"submitted","chain":"base","txHash":"0xabc123"}"#,
            stderrSummary: "",
            completedAt: Date(timeIntervalSince1970: 0)
        )
        let parsed = ZerionExecutionResultParser.parse(commandResult: success, fallbackChain: .base)
        #expect(parsed.status == .executed)
        #expect(parsed.transactionHash == "0xabc123")
        #expect(parsed.explorerURL?.absoluteString.contains("basescan.org") == true)

        let failure = ZerionCommandResult(
            command: "zerion_tiny_swap",
            status: .failed,
            exitCode: 1,
            stdoutSummary: "",
            stderrSummary: #"{"errors":[{"code":"POLICY_DENIED","message":"policy rejected"}]}"#,
            completedAt: Date(timeIntervalSince1970: 0)
        )
        let failed = ZerionExecutionResultParser.parse(commandResult: failure, fallbackChain: .base)
        #expect(failed.status == .failed)
        #expect(failed.message.lowercased().contains("policy"))

        let encoded = try JSONEncoder().encode([
            String(data: JSONEncoder().encode(ZerionTinySwapProposal.sampleBaseTinySwap), encoding: .utf8) ?? "",
            String(data: JSONEncoder().encode(parsed), encoding: .utf8) ?? ""
        ])
        let json = try #require(String(data: encoded, encoding: .utf8)).lowercased()
        for forbidden in ["privatekey", "secretkey", "seedphrase", "signingseed", "walletjson", "zerion_api_key", "agenttoken", "nft"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func agentZerionDocsExistAndStateExecutionBoundaries() throws {
        let architecture = try sourceText(relativePath: "../../../docs/architecture/agent-zerion-executor.md").lowercased()
        let operatorArchitecture = try sourceText(relativePath: "../../../docs/architecture/agent-policy-wallet-operator.md").lowercased()
        let smoke = try sourceText(relativePath: "../../../docs/qa/agent-zerion-foundation-smoke.md").lowercased()
        let tinySmoke = try sourceText(relativePath: "../../../docs/qa/zerion-tiny-transaction-smoke.md").lowercased()
        let operatorSmoke = try sourceText(relativePath: "../../../docs/qa/agent-policy-wallet-operator-smoke.md").lowercased()
        let hostedArchitecture = try sourceText(relativePath: "../../../docs/architecture/agent-hosted-ai.md").lowercased()
        let hostedContract = try sourceText(relativePath: "../../../docs/architecture/agent-hosted-api-contract.md").lowercased()
        let hostedRedaction = try sourceText(relativePath: "../../../docs/security/agent-ai-redaction-boundary.md").lowercased()
        let hostedSmoke = try sourceText(relativePath: "../../../docs/qa/agent-hosted-ai-smoke.md").lowercased()

        #expect(architecture.contains("a2 allows one policy-validated tiny same-chain zerion swap only"))
        #expect(architecture.contains("phase a3 adds agent chat as a proposal and handoff layer"))
        #expect(architecture.contains("separate from the gorkh wallet"))
        #expect(architecture.contains("a1 allows read/status zerion cli commands only"))
        #expect(architecture.contains("if help is unavailable or ambiguous, live execution remains locked"))
        #expect(operatorArchitecture.contains("chat does not execute transactions"))
        #expect(operatorArchitecture.contains("watch-only wallets remain analysis-only"))
        #expect(operatorArchitecture.contains("zerion uses a separate policy-scoped agent wallet"))
        #expect(smoke.contains("zerion executor"))
        #expect(smoke.contains("do not add"))
        #expect(smoke.contains("a2"))
        #expect(tinySmoke.contains("zerion tiny transaction smoke"))
        #expect(tinySmoke.contains("separate zerion wallet"))
        #expect(tinySmoke.contains("do not run bridge, send, sign-message, or sign-typed-data"))
        #expect(operatorSmoke.contains("agent policy wallet operator smoke"))
        #expect(operatorSmoke.contains("chat never executes"))
        #expect(hostedArchitecture.contains("gorkh hosted agent api"))
        #expect(hostedArchitecture.contains("local safe mode"))
        #expect(hostedArchitecture.contains("cannot approve, execute, sign"))
        #expect(hostedContract.contains("post /v1/agent/chat"))
        #expect(hostedContract.contains("all response fields are advisory"))
        #expect(hostedRedaction.contains("response sanitization blocks unsafe tool suggestions"))
        #expect(hostedSmoke.contains("agent hosted ai smoke"))
        #expect(hostedSmoke.contains("no proposal execution"))
        #expect(hostedSmoke.contains("scripts/agent-hosted-ai-smoke.sh --mock"))
        #expect(!architecture.contains("nft"))
        #expect(!tinySmoke.contains("nft"))
        #expect(!operatorArchitecture.contains("nft"))
        #expect(!operatorSmoke.contains("nft"))
        #expect(!hostedArchitecture.contains("nft"))
        #expect(!hostedContract.contains("nft"))
        #expect(!hostedRedaction.contains("nft"))
        #expect(!hostedSmoke.contains("nft"))
    }

    @Test func zerionHackathonDemoPackExistsAndStaysSecretFree() throws {
        let runbook = try sourceText(relativePath: "../../../docs/demo/zerion-agent-demo-runbook.md")
        let policies = try sourceText(relativePath: "../../../docs/demo/zerion-policy-templates.md")
        let video = try sourceText(relativePath: "../../../docs/demo/zerion-agent-video-script.md")
        let submission = try sourceText(relativePath: "../../../docs/demo/zerion-submission-summary.md")
        let e2e = try sourceText(relativePath: "../../../docs/qa/zerion-agent-e2e-smoke.md")
        let release = try sourceText(relativePath: "../../../docs/qa/wallet-release-readiness.md")

        let lowercasedDocs = [runbook, policies, video, submission, e2e, release].joined(separator: "\n").lowercased()
        #expect(lowercasedDocs.contains("separate zerion wallet") || lowercasedDocs.contains("separate tiny-funded zerion wallet"))
        #expect(lowercasedDocs.contains("scoped policy"))
        #expect(lowercasedDocs.contains("agent tokens have spending power"))
        #expect(lowercasedDocs.contains("transaction hash/signature"))
        #expect(lowercasedDocs.contains("do not claim a live transaction"))
        #expect(lowercasedDocs.contains("a7 demo pack"))
        #expect(lowercasedDocs.contains("a8 rehearsal"))
        #expect(lowercasedDocs.contains("zerion cli was not resolved in path") || lowercasedDocs.contains("zerion cli status: not resolved in path"))
        #expect(lowercasedDocs.contains("no live transaction was executed") || lowercasedDocs.contains("status: blocked before live transaction"))

        let demoDocs = [runbook, policies, video, submission, e2e].joined(separator: "\n")
        for forbidden in [
            "zk_",
            "ZERION_API_KEY=",
            "agent token value",
            "PRIVATE_KEY",
            "SECRET_KEY",
            "MNEMONIC",
            "SEED",
            "WALLET_JSON",
            "RPCFAST",
            "DEEPSEEK_API_KEY"
        ] {
            #expect(!demoDocs.contains(forbidden))
        }
        #expect(!demoDocs.lowercased().contains("nft"))

        let uiCopy = try [
            "GORKH/Modules/Agent/ZerionExecutorView.swift",
            "GORKH/Modules/Agent/ZerionPolicyCenterView.swift",
            "GORKH/Modules/Agent/ZerionProposalView.swift",
            "GORKH/Modules/Agent/ZerionExecutionReviewView.swift"
        ].map(sourceText(relativePath:)).joined(separator: "\n").lowercased()
        #expect(uiCopy.contains("separate zerion wallet") || uiCopy.contains("separate tiny-funded"))
        #expect(uiCopy.contains("scoped policy"))
        #expect(uiCopy.contains("gorkh main-wallet access") || uiCopy.contains("does not use the gorkh main wallet"))
        #expect(uiCopy.contains("no arbitrary shell"))

        let cliCommandSource = try sourceText(relativePath: "GORKH/Core/Zerion/ZerionCLICommand.swift")
        #expect(!cliCommandSource.contains("case bridge"))
        #expect(!cliCommandSource.contains("case send"))
        #expect(!cliCommandSource.contains("case signMessage"))
        #expect(!cliCommandSource.contains("case signTypedData"))
    }

    @Test func sharedXcodeSchemeContainsNoSecretEnvironmentValues() throws {
        let scheme = try sourceText(relativePath: "GORKH.xcodeproj/xcshareddata/xcschemes/GORKH.xcscheme")
        let uppercased = scheme.uppercased()
        for forbidden in [
            "RPCFAST",
            "GORKH_RPCFAST",
            "JUPITER",
            "API_KEY",
            "GORKH_AGENT_API_KEY",
            "GORKH_AGENT_API_BASE_URL",
            "PRIVATE_KEY",
            "SECRET_KEY",
            "MNEMONIC",
            "SEED",
            "WALLET_JSON",
            "ZERION_API_KEY",
            "WALLET_PRIVATE_KEY",
            "EVM_PRIVATE_KEY",
            "SOLANA_PRIVATE_KEY",
            "TEMPO_PRIVATE_KEY"
        ] {
            #expect(!uppercased.contains(forbidden))
        }
        #expect(!scheme.contains("EnvironmentVariables"))
    }

    @Test func walletProductionCopyKeepsSafetyClaimsHonest() throws {
        let files = [
            "GORKH/Modules/Wallet/WalletInspectorView.swift",
            "GORKH/Modules/Wallet/WalletOverviewView.swift",
            "GORKH/Modules/Wallet/WalletReceiveView.swift",
            "GORKH/Modules/Wallet/Private/WalletPrivateView.swift",
            "GORKH/Modules/Wallet/Portfolio/PortfolioPnLView.swift"
        ]
        let source = try files.map(sourceText(relativePath:)).joined(separator: "\n").lowercased()

        #expect(source.contains("signing always requires approval") || source.contains("signing guard active"))
        #expect(source.contains("mainnet"))
        #expect(source.contains("not tax-grade"))
        #expect(source.contains("read-only"))
        #expect(source.contains("agent signer"))
        #expect(!source.contains("tax report"))
        #expect(!source.contains("tax filing"))
        #expect(!source.contains("certified"))
        #expect(!source.contains("guaranteed profit"))
        #expect(!source.contains("nft"))
    }

    @Test func raydiumAdapterReportsPartialWhenEnrichmentMissingAndAggregatesWithOtherLPs() async throws {
        let profile = WalletProfile(label: "LP", publicAddress: SolanaConstants.systemProgramID)
        let meteora = LPAdapterResult(
            protocolKind: .meteora,
            status: .loaded,
            positions: [sampleLPPosition(profile: profile, protocolKind: .meteora, estimatedValueUSD: 50)],
            source: .sdkReadOnly,
            updatedAt: Date(timeIntervalSince1970: 0),
            errorMessage: nil
        )
        let orca = LPAdapterResult(
            protocolKind: .orca,
            status: .partial,
            positions: [sampleLPPosition(profile: profile, protocolKind: .orca, estimatedValueUSD: nil, status: .partial)],
            source: .sdkReadOnly,
            updatedAt: Date(timeIntervalSince1970: 0),
            errorMessage: "Orca value unavailable"
        )
        let raydium = await RaydiumReadOnlyAdapter(client: MockRaydiumAPIClient(
            stake: try RaydiumAPIClient.decodeOwnerEndpointResult(
                statusCode: 200,
                data: raydiumStakeFixture(),
                owner: profile.publicAddress,
                kind: .standardLP,
                sourceEndpoint: "/position/stake/{owner}",
                emptyMessage: ""
            ),
            locked: RaydiumOwnerEndpointResult(status: .empty, positions: [], message: nil),
            pools: [:],
            mints: [:],
            prices: [:]
        )).fetchPositions(profiles: [profile], network: .mainnetBeta, prices: [:])
        let summary = LPPortfolioAggregator.aggregate(adapterResults: [meteora, orca, raydium], refreshedAt: Date(timeIntervalSince1970: 0))

        #expect(raydium.status == .partial)
        #expect(raydium.positions.first?.estimatedValueUSD == nil)
        #expect(summary.status == .partial)
        #expect(summary.positionCount == 3)
        #expect(summary.estimatedValueUSD == nil)
    }

    @Test func orcaHarvestReviewAllowsOnlyExpectedSignerAndWhirlpoolProgram() throws {
        let wallet = SolanaConstants.systemProgramID
        let plan = sampleOrcaHarvestPlan(wallet: wallet)
        let draft = sampleOrcaHarvestDraft(wallet: wallet, plan: plan)
        let message = try SolanaTransactionBuilder.makeInstructionProposalMessage(
            feePayer: wallet,
            recentBlockhash: SolanaConstants.systemProgramID,
            instructions: try sampleOrcaInstructionProposals(plan.instructions)
        )
        let unsigned = SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message)
        let review = try OrcaHarvestReviewer.review(
            draft: draft,
            serializedTransactionBase64: unsigned,
            expectedWallet: wallet
        )
        let json = try #require(String(data: JSONEncoder().encode(draft), encoding: .utf8)).lowercased()

        #expect(review.canApprove)
        #expect(review.baseReview.requiredSignatureCount == 1)
        #expect(review.baseReview.signerAccounts == [wallet])
        #expect(review.baseReview.programSummaries.contains { $0.programID == OrcaHarvestConstants.whirlpoolProgramID })
        for forbidden in ["privatekey", "secretkey", "signingseed", "seedphrase", "mnemonic", "walletjson", "serializedtransaction", "transactionpayload"] {
            #expect(!json.contains(forbidden))
        }
    }

    @Test func orcaHarvestReviewBlocksUnexpectedSigner() throws {
        let wallet = SolanaConstants.systemProgramID
        let unexpectedSigner = "4N9T5NZ7nVgT5WV5mgWbHcCxgVhM7kUWvQmr6YQb7wNo"
        let instructions = [
            OrcaHarvestInstruction(
                programID: OrcaHarvestConstants.whirlpoolProgramID,
                accounts: [
                    OrcaHarvestInstructionAccount(address: wallet, isSigner: true, isWritable: true),
                    OrcaHarvestInstructionAccount(address: unexpectedSigner, isSigner: true, isWritable: false)
                ],
                dataBase64: Data([1, 2, 3]).base64EncodedString()
            )
        ]
        let plan = sampleOrcaHarvestPlan(wallet: wallet, instructions: instructions, signerAccounts: [wallet, unexpectedSigner])
        let draft = sampleOrcaHarvestDraft(wallet: wallet, plan: plan)
        let message = try SolanaTransactionBuilder.makeInstructionProposalMessage(
            feePayer: wallet,
            recentBlockhash: SolanaConstants.systemProgramID,
            instructions: try sampleOrcaInstructionProposals(plan.instructions)
        )
        let review = try OrcaHarvestReviewer.review(
            draft: draft,
            serializedTransactionBase64: SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message),
            expectedWallet: wallet
        )

        #expect(!review.canApprove)
        #expect(review.blockingReasons.contains { $0.contains("unexpected signer") })
    }

    @Test func orcaHarvestApprovalGuardRequiresSimulationMainnetPhraseAndFreshFingerprint() throws {
        let wallet = SolanaConstants.systemProgramID
        let plan = sampleOrcaHarvestPlan(wallet: wallet)
        let draft = sampleOrcaHarvestDraft(wallet: wallet, plan: plan)
        let message = try SolanaTransactionBuilder.makeInstructionProposalMessage(
            feePayer: wallet,
            recentBlockhash: SolanaConstants.systemProgramID,
            instructions: try sampleOrcaInstructionProposals(plan.instructions)
        )
        let unsigned = SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message)
        let review = try OrcaHarvestReviewer.review(draft: draft, serializedTransactionBase64: unsigned, expectedWallet: wallet)
        let fingerprint = OrcaHarvestApprovalGuard.fingerprint(draft: draft)
        let simulation = SimulationResult(
            status: .success,
            logs: [],
            estimatedFeeLamports: 5_000,
            errorMessage: nil,
            simulatedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(throws: OrcaHarvestError.self) {
            try OrcaHarvestApprovalGuard.validate(OrcaHarvestApprovalContext(
                draft: draft,
                review: review,
                simulation: nil,
                network: .mainnetBeta,
                walletPublicKey: wallet,
                mainnetConfirmation: TransactionApprovalPolicy.requiredMainnetConfirmation,
                hasCompletedDevnetSmoke: true,
                vaultState: .unlocked,
                hasUnlockedSecret: true,
                hasPreparedMessage: true,
                currentFingerprint: fingerprint,
                preparedFingerprint: fingerprint
            ))
        }

        #expect(throws: OrcaHarvestError.self) {
            try OrcaHarvestApprovalGuard.validate(OrcaHarvestApprovalContext(
                draft: draft,
                review: review,
                simulation: simulation,
                network: .mainnetBeta,
                walletPublicKey: wallet,
                mainnetConfirmation: "wrong",
                hasCompletedDevnetSmoke: true,
                vaultState: .unlocked,
                hasUnlockedSecret: true,
                hasPreparedMessage: true,
                currentFingerprint: fingerprint,
                preparedFingerprint: fingerprint
            ))
        }

        try OrcaHarvestApprovalGuard.validate(OrcaHarvestApprovalContext(
            draft: draft,
            review: review,
            simulation: simulation,
            network: .mainnetBeta,
            walletPublicKey: wallet,
            mainnetConfirmation: TransactionApprovalPolicy.requiredMainnetConfirmation,
            hasCompletedDevnetSmoke: true,
            vaultState: .unlocked,
            hasUnlockedSecret: true,
            hasPreparedMessage: true,
            currentFingerprint: fingerprint,
            preparedFingerprint: fingerprint
        ))
    }

    @Test func swapQuoteRequestValidationAndEndpointGuard() throws {
        let usdcMint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
        let url = try JupiterQuoteClient.quoteURL(
            baseURL: URL(string: "https://lite-api.jup.ag/swap/v1")!,
            inputMint: PortfolioConstants.nativeSolMint,
            outputMint: usdcMint,
            amountRaw: 1_000_000,
            slippageBps: 50
        )
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        #expect(components.host == "lite-api.jup.ag")
        #expect(components.path == "/swap/v1/quote")
        #expect(query["inputMint"] == PortfolioConstants.nativeSolMint)
        #expect(query["outputMint"] == usdcMint)
        #expect(query["amount"] == "1000000")
        #expect(query["slippageBps"] == "50")
        #expect(query["swapMode"] == "ExactIn")

        try SwapValidation.validateQuoteRequest(
            inputMint: PortfolioConstants.nativeSolMint,
            outputMint: usdcMint,
            amountRaw: 1_000_000,
            availableRaw: 2_000_000,
            inputDecimals: 9,
            slippageBps: 50
        )

        #expect(throws: SwapError.self) {
            try JupiterQuoteClient.quoteURL(
                baseURL: URL(string: "https://lite-api.jup.ag/swap/v1/swap")!,
                inputMint: PortfolioConstants.nativeSolMint,
                outputMint: usdcMint,
                amountRaw: 1_000_000,
                slippageBps: 50
            )
        }
        #expect(throws: SwapError.self) {
            try SwapValidation.validateSlippageBps(0)
        }
        #expect(throws: SwapError.self) {
            try SwapValidation.validateQuoteRequest(
                inputMint: PortfolioConstants.nativeSolMint,
                outputMint: PortfolioConstants.nativeSolMint,
                amountRaw: 1,
                availableRaw: 1,
                inputDecimals: 9,
                slippageBps: 50
            )
        }
        #expect(throws: SwapError.self) {
            try SwapValidation.validateQuoteRequest(
                inputMint: PortfolioConstants.nativeSolMint,
                outputMint: usdcMint,
                amountRaw: 3,
                availableRaw: 2,
                inputDecimals: 9,
                slippageBps: 50
            )
        }
    }

    @Test func jupiterQuoteDecodeKeepsRawPayloadOutOfSafeSummary() throws {
        let quote = try JupiterQuoteClient.decodeQuote(
            data: sampleJupiterQuoteData(),
            quotedAt: Date(timeIntervalSince1970: 1_000)
        )
        let encodedSafeSummary = try JSONEncoder().encode(quote.safeSummary)
        let json = try #require(String(data: encodedSafeSummary, encoding: .utf8)).lowercased()

        #expect(quote.inputMint == PortfolioConstants.nativeSolMint)
        #expect(quote.outputMint == "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v")
        #expect(quote.inAmount == 1_000_000)
        #expect(quote.outAmount == 142_000)
        #expect(quote.otherAmountThreshold == 140_000)
        #expect(quote.slippageBps == 50)
        #expect(quote.routePlan.first?.label == "Test AMM")
        #expect(!json.contains("rawquotejson"))
        #expect(!json.contains("serializedtransaction"))
        #expect(!json.contains("swaptransaction"))
        #expect(!json.contains("transactionpayload"))
    }

    @Test func jupiterSwapBuildResponseStaysInMemoryAndReviewable() throws {
        let fixture = try sampleSwapTransactionFixture()
        let response = """
        {
          "swapTransaction": "\(fixture.unsignedTransactionBase64)",
          "lastValidBlockHeight": 123,
          "prioritizationFeeLamports": 5000,
          "computeUnitLimit": 1400000
        }
        """
        let quoteID = UUID()
        let build = try JupiterSwapClient.decodeSwapResponse(
            data: Data(response.utf8),
            quoteID: quoteID,
            userPublicKey: fixture.keypair.publicAddress,
            builtAt: Date(timeIntervalSince1970: 2_000)
        )
        let review = try SwapTransactionReviewer.review(
            serializedTransactionBase64: build.swapTransactionBase64,
            expectedWallet: fixture.keypair.publicAddress
        )

        #expect(build.quoteID == quoteID)
        #expect(build.userPublicKey == fixture.keypair.publicAddress)
        #expect(build.lastValidBlockHeight == 123)
        #expect(build.transactionFingerprint == SwapFingerprint.transactionFingerprint(base64: fixture.unsignedTransactionBase64))
        #expect(review.canApprove)
        #expect(review.transactionVersion == "legacy")
        #expect(review.feePayer == fixture.keypair.publicAddress)
        #expect(review.signerAccounts == [fixture.keypair.publicAddress])
        #expect(review.programSummaries.contains { $0.label == "System Program" })
        #expect(review.riskWarnings.contains { $0.message.contains("legacy format") })
        #expect(review.riskWarnings.contains { $0.message.contains("System program interaction") })
    }

    @Test func swapTransactionReviewBlocksWrongFeePayerAndSignsExpectedSignerOnly() throws {
        let fixture = try sampleSwapTransactionFixture()
        let wrongWallet = Base58.encode(Data(repeating: 8, count: 32))
        let review = try SwapTransactionReviewer.review(
            serializedTransactionBase64: fixture.unsignedTransactionBase64,
            expectedWallet: wrongWallet
        )

        #expect(!review.canApprove)
        #expect(review.blockingReasons.contains("Fee payer does not match the selected wallet."))
        #expect(review.blockingReasons.contains("Selected wallet is not a required signer."))
        #expect(throws: SwapTransactionReviewError.self) {
            try SolanaSerializedTransaction.sign(
                base64: fixture.unsignedTransactionBase64,
                seed: fixture.keypair.seed,
                expectedSigner: wrongWallet
            )
        }

        let signedTransaction = try SolanaSerializedTransaction.sign(
            base64: fixture.unsignedTransactionBase64,
            seed: fixture.keypair.seed,
            expectedSigner: fixture.keypair.publicAddress
        )
        let decodedSigned = try SolanaSerializedTransaction.decode(base64: signedTransaction)
        let signedBytes = try #require(Data(base64Encoded: signedTransaction))
        let signature = Data(signedBytes[decodedSigned.signaturesOffset..<(decodedSigned.signaturesOffset + 64)])
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: fixture.keypair.publicKey)

        #expect(signature.count == 64)
        #expect(signature != Data(repeating: 0, count: 64))
        #expect(publicKey.isValidSignature(signature, for: decodedSigned.messageData))
        #expect(decodedSigned.messageData == fixture.message)
    }

    @Test func swapRouteRiskReviewFlagsUnknownProgramsWritableSignersAndLookupTables() throws {
        let expectedWallet = Base58.encode(Data(repeating: 1, count: 32))
        var accountKeys = [
            expectedWallet,
            Base58.encode(Data(repeating: 2, count: 32)),
            Base58.encode(Data(repeating: 3, count: 32)),
            SolanaConstants.systemProgramID
        ]
        for value in 4...36 {
            accountKeys.append(Base58.encode(Data(repeating: UInt8(value), count: 32)))
        }
        let decoded = DecodedSolanaTransaction(
            originalData: Data(),
            signatureCount: 2,
            signaturesOffset: 0,
            messageOffset: 0,
            messageData: Data(),
            version: "v0",
            requiredSignatures: 2,
            readonlySignedAccounts: 0,
            readonlyUnsignedAccounts: 0,
            accountKeys: accountKeys,
            instructionProgramIndexes: [2, 3],
            addressLookupTableCount: 1
        )
        let warnings = SwapRouteRiskReviewer.review(decoded: decoded, expectedWallet: expectedWallet)

        #expect(warnings.contains { $0.severity == .high && $0.message.contains("unrecognized program") })
        #expect(warnings.contains { $0.severity == .high && $0.message.contains("writable signer") })
        #expect(warnings.contains { $0.severity == .warning && $0.message.contains("address lookup table") })
        #expect(warnings.contains { $0.severity == .warning && $0.message.contains("writable static account") })
        #expect(warnings.contains { $0.severity == .info && $0.message.contains("System program interaction") })
    }

    @Test func swapApprovalGuardRequiresFreshReviewSimulationAndFingerprint() throws {
        try SwapApprovalGuard.validate(try sampleSwapApprovalContext())

        #expect(throws: SwapError.self) {
            try SwapApprovalGuard.validate(try sampleSwapApprovalContext(simulation: nil))
        }
        #expect(throws: SwapError.self) {
            try SwapApprovalGuard.validate(try sampleSwapApprovalContext(
                simulation: SimulationResult(
                    status: .failed,
                    logs: ["Program failed"],
                    estimatedFeeLamports: nil,
                    errorMessage: "Simulation failed",
                    simulatedAt: Date()
                )
            ))
        }
        #expect(throws: SwapError.self) {
            try SwapApprovalGuard.validate(try sampleSwapApprovalContext(quoteAgeSeconds: 120))
        }
        #expect(throws: SwapError.self) {
            try SwapApprovalGuard.validate(try sampleSwapApprovalContext(preparedFingerprint: "changed"))
        }
        #expect(throws: SwapError.self) {
            try SwapApprovalGuard.validate(try sampleSwapApprovalContext(
                network: .mainnetBeta,
                mainnetConfirmation: "I understand",
                hasCompletedDevnetSmoke: true
            ))
        }
        try SwapApprovalGuard.validate(try sampleSwapApprovalContext(
            network: .mainnetBeta,
            mainnetConfirmation: TransactionApprovalPolicy.requiredMainnetConfirmation,
            hasCompletedDevnetSmoke: true
        ))
    }

    @Test func swapAuditEventsRedactSerializedPayloads() throws {
        let event = AuditEvent(
            kind: .swapTransactionBuilt,
            walletID: UUID(),
            network: .mainnetBeta,
            publicAddress: SolanaConstants.systemProgramID,
            message: "Swap built",
            details: [
                "inputMint": PortfolioConstants.nativeSolMint,
                "outputMint": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
                "serializedTransaction": "do-not-store",
                "swapTransaction": "do-not-store",
                "transactionPayload": "do-not-store"
            ]
        )
        let json = try #require(String(data: JSONEncoder().encode(event), encoding: .utf8)).lowercased()

        #expect(json.contains("swap_transaction_built"))
        #expect(json.contains("inputmint"))
        #expect(!json.contains("do-not-store"))
        #expect(!json.contains("serializedtransaction"))
        #expect(!json.contains("swaptransaction"))
        #expect(!json.contains("transactionpayload"))
    }

    @Test func swapBalanceDeltaVerificationReportsVerifiedMismatchAndUnavailable() throws {
        let quote = try sampleJupiterQuote()
        let verified = SwapBalanceDeltaVerifier.verify(
            quote: quote,
            before: [
                quote.inputMint: 2_000_000,
                quote.outputMint: 1_000
            ],
            after: [
                quote.inputMint: 900_000,
                quote.outputMint: 141_100
            ],
            checkedAt: Date(timeIntervalSince1970: 10)
        )
        #expect(verified.status == .verified)
        #expect(verified.inputDeltaRaw == -1_100_000)
        #expect(verified.outputDeltaRaw == 140_100)

        let mismatch = SwapBalanceDeltaVerifier.verify(
            quote: quote,
            before: [
                quote.inputMint: 2_000_000,
                quote.outputMint: 1_000
            ],
            after: [
                quote.inputMint: 1_500_000,
                quote.outputMint: 20_000
            ]
        )
        #expect(mismatch.status == .mismatch)

        let unavailable = SwapBalanceDeltaVerifier.verify(
            quote: quote,
            before: [quote.inputMint: 2_000_000],
            after: [quote.inputMint: 900_000]
        )
        #expect(unavailable.status == .unavailable)
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

    @Test func autoLockTimeoutModelLocksAfterConfiguredInactivity() {
        let start = Date(timeIntervalSince1970: 1_000)
        var controller = WalletLockController(policy: .default, now: start)

        #expect(!controller.shouldAutoLock(now: start.addingTimeInterval(299)))
        #expect(controller.shouldAutoLock(now: start.addingTimeInterval(300)))

        var policy = WalletSecurityPolicy.default
        policy.autoLockTimeout = .never
        controller.updatePolicy(policy, now: start)
        #expect(!controller.shouldAutoLock(now: start.addingTimeInterval(10_000)))
    }

    @Test func signingPreflightBlocksLockedMissingSimulationAndDraftMismatch() throws {
        let simulation = SimulationResult(
            status: .success,
            logs: [],
            estimatedFeeLamports: 5_000,
            errorMessage: nil,
            simulatedAt: Date()
        )
        let fingerprint = "approved"

        #expect(throws: WalletSigningPreflightError.walletLocked) {
            try WalletApprovalGuard.validate(WalletSigningPreflightContext(
                network: .devnet,
                simulation: simulation,
                mainnetConfirmation: "",
                hasCompletedDevnetSmoke: false,
                allowsUnavailableSimulation: false,
                vaultState: .locked,
                hasUnlockedSecret: true,
                hasPreparedMessage: true,
                preparedDraftFingerprint: fingerprint,
                currentDraftFingerprint: fingerprint,
                hasBlockingWarnings: false
            ))
        }

        #expect(throws: WalletSigningPreflightError.missingSimulation) {
            try WalletApprovalGuard.validate(WalletSigningPreflightContext(
                network: .devnet,
                simulation: nil,
                mainnetConfirmation: "",
                hasCompletedDevnetSmoke: false,
                allowsUnavailableSimulation: false,
                vaultState: .unlocked,
                hasUnlockedSecret: true,
                hasPreparedMessage: true,
                preparedDraftFingerprint: fingerprint,
                currentDraftFingerprint: fingerprint,
                hasBlockingWarnings: false
            ))
        }

        #expect(throws: WalletSigningPreflightError.draftMismatch) {
            try WalletApprovalGuard.validate(WalletSigningPreflightContext(
                network: .devnet,
                simulation: simulation,
                mainnetConfirmation: "",
                hasCompletedDevnetSmoke: false,
                allowsUnavailableSimulation: false,
                vaultState: .unlocked,
                hasUnlockedSecret: true,
                hasPreparedMessage: true,
                preparedDraftFingerprint: fingerprint,
                currentDraftFingerprint: "changed",
                hasBlockingWarnings: false
            ))
        }

        try WalletApprovalGuard.validate(WalletSigningPreflightContext(
            network: .devnet,
            simulation: simulation,
            mainnetConfirmation: "",
            hasCompletedDevnetSmoke: false,
            allowsUnavailableSimulation: false,
            vaultState: .unlocked,
            hasUnlockedSecret: true,
            hasPreparedMessage: true,
            preparedDraftFingerprint: fingerprint,
            currentDraftFingerprint: fingerprint,
            hasBlockingWarnings: false
        ))
    }

    @Test func backupStatusIsHonestForRecoveryAndSeedOnlyWallets() {
        let recovery = WalletProfile(
            label: "Recovery",
            publicAddress: SolanaConstants.systemProgramID,
            walletOrigin: .generatedRecovery,
            derivationPath: DerivationPath.defaultSolana.rawValue
        )
        let importedKey = WalletProfile(
            label: "Imported",
            publicAddress: SolanaConstants.systemProgramID,
            walletOrigin: .importedPrivateKey
        )

        let recoveryStatus = WalletBackupStatus.evaluate(profile: recovery)
        let importedStatus = WalletBackupStatus.evaluate(profile: importedKey)

        #expect(recoveryStatus.recoveryPhraseConfirmed)
        #expect(!recoveryStatus.recoveryPhraseExportAvailable)
        #expect(recoveryStatus.riskStatus == .backedUp)
        #expect(importedStatus.riskStatus == .seedOnlyWallet)
        #expect(!importedStatus.recoveryPhraseExportAvailable)
    }

    @Test func walletDeleteRemovesMetadataAndVaultSecret() throws {
        let vault = InMemoryWalletVault()
        let suiteName = "ai.gorkh.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let auditURL = FileManager.default.temporaryDirectory.appendingPathComponent("gorkh-delete-test-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: auditURL) }
        let manager = WalletManager(
            vault: vault,
            rpcClient: SolanaRPCClient(),
            auditLog: AuditLog(fileURL: auditURL),
            metadataStore: WalletMetadataStore(defaults: defaults),
            securitySettingsStore: WalletSecuritySettingsStore(defaults: defaults),
            localAuthenticationService: MockLocalAuthenticationService(result: .success),
            mnemonicService: Bip39MnemonicService.shared,
            cloakBridge: CloakBridgeUnavailable(),
            cloakPrivateVault: CloakPrivateVaultStatusOnly(),
            cloakHelperInvocationAdapter: .disabled()
        )

        manager.createWallet(label: "Delete Me")
        let profile = try #require(manager.selectedProfile)
        #expect(vault.containsSecret(for: profile.id))

        manager.deleteSelectedWallet(confirmation: "wrong")
        #expect(vault.containsSecret(for: profile.id))
        #expect(!manager.profiles.isEmpty)

        manager.deleteSelectedWallet(confirmation: "DELETE WALLET")
        #expect(!vault.containsSecret(for: profile.id))
        #expect(manager.profiles.isEmpty)
        #expect(manager.auditEvents.contains { $0.kind == .walletDeleted })
    }

    @Test func localAuthenticationGateBlocksFailedUnlock() async throws {
        let vault = InMemoryWalletVault()
        let suiteName = "ai.gorkh.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let auditURL = FileManager.default.temporaryDirectory.appendingPathComponent("gorkh-auth-test-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: auditURL) }
        let manager = WalletManager(
            vault: vault,
            rpcClient: SolanaRPCClient(),
            auditLog: AuditLog(fileURL: auditURL),
            metadataStore: WalletMetadataStore(defaults: defaults),
            securitySettingsStore: WalletSecuritySettingsStore(defaults: defaults),
            localAuthenticationService: MockLocalAuthenticationService(result: .failed("Denied")),
            mnemonicService: Bip39MnemonicService.shared,
            cloakBridge: CloakBridgeUnavailable(),
            cloakPrivateVault: CloakPrivateVaultStatusOnly(),
            cloakHelperInvocationAdapter: .disabled()
        )

        manager.createWallet(label: "Auth")
        manager.lockWallet()
        await manager.unlockWallet()

        #expect(manager.vaultState == .locked)
        #expect(manager.auditEvents.contains { $0.kind == .localAuthenticationFailed })
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
        #expect(WalletSecuritySettingsStore.allowedKeys.allSatisfy { !Redaction.isSensitiveKey($0) })

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

private struct ParsedSolanaMessage {
    let requiredSignatures: UInt8
    let readonlySignedAccounts: UInt8
    let readonlyUnsignedAccounts: UInt8
    let accountKeys: [Data]
    let instructions: [ParsedSolanaInstruction]
}

private struct ParsedSolanaInstruction {
    let programIDIndex: UInt8
    let accountIndexes: [UInt8]
    let data: Data
}

private func parseMessage(_ message: Data) throws -> ParsedSolanaMessage {
    var offset = 0
    let bytes = [UInt8](message)

    func readByte() throws -> UInt8 {
        guard offset < bytes.count else {
            throw TestParsingError.outOfBounds
        }
        defer { offset += 1 }
        return bytes[offset]
    }

    func readShortVector() throws -> Int {
        var value = 0
        var shift = 0

        while true {
            let byte = try readByte()
            value |= Int(byte & 0x7f) << shift
            if byte & 0x80 == 0 {
                return value
            }
            shift += 7
        }
    }

    let requiredSignatures = try readByte()
    let readonlySignedAccounts = try readByte()
    let readonlyUnsignedAccounts = try readByte()
    let accountCount = try readShortVector()
    var accountKeys: [Data] = []

    for _ in 0..<accountCount {
        guard offset + 32 <= bytes.count else {
            throw TestParsingError.outOfBounds
        }
        accountKeys.append(Data(bytes[offset..<(offset + 32)]))
        offset += 32
    }

    guard offset + 32 <= bytes.count else {
        throw TestParsingError.outOfBounds
    }
    offset += 32 // recent blockhash

    let instructionCount = try readShortVector()
    var instructions: [ParsedSolanaInstruction] = []
    for _ in 0..<instructionCount {
        let programIDIndex = try readByte()
        let accountIndexCount = try readShortVector()
        var accountIndexes: [UInt8] = []
        for _ in 0..<accountIndexCount {
            accountIndexes.append(try readByte())
        }
        let dataLength = try readShortVector()
        guard offset + dataLength <= bytes.count else {
            throw TestParsingError.outOfBounds
        }
        let instructionData = Data(bytes[offset..<(offset + dataLength)])
        offset += dataLength
        instructions.append(ParsedSolanaInstruction(
            programIDIndex: programIDIndex,
            accountIndexes: accountIndexes,
            data: instructionData
        ))
    }

    return ParsedSolanaMessage(
        requiredSignatures: requiredSignatures,
        readonlySignedAccounts: readonlySignedAccounts,
        readonlyUnsignedAccounts: readonlyUnsignedAccounts,
        accountKeys: accountKeys,
        instructions: instructions
    )
}

private enum TestParsingError: Error {
    case outOfBounds
}

private struct MockLocalAuthenticationService: LocalAuthenticationService {
    let result: LocalAuthenticationResult

    var statusDescription: String {
        "Mock authentication"
    }

    func authenticate(reason: String) async -> LocalAuthenticationResult {
        result
    }
}

private struct MockCloakHelperPathResolver: CloakHelperPathResolving {
    func resolve(policy: CloakBridgeExecutionPolicy, projectRoot: URL?) throws -> CloakHelperResolvedPath {
        CloakHelperResolvedPath(
            nodeExecutable: URL(fileURLWithPath: "/usr/bin/node"),
            helperScript: URL(fileURLWithPath: "/tmp/gorkh/tools/cloak-bridge/src/index.ts"),
            helperRelativePath: policy.allowlistedHelperRelativePath
        )
    }
}

private struct MockMarginFiHelperBridge: MarginFiHelperBridging {
    let result: LendingAdapterResult?

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LendingAdapterResult? {
        result
    }
}

private struct MockMeteoraHelperBridge: MeteoraHelperBridging {
    let result: LPAdapterResult?

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LPAdapterResult? {
        result
    }
}

private struct MockOrcaHelperBridge: OrcaHelperBridging {
    let result: LPAdapterResult?

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LPAdapterResult? {
        result
    }

    func buildHarvestPlan(position: LPPositionSummary, network: WalletNetwork) async throws -> OrcaHarvestPlan {
        throw OrcaHelperError.disabled
    }
}

private struct MockRaydiumAPIClient: RaydiumAPIClienting {
    let stake: RaydiumOwnerEndpointResult
    let locked: RaydiumOwnerEndpointResult
    let pools: [String: RaydiumPoolInfo]
    let mints: [String: RaydiumMintInfo]
    let prices: [String: Decimal]

    static func empty() -> MockRaydiumAPIClient {
        MockRaydiumAPIClient(
            stake: RaydiumOwnerEndpointResult(status: .empty, positions: [], message: nil),
            locked: RaydiumOwnerEndpointResult(status: .empty, positions: [], message: nil),
            pools: [:],
            mints: [:],
            prices: [:]
        )
    }

    func fetchOwnerStakePositions(owner: String, network: WalletNetwork) async throws -> RaydiumOwnerEndpointResult {
        stake
    }

    func fetchOwnerCLMMLockPositions(owner: String, network: WalletNetwork) async throws -> RaydiumOwnerEndpointResult {
        locked
    }

    func fetchPoolInfos(ids: [String], network: WalletNetwork) async throws -> [String: RaydiumPoolInfo] {
        pools.filter { ids.contains($0.key) }
    }

    func fetchMintInfos(mints: [String], network: WalletNetwork) async throws -> [String: RaydiumMintInfo] {
        self.mints.filter { mints.contains($0.key) }
    }

    func fetchMintPrices(mints: [String], network: WalletNetwork) async throws -> [String: Decimal] {
        prices.filter { mints.contains($0.key) }
    }

    func fetchFarmInfos(lpMint: String, network: WalletNetwork) async throws -> [RaydiumFarmInfo] {
        []
    }
}

private struct MockMarginFiHelperPathResolver: MarginFiHelperPathResolving {
    func resolve(policy: MarginFiHelperInvocationPolicy, projectRoot: URL?) throws -> MarginFiHelperResolvedPath {
        MarginFiHelperResolvedPath(
            nodeExecutable: URL(fileURLWithPath: "/usr/bin/node"),
            helperScript: URL(fileURLWithPath: "/tmp/gorkh/tools/marginfi-readonly/src/index.ts"),
            helperRelativePath: policy.allowlistedHelperRelativePath
        )
    }
}

private struct MockMeteoraHelperPathResolver: MeteoraHelperPathResolving {
    func resolve(policy: MeteoraHelperInvocationPolicy, projectRoot: URL?) throws -> MeteoraHelperResolvedPath {
        MeteoraHelperResolvedPath(
            nodeExecutable: URL(fileURLWithPath: "/usr/bin/node"),
            helperScript: URL(fileURLWithPath: "/tmp/gorkh/tools/meteora-readonly/src/index.ts"),
            helperRelativePath: policy.allowlistedHelperRelativePath
        )
    }
}

private struct MockOrcaHelperPathResolver: OrcaHelperPathResolving {
    func resolve(policy: OrcaHelperInvocationPolicy, projectRoot: URL?) throws -> OrcaHelperResolvedPath {
        OrcaHelperResolvedPath(
            nodeExecutable: URL(fileURLWithPath: "/usr/bin/node"),
            helperScript: URL(fileURLWithPath: "/tmp/gorkh/tools/orca-readonly/src/index.ts"),
            helperRelativePath: policy.allowlistedHelperRelativePath
        )
    }
}

private final class MockMarginFiHelperProcessRunner: MarginFiHelperProcessRunning {
    private let response: MarginFiHelperResponse?
    private let rawStdout: String?

    init(response: MarginFiHelperResponse) {
        self.response = response
        self.rawStdout = nil
    }

    init(rawStdout: String) {
        self.response = nil
        self.rawStdout = rawStdout
    }

    func run(
        resolvedPath: MarginFiHelperResolvedPath,
        command: MarginFiHelperCommand,
        stdin: Data
    ) async throws -> MarginFiHelperProcessResult {
        if let rawStdout {
            return MarginFiHelperProcessResult(exitCode: 0, stdout: Data(rawStdout.utf8), stderr: "")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return MarginFiHelperProcessResult(
            exitCode: 0,
            stdout: try encoder.encode(response),
            stderr: ""
        )
    }
}

private final class MockMeteoraHelperProcessRunner: MeteoraHelperProcessRunning {
    private let response: MeteoraHelperResponse?
    private let rawStdout: String?

    init(response: MeteoraHelperResponse) {
        self.response = response
        self.rawStdout = nil
    }

    init(rawStdout: String) {
        self.response = nil
        self.rawStdout = rawStdout
    }

    func run(
        resolvedPath: MeteoraHelperResolvedPath,
        command: MeteoraHelperCommand,
        stdin: Data
    ) async throws -> MeteoraHelperProcessResult {
        if let rawStdout {
            return MeteoraHelperProcessResult(exitCode: 0, stdout: Data(rawStdout.utf8), stderr: "")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return MeteoraHelperProcessResult(
            exitCode: 0,
            stdout: try encoder.encode(response),
            stderr: ""
        )
    }
}

private final class MockOrcaHelperProcessRunner: OrcaHelperProcessRunning {
    private let response: OrcaHelperResponse?
    private let rawStdout: String?

    init(response: OrcaHelperResponse) {
        self.response = response
        self.rawStdout = nil
    }

    init(rawStdout: String) {
        self.response = nil
        self.rawStdout = rawStdout
    }

    func run(
        resolvedPath: OrcaHelperResolvedPath,
        command: OrcaHelperCommand,
        stdin: Data
    ) async throws -> OrcaHelperProcessResult {
        if let rawStdout {
            return OrcaHelperProcessResult(exitCode: 0, stdout: Data(rawStdout.utf8), stderr: "")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return OrcaHelperProcessResult(
            exitCode: 0,
            stdout: try encoder.encode(response),
            stderr: ""
        )
    }
}

private final class MockCloakHelperProcessRunner: CloakHelperProcessRunning {
    enum Response {
        case success(CloakBridgeResponse)
        case failure(Int32, String)
    }

    private let response: Response?
    private let rawStdout: String?
    private(set) var invocationCount = 0
    private(set) var lastCommand: CloakBridgeCommand?

    init(response: Response) {
        self.response = response
        self.rawStdout = nil
    }

    init(rawStdout: String) {
        self.response = nil
        self.rawStdout = rawStdout
    }

    func run(
        resolvedPath: CloakHelperResolvedPath,
        command: CloakBridgeCommand,
        stdin: Data
    ) async throws -> CloakHelperProcessResult {
        invocationCount += 1
        lastCommand = command

        if let rawStdout {
            return CloakHelperProcessResult(exitCode: 0, stdout: Data(rawStdout.utf8), stderr: "")
        }

        switch response {
        case .success(let response):
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return CloakHelperProcessResult(
                exitCode: 0,
                stdout: try encoder.encode(response),
                stderr: ""
            )
        case .failure(let code, let stderr):
            return CloakHelperProcessResult(exitCode: code, stdout: Data(), stderr: stderr)
        case .none:
            return CloakHelperProcessResult(exitCode: 1, stdout: Data(), stderr: "missing mock response")
        }
    }
}

private extension CloakBridgeResponse {
    static func okResponse(
        command: CloakBridgeCommand,
        status: CloakBridgeStatus = .ok,
        errorCategory: CloakBridgeErrorCategory = .none,
        feeQuote: CloakFeeQuote? = nil,
        sdkValidation: CloakSDKValidation? = nil,
        feeValidation: CloakFeeValidation? = nil,
        environmentValidation: CloakEnvironmentValidation? = nil,
        nextRequiredGates: [String]? = nil
    ) -> CloakBridgeResponse {
        CloakBridgeResponse(
            requestID: UUID(),
            command: command,
            actionKind: command == .depositPlan ? .deposit : nil,
            status: status,
            errorCategory: errorCategory,
            message: "Mock response",
            feeQuote: feeQuote,
            sdkValidation: sdkValidation,
            feeValidation: feeValidation,
            environmentValidation: environmentValidation,
            nextRequiredGates: nextRequiredGates
        )
    }
}

@MainActor private extension CloakBridgeSigningRequest {
    static func testRequest(
        requestID: UUID,
        fingerprint: String,
        id: UUID = UUID(),
        programID: String = CloakConstants.programID,
        walletPublicKey: String = SolanaConstants.systemProgramID,
        amountLamports: UInt64 = 50_000_000,
        expiresAt: Date = Date().addingTimeInterval(120)
    ) throws -> CloakBridgeSigningRequest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let object: [String: Any] = [
            "type": "sign-request",
            "id": id.uuidString,
            "requestId": requestID.uuidString,
            "signingKind": "sign_transaction",
            "walletPublicKey": walletPublicKey,
            "network": WalletNetwork.mainnetBeta.rawValue,
            "actionKind": CloakActionKind.deposit.rawValue,
            "amountLamports": "\(amountLamports)",
            "mintAddress": CloakConstants.nativeSolMint,
            "programId": programID,
            "draftFingerprint": fingerprint,
            "purpose": "Approve Cloak SOL deposit transaction.",
            "payloadBase64": Data([1, 2, 3]).base64EncodedString(),
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "expiresAt": ISO8601DateFormatter().string(from: expiresAt)
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        return try decoder.decode(CloakBridgeSigningRequest.self, from: data)
    }

    func replacing(
        programID: String? = nil,
        walletPublicKey: String? = nil,
        amountLamports: UInt64? = nil,
        expiresAt: Date? = nil
    ) throws -> CloakBridgeSigningRequest {
        try CloakBridgeSigningRequest.testRequest(
            requestID: requestID ?? UUID(),
            fingerprint: draftFingerprint,
            id: id,
            programID: programID ?? self.programID,
            walletPublicKey: walletPublicKey ?? self.walletPublicKey,
            amountLamports: amountLamports ?? self.amountLamports,
            expiresAt: expiresAt ?? self.expiresAt
        )
    }
}

private func sampleTokenBalance(
    tokenAccount: String = Base58.encode(Data(repeating: 3, count: 32)),
    owner: String = SolanaConstants.systemProgramID,
    mint: String = Base58.encode(Data(repeating: 5, count: 32)),
    amountRaw: UInt64 = 1_000_000,
    decimals: UInt8? = 6,
    programKind: TokenProgramKind = .splToken,
    state: TokenAccountState = .initialized,
    delegateAddress: String? = nil,
    delegatedAmountRaw: UInt64? = nil,
    closeAuthorityAddress: String? = nil
) -> TokenBalance {
    TokenBalance(
        tokenAccountAddress: tokenAccount,
        ownerAddress: owner,
        mintAddress: mint,
        amountRaw: amountRaw,
        decimals: decimals,
        uiAmountString: decimals.map { TokenAmountFormatter.format(rawAmount: amountRaw, decimals: $0) } ?? "\(amountRaw)",
        programKind: programKind,
        state: state,
        delegateAddress: delegateAddress,
        delegatedAmountRaw: delegatedAmountRaw,
        closeAuthorityAddress: closeAuthorityAddress,
        fetchedAt: Date(timeIntervalSince1970: 0)
    )
}

private func sampleStakeAccount(
    profile: WalletProfile,
    stakeAccountAddress: String = Base58.encode(Data(repeating: 10, count: 32)),
    voteAccount: String = Base58.encode(Data(repeating: 11, count: 32)),
    delegatedLamports: UInt64,
    state: StakeAccountState
) -> StakeAccountSummary {
    StakeAccountSummary(
        stakeAccountAddress: stakeAccountAddress,
        walletID: profile.id,
        walletLabel: profile.label,
        walletPublicAddress: profile.publicAddress,
        network: profile.selectedNetwork,
        state: state,
        delegation: StakeDelegationSummary(
            voteAccount: voteAccount,
            delegatedLamports: delegatedLamports,
            activationEpoch: 1,
            deactivationEpoch: state == .deactivating ? 10 : StakeConstants.deactivationEpochNever,
            state: state
        ),
        validator: StakeValidatorSummary(voteAccount: voteAccount, validatorIdentity: nil, name: nil, source: StakeConstants.source),
        rentExemptReserveLamports: 2_282_880,
        stakerAuthorityMatches: true,
        withdrawerAuthorityMatches: false,
        source: StakeConstants.source,
        fetchedAt: Date(timeIntervalSince1970: 0),
        errorMessage: nil
    )
}

private func sampleLendingPosition(
    profile: WalletProfile,
    protocolKind: LendingProtocolKind,
    suppliedUSD: Decimal,
    borrowedUSD: Decimal,
    healthFactor: Decimal?
) -> LendingPositionSummary {
    let supplied = LendingAssetAmount(
        mintAddress: PortfolioConstants.nativeSolMint,
        symbol: "SOL",
        name: "Solana",
        amountRaw: 1_000_000_000,
        decimals: 9,
        uiAmountString: "1",
        usdValue: suppliedUSD,
        priceQuote: nil,
        source: .publicAPI
    )
    let borrowed = LendingAssetAmount(
        mintAddress: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        symbol: "USDC",
        name: "USD Coin",
        amountRaw: UInt64((borrowedUSD as NSDecimalNumber).uint64Value * 1_000_000),
        decimals: 6,
        uiAmountString: "\(borrowedUSD)",
        usdValue: borrowedUSD,
        priceQuote: nil,
        source: .publicAPI
    )
    let health = LendingHealthSummary(
        ltv: nil,
        liquidationThreshold: nil,
        healthFactor: healthFactor,
        riskLevel: LendingHealthSummary.riskLevel(healthFactor: healthFactor, ltv: nil),
        unavailableReason: healthFactor == nil ? "Unavailable in sample." : nil
    )

    return LendingPositionSummary(
        walletID: profile.id,
        walletLabel: profile.label,
        walletPublicAddress: profile.publicAddress,
        network: profile.selectedNetwork,
        protocolKind: protocolKind,
        suppliedAssets: [supplied],
        borrowedAssets: [borrowed],
        netValueUSD: suppliedUSD - borrowedUSD,
        health: health,
        source: .publicAPI,
        updatedAt: Date(timeIntervalSince1970: 0),
        status: .loaded,
        errorMessage: nil
    )
}

private func sampleLPPosition(
    profile: WalletProfile,
    protocolKind: LPProtocolKind,
    estimatedValueUSD: Decimal?,
    status: LPAdapterStatus = .loaded
) -> LPPositionSummary {
    let tokenA = LPPositionAssetAmount(
        mintAddress: PortfolioConstants.nativeSolMint,
        symbol: "wSOL",
        name: "Wrapped SOL",
        amountRaw: nil,
        decimals: 9,
        uiAmountString: "1",
        usdValue: estimatedValueUSD.map { $0 / 2 },
        priceQuote: nil,
        source: .sdkReadOnly
    )
    let tokenB = LPPositionAssetAmount(
        mintAddress: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        symbol: "USDC",
        name: "USD Coin",
        amountRaw: nil,
        decimals: 6,
        uiAmountString: "50",
        usdValue: estimatedValueUSD.map { $0 / 2 },
        priceQuote: nil,
        source: .sdkReadOnly
    )
    return LPPositionSummary(
        walletID: profile.id,
        walletLabel: profile.label,
        walletPublicAddress: profile.publicAddress,
        network: profile.selectedNetwork,
        protocolKind: protocolKind,
        poolAddress: "3oS3RJ8UYrYw7TAQEVh6u6ifrHi35o3DnvqyqGti4Gwa",
        positionAddress: "4N9T5NZ7nVgT5WV5mgWbHcCxgVhM7kUWvQmr6YQb7wNo",
        positionMintAddress: protocolKind == .orca ? "4N9T5NZ7nVgT5WV5mgWbHcCxgVhM7kUWvQmr6YQb7wNo" : nil,
        tokenA: tokenA,
        tokenB: tokenB,
        estimatedValueUSD: estimatedValueUSD,
        feeSummary: .unavailable,
        rangeSummary: LPRangeSummary(
            lowerBinID: 10,
            upperBinID: 20,
            currentBinID: 15,
            state: .inRange,
            unavailableReason: nil
        ),
        impermanentLoss: .unavailable,
        source: .sdkReadOnly,
        updatedAt: Date(timeIntervalSince1970: 0),
        status: status,
        metadataStatus: "Sample read-only LP position.",
        errorMessage: status == .partial ? "Partial sample." : nil
    )
}

private func raydiumStakeFixture() -> Data {
    Data("""
    {
      "success": true,
      "data": [
        {
          "poolId": "3oS3RJ8UYrYw7TAQEVh6u6ifrHi35o3DnvqyqGti4Gwa",
          "positionId": "4N9T5NZ7nVgT5WV5mgWbHcCxgVhM7kUWvQmr6YQb7wNo",
          "lpMint": "7vfCXTUXxAo2DUsmUjtqmnCwZKvcS4XhrGgdVn2SAXYh",
          "lpAmount": "10.5",
          "mintA": "\(PortfolioConstants.nativeSolMint)",
          "mintB": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
          "amountA": "1.25",
          "amountB": "25.00",
          "poolType": "CPMM",
          "rewards": [{"mint": "Es9vMFrzaCERmJfrF4H2FYD4TEtvbkfLsggqK7KQ9x4", "amount": "1"}]
        }
      ]
    }
    """.utf8)
}

private func raydiumCLMMLockFixture() -> Data {
    Data("""
    {
      "success": true,
      "data": {
        "rows": [
          {
            "poolId": "6uYdU3sP7iXaWmFkYzHqH2WH2x3EGa3NGeFk1mXQ7j9p",
            "positionId": "7YttLkHDoqR82kWbfm2Q6VZ1QW9YxijK3ghn93Rr2P7f",
            "lpMint": "Es9vMFrzaCERmJfrF4H2FYD4TEtvbkfLsggqK7KQ9x4",
            "mintA": "\(PortfolioConstants.nativeSolMint)",
            "mintB": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
            "amountA": "0.5",
            "amountB": "10",
            "feeOwedA": "0.01",
            "feeOwedB": "0.25",
            "lockEndTime": 1893456000,
            "poolType": "CLMM"
          }
        ]
      }
    }
    """.utf8)
}

private func raydiumPoolFixture() -> Data {
    Data("""
    {
      "success": true,
      "data": [
        {
          "id": "3oS3RJ8UYrYw7TAQEVh6u6ifrHi35o3DnvqyqGti4Gwa",
          "type": "CPMM",
          "lpMint": "7vfCXTUXxAo2DUsmUjtqmnCwZKvcS4XhrGgdVn2SAXYh",
          "mintA": {"address": "\(PortfolioConstants.nativeSolMint)"},
          "mintB": {"address": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"}
        },
        {
          "id": "6uYdU3sP7iXaWmFkYzHqH2WH2x3EGa3NGeFk1mXQ7j9p",
          "type": "CLMM",
          "lpMint": "Es9vMFrzaCERmJfrF4H2FYD4TEtvbkfLsggqK7KQ9x4",
          "mintA": {"address": "\(PortfolioConstants.nativeSolMint)"},
          "mintB": {"address": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"}
        }
      ]
    }
    """.utf8)
}

private func raydiumMintFixture() -> Data {
    Data("""
    {
      "success": true,
      "data": [
        {"address": "\(PortfolioConstants.nativeSolMint)", "symbol": "wSOL", "name": "Wrapped SOL", "decimals": 9},
        {"address": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v", "symbol": "USDC", "name": "USD Coin", "decimals": 6}
      ]
    }
    """.utf8)
}

private func raydiumPriceFixture() -> Data {
    Data("""
    {
      "success": true,
      "data": {
        "\(PortfolioConstants.nativeSolMint)": "100",
        "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v": "1"
      }
    }
    """.utf8)
}

private func sampleOrcaHarvestPlan(
    wallet: String,
    instructions: [OrcaHarvestInstruction]? = nil,
    signerAccounts: [String]? = nil
) -> OrcaHarvestPlan {
    let planInstructions = instructions ?? [
        OrcaHarvestInstruction(
            programID: OrcaHarvestConstants.whirlpoolProgramID,
            accounts: [
                OrcaHarvestInstructionAccount(address: wallet, isSigner: true, isWritable: true),
                OrcaHarvestInstructionAccount(address: "4N9T5NZ7nVgT5WV5mgWbHcCxgVhM7kUWvQmr6YQb7wNo", isSigner: false, isWritable: true)
            ],
            dataBase64: Data([1, 2, 3]).base64EncodedString()
        )
    ]
    return OrcaHarvestPlan(
        walletPublicAddress: wallet,
        positionMint: "4N9T5NZ7nVgT5WV5mgWbHcCxgVhM7kUWvQmr6YQb7wNo",
        positionAddress: "6uYdU3sP7iXaWmFkYzHqH2WH2x3EGa3NGeFk1mXQ7j9p",
        poolAddress: "3oS3RJ8UYrYw7TAQEVh6u6ifrHi35o3DnvqyqGti4Gwa",
        tokenAMint: PortfolioConstants.nativeSolMint,
        tokenBMint: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        feeOwedA: OrcaHarvestTokenAmount(mintAddress: PortfolioConstants.nativeSolMint, amountRaw: "1", amountUI: nil),
        feeOwedB: nil,
        rewardOwed: [],
        instructionCount: planInstructions.count,
        writableAccountCount: 2,
        signerAccounts: signerAccounts ?? [wallet],
        programIDs: [OrcaHarvestConstants.whirlpoolProgramID],
        instructions: planInstructions,
        source: OrcaHarvestConstants.source,
        expiresAt: Date(timeIntervalSinceNow: 60),
        warning: "test"
    )
}

private func sampleOrcaHarvestDraft(wallet: String, plan: OrcaHarvestPlan) -> OrcaHarvestDraft {
    OrcaHarvestDraft(
        walletID: UUID(uuidString: "00000000-0000-0000-0000-000000000111")!,
        walletPublicAddress: wallet,
        network: .mainnetBeta,
        positionMint: plan.positionMint,
        positionAddress: plan.positionAddress ?? plan.positionMint,
        poolAddress: plan.poolAddress ?? "pool",
        plan: plan,
        createdAt: Date()
    )
}

private func sampleOrcaInstructionProposals(_ instructions: [OrcaHarvestInstruction]) throws -> [SolanaInstructionProposal] {
    try instructions.map { instruction in
        SolanaInstructionProposal(
            programID: instruction.programID,
            accounts: instruction.accounts.map {
                SolanaInstructionAccountMeta(address: $0.address, isSigner: $0.isSigner, isWritable: $0.isWritable)
            },
            data: try #require(Data(base64Encoded: instruction.dataBase64))
        )
    }
}

private struct SampleSwapTransactionFixture {
    let keypair: SolanaKeypair
    let message: Data
    let unsignedTransactionBase64: String
}

private func sampleJupiterQuoteData() -> Data {
    let raw = """
    {
      "inputMint": "\(PortfolioConstants.nativeSolMint)",
      "outputMint": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
      "inAmount": "1000000",
      "outAmount": "142000",
      "otherAmountThreshold": "140000",
      "swapMode": "ExactIn",
      "slippageBps": 50,
      "priceImpactPct": "0.01",
      "contextSlot": 123456,
      "timeTaken": 0.02,
      "routePlan": [
        {
          "percent": 100,
          "bps": 10000,
          "swapInfo": {
            "ammKey": "11111111111111111111111111111111",
            "label": "Test AMM",
            "inputMint": "\(PortfolioConstants.nativeSolMint)",
            "outputMint": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
            "inAmount": "1000000",
            "outAmount": "142000",
            "feeAmount": "10",
            "feeMint": "\(PortfolioConstants.nativeSolMint)"
          }
        }
      ]
    }
    """
    return Data(raw.utf8)
}

private func sampleJupiterQuote(quoteAgeSeconds: TimeInterval = 0) throws -> JupiterQuoteSummary {
    try JupiterQuoteClient.decodeQuote(
        data: sampleJupiterQuoteData(),
        quotedAt: Date().addingTimeInterval(-quoteAgeSeconds)
    )
}

private func sampleSwapTransactionFixture() throws -> SampleSwapTransactionFixture {
    let seed = Data(hex: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")
    let keypair = try SolanaKeypair(seed: seed)
    let blockhash = Base58.encode(Data(repeating: 4, count: 32))
    let draft = TransactionDraft(
        network: .mainnetBeta,
        fromAddress: keypair.publicAddress,
        toAddress: Base58.encode(Data(repeating: 3, count: 32)),
        amountLamports: 42
    )
    let message = try SolanaTransactionBuilder.makeTransferMessage(draft: draft, recentBlockhash: blockhash)
    return SampleSwapTransactionFixture(
        keypair: keypair,
        message: message,
        unsignedTransactionBase64: SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message)
    )
}

private func sampleSwapApprovalContext(
    network: WalletNetwork = .devnet,
    quoteAgeSeconds: TimeInterval = 0,
    simulation: SimulationResult? = SimulationResult(
        status: .success,
        logs: ["ok"],
        estimatedFeeLamports: 5_000,
        errorMessage: nil,
        simulatedAt: Date()
    ),
    mainnetConfirmation: String = "",
    hasCompletedDevnetSmoke: Bool = false,
    preparedFingerprint: String? = nil
) throws -> SwapApprovalContext {
    let quote = try sampleJupiterQuote(quoteAgeSeconds: quoteAgeSeconds)
    let fixture = try sampleSwapTransactionFixture()
    let build = JupiterSwapTransactionBuild(
        quoteID: quote.id,
        userPublicKey: fixture.keypair.publicAddress,
        swapTransactionBase64: fixture.unsignedTransactionBase64,
        lastValidBlockHeight: 123,
        prioritizationFeeLamports: nil,
        computeUnitLimit: nil,
        builtAt: Date(),
        transactionFingerprint: SwapFingerprint.transactionFingerprint(base64: fixture.unsignedTransactionBase64)
    )
    let review = try SwapTransactionReviewer.review(
        serializedTransactionBase64: build.swapTransactionBase64,
        expectedWallet: fixture.keypair.publicAddress
    )
    let fingerprint = SwapFingerprint.approvalFingerprint(quote: quote, build: build)
    return SwapApprovalContext(
        quote: quote,
        build: build,
        review: review,
        simulation: simulation,
        network: network,
        walletPublicKey: fixture.keypair.publicAddress,
        mainnetConfirmation: mainnetConfirmation,
        hasCompletedDevnetSmoke: hasCompletedDevnetSmoke,
        vaultState: .unlocked,
        hasUnlockedSecret: true,
        currentFingerprint: fingerprint,
        preparedFingerprint: preparedFingerprint ?? fingerprint
    )
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

private func makeSyntheticMarginFiAccount(
    authority: String,
    suppliedBank: String,
    borrowedBank: String
) throws -> SolanaProgramAccountData {
    guard let groupBytes = SolanaAddressValidator.decodeAddress(MarginFiConstants.mainGroupID),
          let authorityBytes = SolanaAddressValidator.decodeAddress(authority),
          let suppliedBankBytes = SolanaAddressValidator.decodeAddress(suppliedBank),
          let borrowedBankBytes = SolanaAddressValidator.decodeAddress(borrowedBank) else {
        throw SolanaValidationError.invalidAddress("Synthetic MarginFi fixture address is invalid.")
    }

    var bytes = [UInt8](repeating: 0, count: MarginFiAccountLayout.accountDataSize)
    replace(&bytes, at: 0, with: MarginFiAccountLayout.accountDiscriminator)
    replace(&bytes, at: MarginFiAccountLayout.groupOffset, with: Array(groupBytes))
    replace(&bytes, at: MarginFiAccountLayout.authorityOffset, with: Array(authorityBytes))
    writeBalance(
        bytes: &bytes,
        slot: 0,
        bank: Array(suppliedBankBytes),
        side: .supplied,
        lastUpdate: 1_714_000_000
    )
    writeBalance(
        bytes: &bytes,
        slot: 1,
        bank: Array(borrowedBankBytes),
        side: .borrowed,
        lastUpdate: 1_714_000_001
    )

    return SolanaProgramAccountData(
        publicKey: "EN1WSBJmZR1NVdYvPbpwzPnRk7JhbNncS1kNEXqvK7ND",
        owner: MarginFiConstants.programID,
        data: Data(bytes),
        space: MarginFiAccountLayout.accountDataSize
    )
}

private enum SyntheticMarginFiBalanceSide {
    case supplied
    case borrowed
}

private func writeBalance(
    bytes: inout [UInt8],
    slot: Int,
    bank: [UInt8],
    side: SyntheticMarginFiBalanceSide,
    lastUpdate: UInt64
) {
    let offset = MarginFiAccountLayout.lendingAccountOffset + (slot * MarginFiAccountLayout.balanceSlotSize)
    bytes[offset + MarginFiAccountLayout.BalanceOffset.active] = 1
    replace(&bytes, at: offset + MarginFiAccountLayout.BalanceOffset.bank, with: bank)
    bytes[offset + MarginFiAccountLayout.BalanceOffset.bankAssetTag] = 0
    replace(&bytes, at: offset + MarginFiAccountLayout.BalanceOffset.tag, with: [UInt8(slot + 1), 0])
    switch side {
    case .supplied:
        bytes[offset + MarginFiAccountLayout.BalanceOffset.assetShares] = 1
    case .borrowed:
        bytes[offset + MarginFiAccountLayout.BalanceOffset.liabilityShares] = 1
    }
    replace(&bytes, at: offset + MarginFiAccountLayout.BalanceOffset.lastUpdate, with: littleEndianBytes(lastUpdate))
}

private func replace(_ bytes: inout [UInt8], at offset: Int, with replacement: [UInt8]) {
    bytes.replaceSubrange(offset..<(offset + replacement.count), with: replacement)
}

private func littleEndianBytes(_ value: UInt64) -> [UInt8] {
    (0..<8).map { UInt8((value >> ($0 * 8)) & 0xff) }
}

private func sourceText(relativePath: String) throws -> String {
    let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let projectDirectory = testsDirectory.deletingLastPathComponent()
    return try String(contentsOf: projectDirectory.appendingPathComponent(relativePath), encoding: .utf8)
}

private struct MockAgentHTTPTransport: AgentHTTPTransport {
    let payload: String
    var statusCode: Int = 200

    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://agent.gorkh.example/v1/agent/chat")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (Data(payload.utf8), response)
    }
}

private func sampleAgentLLMRequest(message: String) throws -> AgentLLMChatRequest {
    let demoPublicAddress = "11111111111111111111111111111111"
    let classification = AgentIntentClassifier().classify(message)
    let context = try AgentRedactedContextBuilder.build(
        portfolioSummary: .empty(),
        pnlSummary: .empty(),
        pusdCirculationSnapshot: .idle(),
        auditEvents: [],
        selectedProfile: WalletProfile(label: "Demo", publicAddress: demoPublicAddress, walletOrigin: .watchOnly),
        selectedNetwork: .mainnetBeta,
        rpcSecurityStatus: RPCProviderSecurityStatus(
            provider: .rpcFast,
            network: .mainnetBeta,
            tokenStatus: .missing,
            tokenEnvironmentNames: [RPCFastConfiguration.mainnetTokenEnvironmentName],
            beamStatus: "locked"
        ),
        zerionStatus: .unchecked,
        builtAt: Date(timeIntervalSince1970: 0)
    )
    let redacted = try AgentRedactedContextBuilder.redactedUserMessageForAI(message)
    return AgentLLMChatRequest(
        conversationID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        userMessage: redacted.message,
        deterministicIntent: classification,
        redactedContext: context,
        enabledLocalTools: AgentToolBoundary.enabledLocalTools,
        policyState: .current,
        safetyMode: "test"
    )
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
