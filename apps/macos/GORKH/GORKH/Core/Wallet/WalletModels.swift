import Foundation

struct WalletProfile: Codable, Equatable, Identifiable {
    let id: UUID
    var label: String
    var publicAddress: String
    var accounts: [WalletAccount]
    var selectedNetwork: WalletNetwork
    var createdAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        label: String,
        publicAddress: String,
        selectedNetwork: WalletNetwork = .devnet,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.label = label
        self.publicAddress = publicAddress
        self.accounts = [
            WalletAccount(id: id, publicAddress: publicAddress, label: label, derivationPath: nil)
        ]
        self.selectedNetwork = selectedNetwork
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

struct WalletAccount: Codable, Equatable, Identifiable {
    let id: UUID
    var publicAddress: String
    var label: String
    var derivationPath: String?
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
