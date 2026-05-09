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
