import Foundation

enum Redaction {
    private static let blockedTokens = [
        "secret",
        "seed",
        "mnemonic",
        "phrase",
        "private",
        "walletjson",
        "wallet_json",
        "keypair"
    ]

    static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        return blockedTokens.contains { normalized.contains($0) }
    }

    static func safeDetails(_ details: [String: String]) -> [String: String] {
        details.reduce(into: [String: String]()) { partial, item in
            guard !isSensitiveKey(item.key) else {
                return
            }

            partial[item.key] = item.value
        }
    }

    static func containsSensitiveMaterial(_ value: String) -> Bool {
        let normalized = value.lowercased()
        return blockedTokens.contains { normalized.contains($0) }
    }
}
