import CryptoKit
import Darwin
import Foundation

@main
enum LiveDevnetSplSmoke {
    private static let stateDirectoryName = ".gorkh-devnet-smoke"
    private static let stateFileName = "manual-funding-state.json"
    private static let smokeAmountRaw: UInt64 = 1

    static func main() async {
        do {
            switch try SmokeMode(arguments: CommandLine.arguments) {
            case .run(let mintFilter):
                let result = try await run(mintFilter: mintFilter)
                try printResult(result)
            case .prepareTokenBalance:
                let setup = try prepareTokenBalance()
                try printTokenSetup(setup)
            case .help:
                printHelp()
            }
        } catch {
            fputs("Live devnet SPL smoke failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run(mintFilter: String?) async throws -> LiveDevnetSplSmokeResult {
        if let mintFilter, !SolanaAddressValidator.isValidAddress(mintFilter) {
            throw LiveDevnetSplSmokeError.invalidArgument("Mint filter is not a valid Solana address.")
        }

        let state = try loadManualFundingState()
        guard state.network == WalletNetwork.devnet.rawValue else {
            throw LiveDevnetSplSmokeError.invalidState("Manual funding state is not marked devnet.")
        }
        guard let localSigningMaterial = Data(base64Encoded: state.localSigningMaterialBase64) else {
            throw LiveDevnetSplSmokeError.invalidState("Manual funding state cannot be decoded.")
        }

        let sender = try SolanaKeypair(seed: localSigningMaterial)
        guard sender.publicAddress == state.senderPublicAddress else {
            throw LiveDevnetSplSmokeError.invalidState("Manual funding state public address does not match local signing material.")
        }

        let rpcClient = SolanaRPCClient()
        fputs("Devnet sender: \(sender.publicAddress)\n", stderr)
        fputs("Fetching devnet SPL token balances...\n", stderr)

        let balances = try await rpcClient.getTokenBalances(ownerAddress: sender.publicAddress, network: .devnet)
        let candidates = balances
            .filter { $0.canSend }
            .filter { mintFilter == nil || $0.mintAddress == mintFilter }
            .sorted {
                if $0.mintAddress == $1.mintAddress {
                    return $0.tokenAccountAddress < $1.tokenAccountAddress
                }
                return $0.mintAddress < $1.mintAddress
            }

        guard let token = candidates.first else {
            throw LiveDevnetSplSmokeError.missingTokenBalance(
                """
                No initialized devnet SPL Token balance with a positive amount was found for \(sender.publicAddress).
                Fund this throwaway devnet wallet with a small SPL Token balance, then rerun:
                scripts/live-devnet-spl-smoke.sh\(mintFilter.map { " --mint \($0)" } ?? "")
                """
            )
        }

        guard token.amountRaw >= smokeAmountRaw else {
            throw LiveDevnetSplSmokeError.missingTokenBalance("Selected token balance is below one raw token unit.")
        }

        let recipient = try SolanaKeypair.generate()
        let recipientAccounts = try await rpcClient.getTokenAccounts(
            ownerAddress: recipient.publicAddress,
            mintAddress: token.mintAddress,
            programKind: .splToken,
            network: .devnet
        )
        let existingRecipientTokenAccount = recipientAccounts.first { $0.state == .initialized }?.tokenAccountAddress
        let rent = try? await rpcClient.getMinimumBalanceForRentExemption(byteCount: 165, network: .devnet)
        let ataPlan: AssociatedTokenAccountPlan

        if let existingRecipientTokenAccount {
            ataPlan = AssociatedTokenAccount.existingPlan(
                recipientOwner: recipient.publicAddress,
                mint: token.mintAddress,
                tokenProgramKind: .splToken,
                recipientTokenAccount: existingRecipientTokenAccount,
                rentExemptLamports: rent
            )
        } else {
            ataPlan = AssociatedTokenAccount.missingPlan(
                recipientOwner: recipient.publicAddress,
                mint: token.mintAddress,
                tokenProgramKind: .splToken,
                rentExemptLamports: rent
            )
        }

        guard ataPlan.creationSupported, let destinationTokenAccount = ataPlan.associatedTokenAddress else {
            throw LiveDevnetSplSmokeError.transactionFailed(ataPlan.message)
        }

        let amountText = TokenAmountFormatter.format(rawAmount: smokeAmountRaw, decimals: token.decimals)
        let draft = TokenTransferDraft(
            network: .devnet,
            ownerAddress: sender.publicAddress,
            sourceTokenAccount: token.tokenAccountAddress,
            mintAddress: token.mintAddress,
            tokenProgramKind: .splToken,
            recipientOwnerAddress: recipient.publicAddress,
            recipientTokenAccount: destinationTokenAccount,
            amountRaw: smokeAmountRaw,
            amountText: amountText,
            decimals: token.decimals,
            availableAmountRaw: token.amountRaw,
            ataPlan: ataPlan
        )

        fputs("Selected mint: \(token.mintAddress)\n", stderr)
        fputs("Source token account: \(token.tokenAccountAddress)\n", stderr)
        fputs("Recipient owner: \(recipient.publicAddress)\n", stderr)
        fputs("Recipient ATA: \(destinationTokenAccount)\n", stderr)
        fputs("ATA creation included: \(ataPlan.shouldCreateAssociatedTokenAccount)\n", stderr)
        fputs("Building and simulating SPL transfer...\n", stderr)

        let blockhash = try await rpcClient.getLatestBlockhash(network: .devnet)
        let message = try SplTokenInstructionBuilder.makeTransferCheckedMessage(
            draft: draft,
            recentBlockhash: blockhash
        )
        let messageBase64 = SolanaTransactionBuilder.makeMessageBase64(message: message)
        let estimatedFee = try await rpcClient.getFeeForMessage(messageBase64: messageBase64, network: .devnet)
        let unsignedTransaction = SolanaTransactionBuilder.makeUnsignedTransactionBase64(message: message)
        let simulation = try await rpcClient.simulateTransaction(transactionBase64: unsignedTransaction, network: .devnet)

        guard simulation.status == .success else {
            throw LiveDevnetSplSmokeError.transactionFailed(simulation.errorMessage ?? "SPL token simulation failed.")
        }

        fputs("Simulation succeeded.\n", stderr)
        fputs("Signing locally and sending devnet SPL transfer...\n", stderr)
        let signedTransaction = try SolanaTransactionBuilder.makeSignedTransactionBase64(
            message: message,
            seed: sender.seed
        )
        try verifySignedTransaction(signedTransaction, message: message, sender: sender)

        let transactionSignature = try await rpcClient.sendTransaction(
            transactionBase64: signedTransaction,
            network: .devnet
        )
        fputs("SPL transfer signature: \(transactionSignature)\n", stderr)
        fputs("Waiting for transfer confirmation...\n", stderr)
        let transactionStatus = try await waitForSignatureConfirmation(
            signature: transactionSignature,
            rpcClient: rpcClient,
            network: .devnet,
            timeoutSeconds: 90
        )

        fputs("Verifying recipient token balance and audit-safe event...\n", stderr)
        let endingRecipientRaw = try await waitForRecipientTokenBalance(
            owner: recipient.publicAddress,
            mint: token.mintAddress,
            minimumRawAmount: smokeAmountRaw,
            rpcClient: rpcClient,
            timeoutSeconds: 45
        )

        try verifyAuditEventContainsNoSecret(
            sender: sender,
            recipientOwner: recipient.publicAddress,
            destinationTokenAccount: destinationTokenAccount,
            token: token,
            transactionSignature: transactionSignature,
            createsAssociatedTokenAccount: ataPlan.shouldCreateAssociatedTokenAccount,
            estimatedFee: estimatedFee
        )

        return LiveDevnetSplSmokeResult(
            senderAddress: sender.publicAddress,
            sourceTokenAccount: token.tokenAccountAddress,
            mintAddress: token.mintAddress,
            recipientOwnerAddress: recipient.publicAddress,
            recipientTokenAccount: destinationTokenAccount,
            createdAssociatedTokenAccount: ataPlan.shouldCreateAssociatedTokenAccount,
            transferAmountRaw: smokeAmountRaw,
            transferAmountText: amountText,
            transactionSignature: transactionSignature,
            explorerURL: "https://explorer.solana.com/tx/\(transactionSignature)?cluster=devnet",
            estimatedFeeLamports: estimatedFee,
            confirmationStatus: transactionStatus.confirmationStatus ?? "unknown",
            endingRecipientAmountRaw: endingRecipientRaw
        )
    }

    private static func prepareTokenBalance() throws -> DevnetSplTokenSetupResult {
        let state = try loadManualFundingState()
        guard state.network == WalletNetwork.devnet.rawValue else {
            throw LiveDevnetSplSmokeError.invalidState("Manual funding state is not marked devnet.")
        }
        guard let localSigningMaterial = Data(base64Encoded: state.localSigningMaterialBase64) else {
            throw LiveDevnetSplSmokeError.invalidState("Manual funding state cannot be decoded.")
        }

        let sender = try SolanaKeypair(seed: localSigningMaterial)
        guard sender.publicAddress == state.senderPublicAddress else {
            throw LiveDevnetSplSmokeError.invalidState("Manual funding state public address does not match local signing material.")
        }

        try FileManager.default.createDirectory(at: stateDirectoryURL, withIntermediateDirectories: true)
        let senderKeypairURL = stateDirectoryURL.appendingPathComponent("spl-smoke-sender-keypair.json")
        let mintKeypairURL = stateDirectoryURL.appendingPathComponent("spl-smoke-mint-keypair.json")

        try writeCLIKeypair(sender, to: senderKeypairURL)
        _ = try runProcess("solana-keygen", arguments: [
            "new",
            "--no-bip39-passphrase",
            "--silent",
            "--force",
            "--outfile",
            mintKeypairURL.path
        ])
        let mintAddress = try runProcess("solana-keygen", arguments: [
            "pubkey",
            mintKeypairURL.path
        ]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard SolanaAddressValidator.isValidAddress(mintAddress) else {
            throw LiveDevnetSplSmokeError.transactionFailed("Generated mint address is invalid.")
        }

        _ = try runProcess("spl-token", arguments: [
            "create-token",
            "--url",
            WalletNetwork.devnet.rpcURL.absoluteString,
            "--fee-payer",
            senderKeypairURL.path,
            "--mint-authority",
            sender.publicAddress,
            "--decimals",
            "6",
            mintKeypairURL.path
        ])

        let senderTokenAccount = try AssociatedTokenAccount.deriveAddress(
            owner: sender.publicAddress,
            mint: mintAddress,
            tokenProgramKind: .splToken
        ).base58Address

        _ = try runProcess("spl-token", arguments: [
            "create-account",
            "--url",
            WalletNetwork.devnet.rpcURL.absoluteString,
            "--fee-payer",
            senderKeypairURL.path,
            "--owner",
            sender.publicAddress,
            mintAddress
        ])

        _ = try runProcess("spl-token", arguments: [
            "mint",
            "--url",
            WalletNetwork.devnet.rpcURL.absoluteString,
            "--fee-payer",
            senderKeypairURL.path,
            "--mint-authority",
            senderKeypairURL.path,
            mintAddress,
            "10",
            senderTokenAccount
        ])

        let result = DevnetSplTokenSetupResult(
            senderAddress: sender.publicAddress,
            mintAddress: mintAddress,
            senderTokenAccount: senderTokenAccount,
            tokenAmountText: "10",
            nextCommand: "scripts/live-devnet-spl-smoke.sh --mint \(mintAddress)",
            temporaryKeypairDirectory: stateDirectoryURL.path
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        try data.write(to: stateDirectoryURL.appendingPathComponent("spl-smoke-token-setup.json"), options: .atomic)
        return result
    }

    private static func writeCLIKeypair(_ keypair: SolanaKeypair, to url: URL) throws {
        let keypairBytes = Array(keypair.seed + keypair.publicKey)
        let data = try JSONSerialization.data(withJSONObject: keypairBytes, options: [.prettyPrinted])
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: url.path
        )
    }

    private static func verifySignedTransaction(
        _ transactionBase64: String,
        message: Data,
        sender: SolanaKeypair
    ) throws {
        guard let signedBytes = Data(base64Encoded: transactionBase64), signedBytes.count > 65 else {
            throw LiveDevnetSplSmokeError.invalidSignedTransaction
        }

        let signature = Data(signedBytes[1..<65])
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: sender.publicKey)
        guard signature.count == 64, publicKey.isValidSignature(signature, for: message) else {
            throw LiveDevnetSplSmokeError.invalidSignature
        }
        guard Data(signedBytes[65...]) == message else {
            throw LiveDevnetSplSmokeError.invalidSignedTransaction
        }
    }

    private static func waitForSignatureConfirmation(
        signature: String,
        rpcClient: SolanaRPCClient,
        network: WalletNetwork,
        timeoutSeconds: Int
    ) async throws -> SolanaSignatureStatus {
        for _ in 0..<timeoutSeconds {
            if let status = try await rpcClient.getSignatureStatusInfo(signature: signature, network: network) {
                if let errorDescription = status.errorDescription {
                    throw LiveDevnetSplSmokeError.transactionFailed(errorDescription)
                }
                if status.isConfirmedOrFinalized {
                    return status
                }
            }

            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        throw LiveDevnetSplSmokeError.timedOut("Timed out waiting for devnet signature confirmation.")
    }

    private static func waitForRecipientTokenBalance(
        owner: String,
        mint: String,
        minimumRawAmount: UInt64,
        rpcClient: SolanaRPCClient,
        timeoutSeconds: Int
    ) async throws -> UInt64 {
        for _ in 0..<timeoutSeconds {
            let balances = try await rpcClient.getTokenAccounts(
                ownerAddress: owner,
                mintAddress: mint,
                programKind: .splToken,
                network: .devnet
            )
            let total = balances.reduce(UInt64(0)) { partial, balance in
                partial + balance.amountRaw
            }
            if total >= minimumRawAmount {
                return total
            }

            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        throw LiveDevnetSplSmokeError.timedOut("Timed out waiting for recipient token balance.")
    }

    private static func verifyAuditEventContainsNoSecret(
        sender: SolanaKeypair,
        recipientOwner: String,
        destinationTokenAccount: String,
        token: TokenBalance,
        transactionSignature: String,
        createsAssociatedTokenAccount: Bool,
        estimatedFee: UInt64?
    ) throws {
        let auditURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gorkh-live-devnet-spl-smoke-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: auditURL) }

        let auditLog = AuditLog(fileURL: auditURL)
        auditLog.record(AuditEvent(
            kind: .tokenTransferSent,
            walletID: UUID(),
            network: .devnet,
            publicAddress: sender.publicAddress,
            transactionSignature: transactionSignature,
            message: "Live devnet SPL smoke token transfer sent.",
            details: [
                "mint": token.mintAddress,
                "sourceTokenAccount": token.tokenAccountAddress,
                "recipientOwner": recipientOwner,
                "recipientTokenAccount": destinationTokenAccount,
                "amountRaw": "\(smokeAmountRaw)",
                "decimals": "\(token.decimals)",
                "createsAssociatedTokenAccount": "\(createsAssociatedTokenAccount)",
                "estimatedFeeLamports": estimatedFee.map(String.init) ?? "unknown"
            ]
        ))

        let auditText = try String(contentsOf: auditURL, encoding: .utf8)
        guard !auditText.contains(sender.seed.hexString),
              !auditText.contains(Base58.encode(sender.seed)),
              !auditText.lowercased().contains("private"),
              !auditText.lowercased().contains("mnemonic") else {
            throw LiveDevnetSplSmokeError.auditLeakage
        }
    }

    private static func loadManualFundingState() throws -> ManualFundingState {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            throw LiveDevnetSplSmokeError.missingState
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try Data(contentsOf: stateFileURL)
        return try decoder.decode(ManualFundingState.self, from: data)
    }

    private static func printResult(_ result: LiveDevnetSplSmokeResult) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func printTokenSetup(_ result: DevnetSplTokenSetupResult) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func runProcess(_ executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputText = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw LiveDevnetSplSmokeError.transactionFailed(errorText.isEmpty ? outputText : errorText)
        }
        return outputText
    }

    private static func printHelp() {
        print("""
        Usage:
          scripts/live-devnet-spl-smoke.sh
          scripts/live-devnet-spl-smoke.sh --prepare-token-balance
          scripts/live-devnet-spl-smoke.sh --mint <SPL_TOKEN_MINT>
          scripts/live-devnet-spl-smoke.sh --help

        This devnet-only smoke uses the throwaway wallet state from:
          .gorkh-devnet-smoke/manual-funding-state.json

        Setup:
          1. Run scripts/live-devnet-wallet-smoke.sh --prepare-manual-funding if the state is missing.
          2. Fund the printed devnet address with SOL for fees.
          3. Either send a small devnet SPL Token balance to the same wallet, or run --prepare-token-balance to create a temporary devnet SPL mint using local CLI tooling.
          4. Run this script. It creates a fresh recipient owner, includes ATA creation when missing, simulates, signs locally, sends, and confirms.

        No mainnet transaction is run. Signing material is never printed.
        """)
    }

    private static var stateDirectoryURL: URL {
        let rootPath = ProcessInfo.processInfo.environment["GORKH_REPO_ROOT"]
            ?? FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: rootPath)
            .appendingPathComponent(stateDirectoryName, isDirectory: true)
    }

