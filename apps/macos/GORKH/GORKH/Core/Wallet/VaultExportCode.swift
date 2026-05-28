import CryptoKit
import Foundation
import Security

// MARK: - Vault Export Code Generation

enum VaultExportCode {
    /// Format: XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX (32 hex chars = 128 bits)
    static let segmentCount = 8
    static let segmentLength = 4
    static let totalLength = segmentCount * segmentLength // 32

    static func generate() -> String {
        var bytes = [UInt8](repeating: 0, count: 16) // 128 bits
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            fatalError("Secure randomness unavailable for Vault Export Code generation")
        }
        let hex = Data(bytes).map { String(format: "%02x", $0) }.joined()
        return format(hex: hex)
    }

    static func format(hex: String) -> String {
        stride(from: 0, to: hex.count, by: segmentLength).map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            let end = hex.index(start, offsetBy: segmentLength)
            return String(hex[start..<end])
        }.joined(separator: "-")
    }

    static func normalize(_ code: String) -> String {
        code.lowercased().replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespaces)
    }

    static func isValidFormat(_ code: String) -> Bool {
        let normalized = normalize(code)
        guard normalized.count == totalLength else { return false }
        return normalized.allSatisfy { $0.isHexDigit }
    }
}

// MARK: - Vault Export Code Verifier

struct VaultExportCodeVerifier: Codable, Equatable {
    let salt: Data
    let hash: Data
    let version: Int

    static let currentVersion = 1

    init?(code: String) {
        guard VaultExportCode.isValidFormat(code) else { return nil }
        let normalized = VaultExportCode.normalize(code)
        guard let codeData = normalized.data(using: .utf8) else { return nil }

        var saltBytes = [UInt8](repeating: 0, count: 32)
        let saltStatus = SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes)
        guard saltStatus == errSecSuccess else { return nil }
        self.salt = Data(saltBytes)

        self.hash = Self.deriveHash(codeData: codeData, salt: self.salt)
        self.version = Self.currentVersion
    }

    func verify(code: String) -> Bool {
        guard VaultExportCode.isValidFormat(code) else { return false }
        let normalized = VaultExportCode.normalize(code)
        guard let codeData = normalized.data(using: .utf8) else { return false }
        let candidate = Self.deriveHash(codeData: codeData, salt: salt)
        return candidate.count == hash.count && candidate.constantTimeEquals(hash)
    }

    private static func deriveHash(codeData: Data, salt: Data) -> Data {
        var saltInput = Data(salt)
        saltInput.append(codeData)
        return Data(SHA256.hash(data: saltInput))
    }
}

// MARK: - Constant-Time Comparison

extension Data {
    fileprivate func constantTimeEquals(_ other: Data) -> Bool {
        guard count == other.count else { return false }
        var result: UInt8 = 0
        for (a, b) in zip(self, other) {
            result |= a ^ b
        }
        return result == 0
    }
}

// MARK: - Vault Export Code Store

protocol VaultExportCodeStoring {
    func saveVerifier(_ verifier: VaultExportCodeVerifier, for walletID: UUID) throws
    func loadVerifier(for walletID: UUID) throws -> VaultExportCodeVerifier?
    func deleteVerifier(for walletID: UUID) throws
    func containsVerifier(for walletID: UUID) -> Bool
}

final class KeychainVaultExportCodeStore: VaultExportCodeStoring {
    private let service = "foundation.swarp.keyslot.wallet.vault-export-code"

    func saveVerifier(_ verifier: VaultExportCodeVerifier, for walletID: UUID) throws {
        let data = try JSONEncoder().encode(verifier)
        let query = baseQuery(for: walletID)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw WalletVaultError.keychainError(updateStatus)
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw WalletVaultError.keychainError(addStatus)
        }
    }

    func loadVerifier(for walletID: UUID) throws -> VaultExportCodeVerifier? {
        var query = baseQuery(for: walletID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw WalletVaultError.keychainError(status)
        }
        guard let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(VaultExportCodeVerifier.self, from: data)
    }

    func deleteVerifier(for walletID: UUID) throws {
        let status = SecItemDelete(baseQuery(for: walletID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WalletVaultError.keychainError(status)
        }
    }

    func containsVerifier(for walletID: UUID) -> Bool {
        var query = baseQuery(for: walletID)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = false
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    private func baseQuery(for walletID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletID.uuidString
        ]
    }
}

// MARK: - Attempt Tracker

struct VaultExportCodeAttemptRecord: Codable, Equatable {
    var consecutiveFailures: Int
    var lastFailureAt: Date?
    var lockedUntil: Date?

    static let empty = VaultExportCodeAttemptRecord(consecutiveFailures: 0, lastFailureAt: nil, lockedUntil: nil)
}

protocol VaultExportCodeAttemptTracking {
    func record(for walletID: UUID) -> VaultExportCodeAttemptRecord
    func recordSuccess(for walletID: UUID)
    func recordFailure(for walletID: UUID)
    func isLocked(for walletID: UUID, now: Date) -> Bool
    func lockoutRemaining(for walletID: UUID, now: Date) -> TimeInterval
    func reset(for walletID: UUID)
}

