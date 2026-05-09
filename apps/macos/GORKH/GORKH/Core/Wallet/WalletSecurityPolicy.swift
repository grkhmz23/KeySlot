import Foundation

enum WalletAutoLockTimeout: String, CaseIterable, Codable, Identifiable {
    case oneMinute = "one_minute"
    case fiveMinutes = "five_minutes"
    case fifteenMinutes = "fifteen_minutes"
    case never

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneMinute:
            return "1 minute"
        case .fiveMinutes:
            return "5 minutes"
        case .fifteenMinutes:
            return "15 minutes"
        case .never:
            return "Never"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 300
        case .fifteenMinutes:
            return 900
        case .never:
            return nil
        }
    }

    var warning: String? {
        switch self {
        case .never:
            return "Never auto-locking keeps the signer available until you manually lock it."
        case .oneMinute, .fiveMinutes, .fifteenMinutes:
            return nil
        }
    }
}

struct WalletSecurityPolicy: Codable, Equatable {
    var autoLockTimeout: WalletAutoLockTimeout
    var lockWhenAppInactive: Bool
    var requireLocalAuthenticationForUnlock: Bool
    var requireLocalAuthenticationForSigning: Bool

    static let `default` = WalletSecurityPolicy(
        autoLockTimeout: .fiveMinutes,
        lockWhenAppInactive: true,
        requireLocalAuthenticationForUnlock: true,
        requireLocalAuthenticationForSigning: true
    )
}

struct WalletSecuritySettingsStore {
    static let policyKey = "gorkh.wallet.security.policy"
    static let allowedKeys = [policyKey]

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPolicy() -> WalletSecurityPolicy {
        guard let data = defaults.data(forKey: Self.policyKey),
              let policy = try? decoder.decode(WalletSecurityPolicy.self, from: data) else {
            return .default
        }
        return policy
    }

    func savePolicy(_ policy: WalletSecurityPolicy) {
        guard let data = try? encoder.encode(policy) else {
            return
        }
        defaults.set(data, forKey: Self.policyKey)
    }
}
