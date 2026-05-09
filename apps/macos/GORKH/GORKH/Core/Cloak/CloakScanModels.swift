import Foundation

enum CloakScanStatus: String, Codable, Equatable, CaseIterable {
    case idle
    case scanning
    case loaded
    case empty
    case partial
    case unavailable
    case error
    case cacheCleared = "cache_cleared"

    var title: String {
        switch self {
        case .idle:
            return "Not Scanned"
        case .scanning:
            return "Scanning"
        case .loaded:
            return "Loaded"
        case .empty:
            return "No Chain Activity"
        case .partial:
            return "Partial"
        case .unavailable:
            return "Unavailable"
        case .error:
            return "Error"
        case .cacheCleared:
            return "Cache Cleared"
        }
    }
}

enum CloakScanCredentialStatus: String, Codable, Equatable {
    case unavailable
    case stored
    case locked

    var title: String {
        switch self {
        case .unavailable:
            return "Unavailable"
        case .stored:
            return "Stored Locally"
        case .locked:
            return "Locked"
        }
    }
}

struct CloakScanTransactionSummary: Codable, Equatable, Identifiable {
    let signature: String?
    let txType: String?
    let amountLamports: String
    let feeLamports: String
    let netAmountLamports: String
    let runningBalanceLamports: String?
    let timestampMillis: String?
    let recipient: String?
    let commitmentPrefix: String?
    let mintAddress: String?
    let symbol: String?
    let status: String

    var id: String {
        signature ?? "\(txType ?? "scan")-\(commitmentPrefix ?? "none")-\(timestampMillis ?? "0")"
    }

    var amountSOLText: String {
        Self.solText(amountLamports)
    }

    var netSOLText: String {
        Self.solText(netAmountLamports)
    }

    var date: Date? {
        guard let timestampMillis,
              let millis = Double(timestampMillis) else {
            return nil
        }
        return Date(timeIntervalSince1970: millis / 1_000)
    }

    static func solText(_ value: String) -> String {
        guard let decimal = Decimal(string: value) else {
            return "Unavailable"
        }
        return "\(decimal / Decimal(SolanaConstants.lamportsPerSol)) SOL"
    }
}

struct CloakComplianceSummary: Codable, Equatable {
    let transactionCount: Int
    let totalDepositsLamports: String
    let totalWithdrawalsLamports: String
    let totalFeesLamports: String
    let netChangeLamports: String
    let finalBalanceLamports: String
    let mintBreakdown: [CloakComplianceMintBreakdown]
    let dateRangeStart: String?
    let dateRangeEnd: String?
    let generatedAt: Date
}

struct CloakComplianceMintBreakdown: Codable, Equatable, Identifiable {
    let mintAddress: String
    let symbol: String?
    let netLamports: String

    var id: String { mintAddress }
}

struct CloakScanSummary: Codable, Equatable {
    let status: CloakScanStatus
    let transactions: [CloakScanTransactionSummary]
    let totalDepositsLamports: String
    let totalWithdrawalsLamports: String
    let totalFeesLamports: String
    let netChangeLamports: String
    let finalBalanceLamports: String
    let transactionCount: Int
    let scannedAt: Date
    let lastSignature: String?
    let errorMessage: String?
    let rpcProvider: String?
    let rpcHost: String?
    let complianceSummary: CloakComplianceSummary?

    static func idle() -> CloakScanSummary {
        CloakScanSummary(
            status: .idle,
            transactions: [],
            totalDepositsLamports: "0",
            totalWithdrawalsLamports: "0",
            totalFeesLamports: "0",
            netChangeLamports: "0",
            finalBalanceLamports: "0",
            transactionCount: 0,
            scannedAt: Date.distantPast,
            lastSignature: nil,
            errorMessage: nil,
            rpcProvider: nil,
            rpcHost: nil,
            complianceSummary: nil
        )
    }

    static func scanning(previous: CloakScanSummary = .idle()) -> CloakScanSummary {
        CloakScanSummary(
            status: .scanning,
            transactions: previous.transactions,
            totalDepositsLamports: previous.totalDepositsLamports,
            totalWithdrawalsLamports: previous.totalWithdrawalsLamports,
            totalFeesLamports: previous.totalFeesLamports,
            netChangeLamports: previous.netChangeLamports,
            finalBalanceLamports: previous.finalBalanceLamports,
            transactionCount: previous.transactionCount,
            scannedAt: Date(),
            lastSignature: previous.lastSignature,
            errorMessage: nil,
            rpcProvider: previous.rpcProvider,
            rpcHost: previous.rpcHost,
            complianceSummary: previous.complianceSummary
        )
    }

    static func unavailable(_ message: String) -> CloakScanSummary {
        CloakScanSummary(
            status: .unavailable,
            transactions: [],
            totalDepositsLamports: "0",
            totalWithdrawalsLamports: "0",
            totalFeesLamports: "0",
            netChangeLamports: "0",
            finalBalanceLamports: "0",
            transactionCount: 0,
            scannedAt: Date(),
            lastSignature: nil,
            errorMessage: message,
            rpcProvider: nil,
            rpcHost: nil,
            complianceSummary: nil
        )
    }

