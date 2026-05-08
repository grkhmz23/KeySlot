import Foundation

struct WalletProfile: Codable, Equatable, Identifiable {
    let id: UUID
    var label: String
    var publicAddress: String
    var accounts: [WalletAccount]
    var selectedNetwork: WalletNetwork
    var walletOrigin: WalletOrigin
    var derivationPath: String?
    var createdAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        label: String,
        publicAddress: String,
        selectedNetwork: WalletNetwork = .devnet,
        walletOrigin: WalletOrigin = .legacyKeypair,
        derivationPath: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.label = label
        self.publicAddress = publicAddress
        self.accounts = [
            WalletAccount(id: id, publicAddress: publicAddress, label: label, derivationPath: derivationPath)
        ]
        self.selectedNetwork = selectedNetwork
        self.walletOrigin = walletOrigin
        self.derivationPath = derivationPath
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case publicAddress
        case accounts
        case selectedNetwork
        case walletOrigin
        case derivationPath
        case createdAt
        case lastUsedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        publicAddress = try container.decode(String.self, forKey: .publicAddress)
        selectedNetwork = try container.decode(WalletNetwork.self, forKey: .selectedNetwork)
        walletOrigin = try container.decodeIfPresent(WalletOrigin.self, forKey: .walletOrigin) ?? .legacyKeypair
        derivationPath = try container.decodeIfPresent(String.self, forKey: .derivationPath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        accounts = try container.decodeIfPresent([WalletAccount].self, forKey: .accounts) ?? [
            WalletAccount(id: id, publicAddress: publicAddress, label: label, derivationPath: derivationPath)
        ]
    }
}

struct WalletAccount: Codable, Equatable, Identifiable {
    let id: UUID
    var publicAddress: String
    var label: String
    var derivationPath: String?
}

enum WalletOrigin: String, Codable, CaseIterable {
    case generatedRecovery = "generated_recovery"
    case importedRecovery = "imported_recovery"
    case importedPrivateKey = "advanced_import"
    case legacyKeypair = "legacy_local"

    var displayName: String {
        switch self {
        case .generatedRecovery:
            return "Generated recovery phrase"
        case .importedRecovery:
            return "Imported recovery phrase"
        case .importedPrivateKey:
            return "Imported private key"
        case .legacyKeypair:
            return "Legacy local keypair"
        }
    }
}

enum WalletVaultState: Equatable {
    case missing
    case locked
    case unlocked
    case error(String)

    var title: String {
        switch self {
        case .missing:
            return "Missing"
        case .locked:
            return "Locked"
        case .unlocked:
            return "Unlocked"
        case .error:
            return "Error"
        }
    }
}

struct WalletBalance: Codable, Equatable {
    var lamports: UInt64
    var network: WalletNetwork
    var fetchedAt: Date
    var errorMessage: String?

    var solText: String {
        let sol = Decimal(lamports) / Decimal(SolanaConstants.lamportsPerSol)
        return "\(sol) SOL"
    }
}

struct TransactionDraft: Codable, Equatable, Identifiable {
    let id: UUID
    var network: WalletNetwork
    var fromAddress: String
    var toAddress: String
    var amountLamports: UInt64
    var memo: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        network: WalletNetwork,
        fromAddress: String,
        toAddress: String,
        amountLamports: UInt64,
        memo: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.network = network
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.amountLamports = amountLamports
        self.memo = memo
        self.createdAt = createdAt
    }

    var amountSOLText: String {
        let sol = Decimal(amountLamports) / Decimal(SolanaConstants.lamportsPerSol)
        return "\(sol) SOL"
    }
}

struct SimulationResult: Codable, Equatable {
    enum Status: String, Codable {
        case success
        case failed
        case unavailable
    }

    var status: Status
    var logs: [String]
    var estimatedFeeLamports: UInt64?
    var errorMessage: String?
    var simulatedAt: Date

    static func unavailable(_ message: String) -> SimulationResult {
        SimulationResult(
            status: .unavailable,
            logs: [],
            estimatedFeeLamports: nil,
            errorMessage: message,
            simulatedAt: Date()
        )
    }
}

enum ApprovalState: Equatable {
    case idle
    case drafted
    case simulated
    case approved
    case sending
    case sent(String)
    case failed(String)
}

struct AuditEvent: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        case walletCreated = "wallet_created"
        case walletImported = "wallet_imported"
        case walletUnlocked = "wallet_unlocked"
        case walletLocked = "wallet_locked"
        case balanceRefreshed = "balance_refreshed"
        case transactionDrafted = "transaction_drafted"
        case transactionSimulated = "transaction_simulated"
        case transactionApproved = "transaction_approved"
        case transactionSent = "transaction_sent"
        case transactionFailed = "transaction_failed"
        case tokenBalancesRefreshed = "token_balances_refreshed"
        case tokenTransferDrafted = "token_transfer_drafted"
        case tokenTransferSimulated = "token_transfer_simulated"
        case tokenTransferApproved = "token_transfer_approved"
        case tokenTransferSent = "token_transfer_sent"
        case tokenTransferFailed = "token_transfer_failed"
        case ataCreationPlanned = "ata_creation_planned"
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    let walletID: UUID?
    let network: WalletNetwork?
    let publicAddress: String?
    let transactionSignature: String?
    let message: String
    let details: [String: String]

    init(
        id: UUID = UUID(),
        kind: Kind,
        createdAt: Date = Date(),
        walletID: UUID?,
        network: WalletNetwork?,
        publicAddress: String?,
        transactionSignature: String? = nil,
        message: String,
        details: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.walletID = walletID
        self.network = network
        self.publicAddress = publicAddress
        self.transactionSignature = transactionSignature
        self.message = message
        self.details = Redaction.safeDetails(details)
    }
}

enum SolanaConstants {
    static let lamportsPerSol: UInt64 = 1_000_000_000
    static let systemProgramID = "11111111111111111111111111111111"
    static let splTokenProgramID = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    static let associatedTokenAccountProgramID = "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
    static let token2022ProgramID = "TokenzQdBNbLqP5VEhdkAS6EPFNoBxFH5u4V2dB5VF9Ss"
}

enum TransactionApprovalPolicy {
    static let requiredMainnetConfirmation = "I understand this is a real mainnet transaction."

    static func canApprove(
        network: WalletNetwork,
        simulation: SimulationResult?,
        mainnetConfirmation: String,
        hasCompletedDevnetSmoke: Bool,
        allowsUnavailableSimulation: Bool
    ) -> Bool {
        if network.isMainnet {
            guard mainnetConfirmation == requiredMainnetConfirmation, hasCompletedDevnetSmoke else {
                return false
            }
        }

        guard let simulation else {
            return false
        }

        switch simulation.status {
        case .success:
            return true
        case .unavailable:
            return allowsUnavailableSimulation
        case .failed:
            return false
        }
    }
}
