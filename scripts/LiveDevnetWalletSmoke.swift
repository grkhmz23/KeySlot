import CryptoKit
import Darwin
import Foundation

@main
enum LiveDevnetWalletSmoke {
    private static let transferLamports: UInt64 = 1_000_000
    private static let minimumFundingLamports: UInt64 = 2_000_000
    private static let automaticAirdropLamports: UInt64 = 2_000_000
    private static let stateDirectoryName = ".gorkh-devnet-smoke"
    private static let stateFileName = "manual-funding-state.json"

    static func main() async {
        do {
            switch try SmokeMode(arguments: CommandLine.arguments) {
            case .automaticAirdrop:
                let result = try await runAutomaticAirdrop()
                try printResult(result)
            case .prepareManualFunding:
                try prepareManualFunding()
            case .resumeManualFunding:
                let result = try await resumeManualFunding()
                try printResult(result)
            case .cleanup:
                try cleanupManualFundingState()
            case .help:
                printHelp()
            }
        } catch {
            fputs("Live devnet wallet smoke failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func runAutomaticAirdrop() async throws -> LiveDevnetSmokeResult {
        let rpcClient = SolanaRPCClient()
        let sender = try generateBip39SmokeKeypair()
        let recipient = try SolanaKeypair.generate()

        fputs("Generated BIP39-derived throwaway sender: \(sender.publicAddress)\n", stderr)
        fputs("Generated throwaway recipient: \(recipient.publicAddress)\n", stderr)
        fputs("Requesting devnet airdrop...\n", stderr)
        let airdropSignature = try await requestAirdropWithRetry(
            address: sender.publicAddress,
            lamports: automaticAirdropLamports,
            rpcClient: rpcClient,
            attempts: 5
        )
        fputs("Airdrop signature: \(airdropSignature)\n", stderr)
        fputs("Waiting for airdrop confirmation...\n", stderr)
        _ = try await waitForSignatureConfirmation(
            signature: airdropSignature,
            rpcClient: rpcClient,
            network: .devnet,
            timeoutSeconds: 60
        )

        return try await runTransfer(
            sender: sender,
            recipient: recipient,
            rpcClient: rpcClient,
            fundingSource: "devnet_rpc_airdrop",
            airdropSignature: airdropSignature
        )
    }

    private static func prepareManualFunding() throws {
        let sender = try generateBip39SmokeKeypair()
        let state = ManualFundingState(
            version: 1,
            network: WalletNetwork.devnet.rawValue,
            createdAt: Date(),
            senderPublicAddress: sender.publicAddress,
            localSigningMaterialBase64: sender.seed.base64EncodedString(),
            warning: "Throwaway devnet-only BIP39-derived smoke seed. Never use for real funds. This file must stay gitignored."
        )

        try FileManager.default.createDirectory(
            at: stateDirectoryURL,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)

        guard FileManager.default.createFile(
            atPath: stateFileURL.path,
            contents: data,
            attributes: [.posixPermissions: NSNumber(value: Int16(0o600))]
        ) || FileManager.default.fileExists(atPath: stateFileURL.path) else {
            throw LiveDevnetSmokeError.stateWriteFailed
        }
        try data.write(to: stateFileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: stateFileURL.path
        )

        print("""
        GORKH manual-funding devnet smoke prepared.

        DEVNET-ONLY throwaway address to fund:
        \(sender.publicAddress)

        Required minimum funding:
        \(solText(minimumFundingLamports)) devnet SOL

        Next command after funding:
        scripts/live-devnet-wallet-smoke.sh --resume-manual-funding

        Cleanup command:
        scripts/live-devnet-wallet-smoke.sh --cleanup

        Local temporary state:
        \(stateFileURL.path)

        Warning:
        This is devnet-only. The temporary signing material is stored locally under \(stateDirectoryName)/, which is gitignored. Do not use this address for real funds.
        """)
    }

    private static func generateBip39SmokeKeypair() throws -> SolanaKeypair {
        let words = try Bip39MnemonicService.shared.generate(wordCount: 12)
        // The phrase is never printed or stored; only the derived throwaway seed
        // is kept for manual resume under the gitignored smoke directory.
        return try SolanaDerivationService().deriveKeypair(
            mnemonic: words.joined(separator: " "),
            path: .defaultSolana
        )
    }

    private static func resumeManualFunding() async throws -> LiveDevnetSmokeResult {
        let state = try loadManualFundingState()
        guard state.network == WalletNetwork.devnet.rawValue else {
            throw LiveDevnetSmokeError.invalidState("Manual funding state is not marked devnet.")
        }
        guard let localSigningMaterial = Data(base64Encoded: state.localSigningMaterialBase64) else {
            throw LiveDevnetSmokeError.invalidState("Manual funding state cannot be decoded.")
        }

        let sender = try SolanaKeypair(seed: localSigningMaterial)
        guard sender.publicAddress == state.senderPublicAddress else {
            throw LiveDevnetSmokeError.invalidState("Manual funding state public address does not match local signing material.")
        }

        let rpcClient = SolanaRPCClient()
        let recipient = try SolanaKeypair.generate()

        fputs("Resuming manual-funding smoke for devnet sender: \(sender.publicAddress)\n", stderr)
        fputs("Generated throwaway recipient: \(recipient.publicAddress)\n", stderr)
        fputs("Waiting for minimum funded balance: \(solText(minimumFundingLamports)) devnet SOL\n", stderr)

        return try await runTransfer(
            sender: sender,
            recipient: recipient,
            rpcClient: rpcClient,
            fundingSource: "manual_external_devnet_funding",
            airdropSignature: nil
        )
    }

    private static func runTransfer(
        sender: SolanaKeypair,
        recipient: SolanaKeypair,
        rpcClient: SolanaRPCClient,
        fundingSource: String,
        airdropSignature: String?
    ) async throws -> LiveDevnetSmokeResult {
        fputs("Waiting for funded sender balance...\n", stderr)
        let startingBalance = try await waitForMinimumBalance(
            address: sender.publicAddress,
            minimumLamports: minimumFundingLamports,
            rpcClient: rpcClient,
            network: .devnet,
            timeoutSeconds: 300
        )

        fputs("Building and simulating transfer...\n", stderr)
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

        guard simulation.status == .success else {
            throw LiveDevnetSmokeError.transactionFailed(simulation.errorMessage ?? "Simulation failed.")
        }

        fputs("Simulation succeeded.\n", stderr)
        fputs("Signing locally and sending devnet transfer...\n", stderr)
        let signedTransaction = try SolanaTransactionBuilder.makeSignedTransactionBase64(
            message: message,
            seed: sender.seed
        )
        guard let signedBytes = Data(base64Encoded: signedTransaction), signedBytes.count > 65 else {
            throw LiveDevnetSmokeError.invalidSignedTransaction
        }

        let signature = Data(signedBytes[1..<65])
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: sender.publicKey)
        guard signature.count == 64, publicKey.isValidSignature(signature, for: message) else {
            throw LiveDevnetSmokeError.invalidSignature
        }
        guard Data(signedBytes[65...]) == message else {
            throw LiveDevnetSmokeError.invalidSignedTransaction
        }

        let transactionSignature = try await rpcClient.sendTransaction(
            transactionBase64: signedTransaction,
            network: .devnet
        )
        fputs("Transfer signature: \(transactionSignature)\n", stderr)
        fputs("Waiting for transfer confirmation...\n", stderr)
        let transactionStatus = try await waitForSignatureConfirmation(
            signature: transactionSignature,
            rpcClient: rpcClient,
            network: .devnet,
            timeoutSeconds: 90
        )

        fputs("Verifying final balances and audit-safe event...\n", stderr)
        let endingSenderBalance = try await rpcClient.getBalance(address: sender.publicAddress, network: .devnet)
        let endingRecipientBalance = try await waitForMinimumBalance(
            address: recipient.publicAddress,
            minimumLamports: transferLamports,
            rpcClient: rpcClient,
            network: .devnet,
            timeoutSeconds: 30
        )

        guard endingRecipientBalance >= transferLamports else {
            throw LiveDevnetSmokeError.transactionFailed("Recipient balance did not receive transferred lamports.")
        }

        try verifyAuditEventContainsNoSecret(
            sender: sender,
            recipient: recipient,
            transactionSignature: transactionSignature,
            transferLamports: transferLamports,
            estimatedFee: estimatedFee
        )

        return LiveDevnetSmokeResult(
            mode: fundingSource,
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
    }

    private static func requestAirdropWithRetry(
        address: String,
        lamports: UInt64,
        rpcClient: SolanaRPCClient,
        attempts: Int
    ) async throws -> String {
        var lastError: Error?

        for attempt in 1...attempts {
            do {
                return try await rpcClient.requestAirdrop(
                    address: address,
                    lamports: lamports,
                    network: .devnet
                )
            } catch {
                lastError = error
                fputs("Airdrop attempt \(attempt) failed: \(error.localizedDescription)\n", stderr)
                if attempt < attempts {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }

        throw lastError ?? LiveDevnetSmokeError.transactionFailed("Airdrop failed.")
    }

    private static func verifyAuditEventContainsNoSecret(
        sender: SolanaKeypair,
        recipient: SolanaKeypair,
        transactionSignature: String,
        transferLamports: UInt64,
        estimatedFee: UInt64?
    ) throws {
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
        guard !auditText.contains(sender.seed.hexString),
              !auditText.contains(Base58.encode(sender.seed)),
              !auditText.lowercased().contains("private"),
              !auditText.lowercased().contains("mnemonic") else {
            throw LiveDevnetSmokeError.auditLeakage
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

    private static func waitForMinimumBalance(
        address: String,
        minimumLamports: UInt64,
        rpcClient: SolanaRPCClient,
        network: WalletNetwork,
        timeoutSeconds: Int
    ) async throws -> UInt64 {
        for second in 0..<timeoutSeconds {
            let balance = try await rpcClient.getBalance(address: address, network: network)
            if balance >= minimumLamports {
                fputs("Current devnet balance: \(solText(balance)) SOL\n", stderr)
                return balance
            }

            if second % 10 == 0 {
                fputs("Current devnet balance: \(solText(balance)) SOL; waiting for \(solText(minimumLamports)) SOL...\n", stderr)
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        throw LiveDevnetSmokeError.timedOut("Timed out waiting for devnet balance.")
    }

    private static func loadManualFundingState() throws -> ManualFundingState {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            throw LiveDevnetSmokeError.missingState
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try Data(contentsOf: stateFileURL)
        return try decoder.decode(ManualFundingState.self, from: data)
    }

    private static func cleanupManualFundingState() throws {
        if FileManager.default.fileExists(atPath: stateDirectoryURL.path) {
            try FileManager.default.removeItem(at: stateDirectoryURL)
        }
        print("Removed \(stateDirectoryURL.path)")
    }

    private static func printResult(_ result: LiveDevnetSmokeResult) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func printHelp() {
        print("""
        Usage:
          scripts/live-devnet-wallet-smoke.sh
          scripts/live-devnet-wallet-smoke.sh --prepare-manual-funding
          scripts/live-devnet-wallet-smoke.sh --resume-manual-funding
          scripts/live-devnet-wallet-smoke.sh --cleanup
          scripts/live-devnet-wallet-smoke.sh --help

        Default mode tries devnet RPC airdrop first.
        Manual mode is devnet-only and stores throwaway local signing material under \(stateDirectoryName)/.
        """)
    }

    private static func solText(_ lamports: UInt64) -> String {
        let sol = Decimal(lamports) / Decimal(SolanaConstants.lamportsPerSol)
        return "\(sol)"
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
    case automaticAirdrop
    case prepareManualFunding
    case resumeManualFunding
    case cleanup
    case help

    init(arguments: [String]) throws {
        let mode = arguments.dropFirst().first ?? ""
        switch mode {
        case "":
            self = .automaticAirdrop
        case "--prepare-manual-funding":
            self = .prepareManualFunding
        case "--resume-manual-funding":
            self = .resumeManualFunding
        case "--cleanup":
            self = .cleanup
        case "--help", "-h":
            self = .help
        default:
            throw LiveDevnetSmokeError.invalidMode(mode)
        }
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

private struct LiveDevnetSmokeResult: Codable {
    let mode: String
    let senderAddress: String
    let recipientAddress: String
    let airdropSignature: String?
    let transactionSignature: String
    let explorerURL: String
    let startingBalanceLamports: UInt64
    let endingSenderBalanceLamports: UInt64
    let endingRecipientBalanceLamports: UInt64
    let estimatedFeeLamports: UInt64?
    let confirmationStatus: String
}

private enum LiveDevnetSmokeError: LocalizedError {
    case invalidMode(String)
    case invalidSignature
    case invalidSignedTransaction
    case missingState
    case invalidState(String)
    case stateWriteFailed
    case auditLeakage
    case transactionFailed(String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .invalidMode(let mode):
            return "Unknown mode '\(mode)'. Use --help."
        case .invalidSignature:
            return "The locally produced signature did not verify against the generated public key."
        case .invalidSignedTransaction:
            return "The signed transaction did not contain the expected signature/message layout."
        case .missingState:
            return "Manual funding state is missing. Run --prepare-manual-funding first."
        case .invalidState(let message):
            return message
        case .stateWriteFailed:
            return "Could not write manual funding state."
        case .auditLeakage:
            return "The safe audit event contained sensitive material."
        case .transactionFailed(let message):
            return "Devnet transaction failed: \(message)"
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