    static func cacheCleared() -> CloakScanSummary {
        var summary = idle()
        summary = CloakScanSummary(
            status: .cacheCleared,
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
            rpcProvider: nil,
            rpcHost: nil,
            complianceSummary: nil
        )
        return summary
    }
}

enum CloakActivityReconciliationState: String, Codable, Equatable {
    case matched
    case localOnly = "local_only"
    case chainOnly = "chain_only"
    case unknown

    var title: String {
        switch self {
        case .matched:
            return "Matched"
        case .localOnly:
            return "Local Only"
        case .chainOnly:
            return "Chain Only"
        case .unknown:
            return "Unknown"
        }
    }
}

struct CloakReconciledActivity: Codable, Equatable, Identifiable {
    let id: String
    let state: CloakActivityReconciliationState
    let localRecordID: UUID?
    let chainSignature: String?
    let amountLamports: String
    let statusText: String
    let timestamp: Date?
    let commitmentPrefix: String?
}

enum CloakActivityReconciler {
    static func reconcile(
        localRecords: [CloakPrivateRecordMetadata],
        scanSummary: CloakScanSummary
    ) -> [CloakReconciledActivity] {
        let chainBySignature = Dictionary(uniqueKeysWithValues: scanSummary.transactions.compactMap { transaction in
            transaction.signature.map { ($0, transaction) }
        })
        var usedSignatures = Set<String>()
        var reconciled: [CloakReconciledActivity] = []

        for record in localRecords {
            let candidates = [record.depositSignature, record.withdrawSignature].compactMap { $0 }
            let match = candidates.compactMap { signature -> CloakScanTransactionSummary? in
                guard let transaction = chainBySignature[signature] else {
                    return nil
                }
                usedSignatures.insert(signature)
                return transaction
            }.first

            reconciled.append(CloakReconciledActivity(
                id: record.id.uuidString,
                state: match == nil ? .localOnly : .matched,
                localRecordID: record.id,
                chainSignature: match?.signature ?? record.withdrawSignature ?? record.depositSignature,
                amountLamports: match?.amountLamports ?? "\(record.amountLamports)",
                statusText: record.state.rawValue,
                timestamp: match?.date ?? record.updatedAt,
                commitmentPrefix: match?.commitmentPrefix ?? record.commitmentPrefix
            ))
        }

        for transaction in scanSummary.transactions where !usedSignatures.contains(transaction.signature ?? "") {
            reconciled.append(CloakReconciledActivity(
                id: transaction.id,
                state: .chainOnly,
                localRecordID: nil,
                chainSignature: transaction.signature,
                amountLamports: transaction.amountLamports,
                statusText: transaction.txType ?? "scan",
                timestamp: transaction.date,
                commitmentPrefix: transaction.commitmentPrefix
            ))
        }

        return reconciled.sorted { lhs, rhs in
            (lhs.timestamp ?? .distantPast) > (rhs.timestamp ?? .distantPast)
        }
    }
}

enum CloakScanPolicy {
    static func credentialStatus(vaultStatus: CloakVaultStatus, vaultState: WalletVaultState) -> CloakScanCredentialStatus {
        guard vaultStatus.hasViewingKeyReference else {
            return .unavailable
        }
        return vaultState == .unlocked ? .stored : .locked
    }

    static func canScan(vaultStatus: CloakVaultStatus, vaultState: WalletVaultState, network: WalletNetwork) -> Bool {
        credentialStatus(vaultStatus: vaultStatus, vaultState: vaultState) == .stored
            && network == .mainnetBeta
    }
}

struct CloakScanCacheEntry: Codable, Equatable {
    let walletID: UUID
    let summary: CloakScanSummary
    let updatedAt: Date
}

final class CloakScanCacheStore {
    static let cacheKey = "ai.gorkh.cloak.scan.cache.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(walletID: UUID?) -> CloakScanSummary? {
        guard let walletID else {
            return nil
        }
        return loadEntries().first { $0.walletID == walletID }?.summary
    }

    func upsert(summary: CloakScanSummary, walletID: UUID) {
        var entries = loadEntries()
        entries.removeAll { $0.walletID == walletID }
        entries.append(CloakScanCacheEntry(walletID: walletID, summary: summary, updatedAt: Date()))
        save(entries)
    }

    func clear(walletID: UUID) {
        save(loadEntries().filter { $0.walletID != walletID })
    }

    private func loadEntries() -> [CloakScanCacheEntry] {
        guard let data = defaults.data(forKey: Self.cacheKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CloakScanCacheEntry].self, from: data)) ?? []
    }

    private func save(_ entries: [CloakScanCacheEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try? encoder.encode(entries), forKey: Self.cacheKey)
    }
}
