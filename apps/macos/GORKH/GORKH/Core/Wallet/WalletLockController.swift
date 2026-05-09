import Foundation

struct WalletLockController: Equatable {
    private(set) var policy: WalletSecurityPolicy
    private(set) var lastActivityAt: Date

    init(policy: WalletSecurityPolicy, now: Date = Date()) {
        self.policy = policy
        self.lastActivityAt = now
    }

    mutating func updatePolicy(_ policy: WalletSecurityPolicy, now: Date = Date()) {
        self.policy = policy
        markActivity(now: now)
    }

    mutating func markActivity(now: Date = Date()) {
        lastActivityAt = now
    }

    func shouldAutoLock(now: Date = Date()) -> Bool {
        guard let interval = policy.autoLockTimeout.interval else {
            return false
        }
        return now.timeIntervalSince(lastActivityAt) >= interval
    }
}