final class UserDefaultsVaultExportCodeAttemptTracker: VaultExportCodeAttemptTracking {
    private let keyPrefix = "keyslot.wallet.vault-export-code.attempts."

    func record(for walletID: UUID) -> VaultExportCodeAttemptRecord {
        guard let data = UserDefaults.standard.data(forKey: keyPrefix + walletID.uuidString),
              let record = try? JSONDecoder().decode(VaultExportCodeAttemptRecord.self, from: data) else {
            return .empty
        }
        return record
    }

    func recordSuccess(for walletID: UUID) {
        save(.empty, for: walletID)
    }

    func recordFailure(for walletID: UUID) {
        var current = record(for: walletID)
        current.consecutiveFailures += 1
        current.lastFailureAt = Date()

        let lockoutDuration: TimeInterval
        switch current.consecutiveFailures {
        case 1...2:
            lockoutDuration = 0
        case 3...4:
            lockoutDuration = 30
        case 5...6:
            lockoutDuration = 300 // 5 minutes
        default:
            lockoutDuration = 3600 // 1 hour
        }

        if lockoutDuration > 0 {
            current.lockedUntil = Date().addingTimeInterval(lockoutDuration)
        }

        save(current, for: walletID)
    }

    func isLocked(for walletID: UUID, now: Date) -> Bool {
        let record = record(for: walletID)
        guard let lockedUntil = record.lockedUntil else { return false }
        return now < lockedUntil
    }

    func lockoutRemaining(for walletID: UUID, now: Date) -> TimeInterval {
        let record = record(for: walletID)
        guard let lockedUntil = record.lockedUntil else { return 0 }
        return max(0, lockedUntil.timeIntervalSince(now))
    }

    func reset(for walletID: UUID) {
        UserDefaults.standard.removeObject(forKey: keyPrefix + walletID.uuidString)
    }

    private func save(_ record: VaultExportCodeAttemptRecord, for walletID: UUID) {
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: keyPrefix + walletID.uuidString)
        }
    }
}

// MARK: - Vault Export Code Service

protocol VaultExportCodeServicing {
    func generateCode() -> String
    func createVerifier(from code: String) -> VaultExportCodeVerifier?
    func verify(code: String, for walletID: UUID) -> VaultExportCodeVerificationResult
    func saveVerifier(_ verifier: VaultExportCodeVerifier, for walletID: UUID) throws
    func isLocked(for walletID: UUID, now: Date) -> Bool
    func lockoutRemaining(for walletID: UUID, now: Date) -> TimeInterval
    func resetAttempts(for walletID: UUID)
}

enum VaultExportCodeVerificationResult: Equatable {
    case success
    case locked(remaining: TimeInterval)
    case invalidFormat
    case wrongCode(remainingAttempts: Int?)
}

final class VaultExportCodeService: VaultExportCodeServicing {
    private let store: VaultExportCodeStoring
    private let attemptTracker: VaultExportCodeAttemptTracking

    init(
        store: VaultExportCodeStoring = KeychainVaultExportCodeStore(),
        attemptTracker: VaultExportCodeAttemptTracking = UserDefaultsVaultExportCodeAttemptTracker()
    ) {
        self.store = store
        self.attemptTracker = attemptTracker
    }

    func generateCode() -> String {
        VaultExportCode.generate()
    }

    func createVerifier(from code: String) -> VaultExportCodeVerifier? {
        VaultExportCodeVerifier(code: code)
    }

    func verify(code: String, for walletID: UUID) -> VaultExportCodeVerificationResult {
        let now = Date()
        if attemptTracker.isLocked(for: walletID, now: now) {
            return .locked(remaining: attemptTracker.lockoutRemaining(for: walletID, now: now))
        }

        guard VaultExportCode.isValidFormat(code) else {
            return .invalidFormat
        }

        guard let verifier = try? store.loadVerifier(for: walletID) else {
            return .wrongCode(remainingAttempts: nil)
        }

        if verifier.verify(code: code) {
            attemptTracker.recordSuccess(for: walletID)
            return .success
        } else {
            attemptTracker.recordFailure(for: walletID)
            let remaining = maxAttemptsBeforeLockout - attemptTracker.record(for: walletID).consecutiveFailures
            return .wrongCode(remainingAttempts: remaining > 0 ? remaining : nil)
        }
    }

    func saveVerifier(_ verifier: VaultExportCodeVerifier, for walletID: UUID) throws {
        try store.saveVerifier(verifier, for: walletID)
    }

    func isLocked(for walletID: UUID, now: Date) -> Bool {
        attemptTracker.isLocked(for: walletID, now: now)
    }

    func lockoutRemaining(for walletID: UUID, now: Date) -> TimeInterval {
        attemptTracker.lockoutRemaining(for: walletID, now: now)
    }

    func resetAttempts(for walletID: UUID) {
        attemptTracker.reset(for: walletID)
    }

    private var maxAttemptsBeforeLockout: Int { 3 }
}
