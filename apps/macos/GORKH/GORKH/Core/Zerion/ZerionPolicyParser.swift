import Foundation

enum ZerionPolicyParser {
    static func parsePolicyCenter(policiesText: String, tokensText: String, updatedAt: Date = Date()) -> ZerionPolicyCenterSnapshot {
        let policies = parsePolicies(from: policiesText)
        let tokens = parseTokens(from: tokensText)
        let status: ZerionPolicyReadStatus = policies.isEmpty && tokens.isEmpty ? .unavailable : .loaded
        return ZerionPolicyCenterSnapshot(
            policies: policies,
            tokens: tokens,
            status: status,
            unavailableReason: status == .loaded ? nil : "No Zerion policies or agent tokens were returned by the CLI.",
            updatedAt: updatedAt
        )
    }

    static func parsePolicies(from text: String) -> [ZerionPolicySummary] {
        parseRecords(from: text, preferredKeys: ["policies", "data"]).compactMap { record in
            let id = stringValue(record, keys: ["id", "policyID", "policy_id", "name"]) ?? "policy-\(UUID().uuidString.prefix(8))"
            let name = stringValue(record, keys: ["name", "label", "id"]) ?? id
            return ZerionPolicySummary(
                id: ZerionRedaction.redact(id),
                name: ZerionRedaction.redact(name),
                allowedChains: stringArrayValue(record, keys: ["chains", "allowedChains", "allowed_chains"]),
                expiresAt: dateValue(record, keys: ["expiresAt", "expires_at", "expiry", "expires"]),
                deniesTransfers: boolValue(record, keys: ["denyTransfers", "deny_transfers", "deniesTransfers", "deny-transfers"]),
                deniesApprovals: boolValue(record, keys: ["denyApprovals", "deny_approvals", "deniesApprovals", "deny-approvals"]),
                allowlistCount: allowlistCount(record),
                walletBinding: stringValue(record, keys: ["wallet", "walletName", "wallet_name", "walletBinding", "wallet_binding"]).map(ZerionRedaction.redact),
                status: .loaded
            )
        }
    }

    static func parseTokens(from text: String) -> [ZerionAgentTokenSummary] {
        parseRecords(from: text, preferredKeys: ["tokens", "data"]).compactMap { record in
            let id = stringValue(record, keys: ["id", "name", "tokenID", "token_id"]) ?? "token-\(UUID().uuidString.prefix(8))"
            return ZerionAgentTokenSummary(
                id: ZerionRedaction.redact(id),
                policyID: stringValue(record, keys: ["policyID", "policy_id", "policy", "policyName", "policy_name"]).map(ZerionRedaction.redact),
                status: .presentRedacted,
                expiresAt: dateValue(record, keys: ["expiresAt", "expires_at", "expiry", "expires"])
            )
        }
    }

    private static func parseRecords(from text: String, preferredKeys: [String]) -> [[String: Any]] {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }
        if let array = object as? [[String: Any]] {
            return array
        }
        guard let dictionary = object as? [String: Any] else {
            return []
        }
        for key in preferredKeys {
            if let records = dictionary[key] as? [[String: Any]] {
                return records
            }
            if let wrapper = dictionary[key] as? [String: Any],
               let records = wrapper["items"] as? [[String: Any]] {
                return records
            }
        }
        if let attributes = dictionary["attributes"] as? [String: Any] {
            return [attributes]
        }
        return [dictionary]
    }

    private static func stringValue(_ record: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = record[key] as? String, value.isEmpty == false {
                return value
            }
            if let value = record[key] {
                return String(describing: value)
            }
        }
        return nil
    }

    private static func stringArrayValue(_ record: [String: Any], keys: [String]) -> [String] {
        for key in keys {
            if let value = record[key] as? [String] {
                return value.map { $0.lowercased() }
            }
            if let value = record[key] as? String {
                return value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { $0.isEmpty == false }
            }
        }
        return []
    }

    private static func boolValue(_ record: [String: Any], keys: [String]) -> Bool {
        for key in keys {
            if let value = record[key] as? Bool {
                return value
            }
            if let value = record[key] as? String {
                return ["true", "yes", "1"].contains(value.lowercased())
            }
            if let value = record[key] as? NSNumber {
                return value.boolValue
            }
        }
        return false
    }

    private static func dateValue(_ record: [String: Any], keys: [String]) -> Date? {
        let formatter = ISO8601DateFormatter()
        for key in keys {
            if let value = record[key] as? String,
               let date = formatter.date(from: value) {
                return date
            }
            if let value = record[key] as? TimeInterval {
                return Date(timeIntervalSince1970: value)
            }
        }
        return nil
    }

    private static func allowlistCount(_ record: [String: Any]) -> Int {
        if let count = record["allowlistCount"] as? Int {
            return count
        }
        if let count = record["allowlist_count"] as? Int {
            return count
        }
        if let list = record["allowlist"] as? [Any] {
            return list.count
        }
        if let list = record["allowlist"] as? String {
            return list.split(separator: ",").count
        }
        return 0
    }
}
