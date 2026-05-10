import Foundation

enum ZerionRedaction {
    nonisolated static func apiKeyStatus(from environment: [String: String] = ProcessInfo.processInfo.environment) -> ZerionSecretStatus {
        guard let value = environment["ZERION_API_KEY"], value.isEmpty == false else {
            return .missing
        }
        return value.hasPrefix("zk_") ? .presentRedacted : .malformedRedacted
    }

    nonisolated static func agentTokenStatus(from text: String?) -> ZerionSecretStatus {
        guard let text, text.isEmpty == false else {
            return .unknown
        }

        let lowercased = text.lowercased()
        if lowercased.contains("agent") && lowercased.contains("token") {
            return .presentRedacted
        }
        return .unknown
    }

    nonisolated static func redact(_ text: String) -> String {
        var redacted = text
        redacted = redacted.replacingOccurrences(
            of: #"zk_[A-Za-z0-9_\-]{6,}"#,
            with: "[redacted-zerion-api-key]",
            options: .regularExpression
        )
        redacted = redacted.replacingOccurrences(
            of: #"(?i)(ZERION_API_KEY\s*[:=]\s*)[^\s,}"]+"#,
            with: "$1[redacted]",
            options: .regularExpression
        )
        redacted = redacted.replacingOccurrences(
            of: #"(?i)(agent[_\s-]*token\s*[:=]\s*)[^\s,}"]+"#,
            with: "$1[redacted]",
            options: .regularExpression
        )
        return redacted
    }

    nonisolated static func redactedPreview(_ value: String?) -> String {
        guard let value, value.isEmpty == false else {
            return "missing"
        }
        return value.hasPrefix("zk_") ? "zk_[redacted]" : "[redacted]"
    }

    nonisolated static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
        return normalized.contains("zerionapikey") ||
            normalized.contains("agenttoken") ||
            normalized.contains("privatekey") ||
            normalized.contains("secretkey") ||
            normalized.contains("walletjson") ||
            normalized.contains("signingseed")
    }

    nonisolated static func safeDetails(_ details: [String: String]) -> [String: String] {
        details.reduce(into: [String: String]()) { partial, item in
            guard isSensitiveKey(item.key) == false,
                  Redaction.isSensitiveKey(item.key) == false else {
                return
            }
            partial[item.key] = redact(item.value)
        }
    }
}