    private static var stateFileURL: URL {
        stateDirectoryURL.appendingPathComponent(stateFileName)
    }
}

private enum SmokeMode {
    case run(mintFilter: String?)
    case prepareTokenBalance
    case help

    init(arguments: [String]) throws {
        var mintFilter: String?
        var iterator = arguments.dropFirst().makeIterator()

        while let argument = iterator.next() {
            switch argument {
            case "--help", "-h":
                self = .help
                return
            case "--prepare-token-balance":
                self = .prepareTokenBalance
                return
            case "--mint":
                guard let mint = iterator.next() else {
                    throw LiveDevnetSplSmokeError.invalidArgument("--mint requires a mint address.")
                }
                mintFilter = mint
            default:
                throw LiveDevnetSplSmokeError.invalidArgument("Unknown argument '\(argument)'. Use --help.")
            }
        }

        self = .run(mintFilter: mintFilter)
    }
}

private struct ManualFundingState: Codable {
    let version: Int
    let network: String
    let createdAt: Date
    let senderPublicAddress: String
    let localSigningMaterialBase64: String
    let warning: String
}

private struct LiveDevnetSplSmokeResult: Codable {
    let senderAddress: String
    let sourceTokenAccount: String
    let mintAddress: String
    let recipientOwnerAddress: String
    let recipientTokenAccount: String
    let createdAssociatedTokenAccount: Bool
    let transferAmountRaw: UInt64
    let transferAmountText: String
    let transactionSignature: String
    let explorerURL: String
    let estimatedFeeLamports: UInt64?
    let confirmationStatus: String
    let endingRecipientAmountRaw: UInt64
}

private struct DevnetSplTokenSetupResult: Codable {
    let senderAddress: String
    let mintAddress: String
    let senderTokenAccount: String
    let tokenAmountText: String
    let nextCommand: String
    let temporaryKeypairDirectory: String
}

private enum LiveDevnetSplSmokeError: LocalizedError {
    case invalidArgument(String)
    case invalidSignature
    case invalidSignedTransaction
    case missingState
    case missingTokenBalance(String)
    case invalidState(String)
    case auditLeakage
    case transactionFailed(String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .invalidArgument(let message):
            return message
        case .invalidSignature:
            return "The locally produced signature did not verify against the generated public key."
        case .invalidSignedTransaction:
            return "The signed transaction did not contain the expected signature/message layout."
        case .missingState:
            return "Manual funding state is missing. Run scripts/live-devnet-wallet-smoke.sh --prepare-manual-funding first."
        case .missingTokenBalance(let message):
            return message
        case .invalidState(let message):
            return message
        case .auditLeakage:
            return "The safe audit event contained sensitive material."
        case .transactionFailed(let message):
            return "Devnet SPL transaction failed: \(message)"
        case .timedOut(let message):
            return message
        }
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
