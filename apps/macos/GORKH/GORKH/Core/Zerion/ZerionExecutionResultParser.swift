import Foundation

enum ZerionExecutionResultParser {
    static func parse(commandResult: ZerionCommandResult, fallbackChain: ZerionExecutionChain) -> ZerionExecutionResult {
        if commandResult.status != .succeeded {
            let message = firstErrorMessage(from: commandResult.stderrSummary)
                ?? commandResult.stderrSummary
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .failed(message.isEmpty ? "Zerion tiny swap failed." : message)
        }

        let stdout = commandResult.stdoutSummary
        let object = jsonObject(from: stdout)
        let hash = findString(in: object, keys: ["txHash", "transactionHash", "hash", "signature", "txid", "transaction_id"])
        let chain = findString(in: object, keys: ["chain", "chainID", "chain_id", "network"]) ?? fallbackChain.rawValue
        let rawStatus = findString(in: object, keys: ["status", "state"]) ?? "submitted"
        let message = hash.map { "Zerion tiny swap submitted: \($0)" } ?? "Zerion tiny swap command completed."

        return ZerionExecutionResult(
            status: .executed,
            chain: chain,
            transactionHash: hash,
            explorerURL: explorerURL(chain: chain, hash: hash),
            message: ZerionRedaction.redact(message),
            rawStatus: ZerionRedaction.redact(rawStatus),
            completedAt: commandResult.completedAt
        )
    }

    static func firstErrorMessage(from stderr: String) -> String? {
        guard let object = jsonObject(from: stderr) else {
            return nil
        }
        if let message = findString(in: object, keys: ["message", "detail", "title", "code"]) {
            return ZerionRedaction.redact(message)
        }
        if let dictionary = object as? [String: Any],
           let errors = dictionary["errors"] as? [[String: Any]],
           let first = errors.first {
            return findString(in: first, keys: ["message", "detail", "title", "code"]).map(ZerionRedaction.redact)
        }
        return nil
    }

    private static func jsonObject(from text: String) -> Any? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return object
    }

    private static func findString(in object: Any?, keys: Set<String>) -> String? {
        guard let object else {
            return nil
        }
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary {
                if keys.contains(key), let string = value as? String, string.isEmpty == false {
                    return string
                }
                if keys.contains(key), let value = value as? NSNumber {
                    return value.stringValue
                }
                if let nested = findString(in: value, keys: keys) {
                    return nested
                }
            }
        }
        if let array = object as? [Any] {
            for value in array {
                if let nested = findString(in: value, keys: keys) {
                    return nested
                }
            }
        }
        return nil
    }

    private static func explorerURL(chain: String, hash: String?) -> URL? {
        guard let hash, hash.isEmpty == false else {
            return nil
        }
        switch chain.lowercased() {
        case "solana":
            return URL(string: "https://solscan.io/tx/\(hash)")
        case "base":
            return URL(string: "https://basescan.org/tx/\(hash)")
        default:
            return nil
        }
    }
}
