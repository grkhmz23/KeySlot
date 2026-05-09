import Foundation

enum RPCFastRedaction {
    static func redactedURLDisplay(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "[redacted-rpc-url]"
        }
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        return components.string ?? (url.host ?? "[redacted-rpc-url]")
    }

    static func redact(_ value: String, knownTokens: [String] = []) -> String {
        var redacted = value
        for token in knownTokens where !token.isEmpty {
            redacted = redacted.replacingOccurrences(of: token, with: "[redacted-rpcfast-token]")
        }

        let patterns = [
            #"(?i)(GORKH_RPCFAST_DEVNET_TOKEN|GORKH_RPCFAST_MAINNET_TOKEN|RPCFAST_DEVNET_TOKEN|RPCFAST_MAINNET_TOKEN)\s*=\s*[^,\s]+"#,
            #"(?i)(X-Token|x-token|api_key|apikey|token)\s*[:=]\s*[^,\s]+"#
        ]

        for pattern in patterns {
            redacted = redacted.replacingOccurrences(
                of: pattern,
                with: "$1=[redacted]",
                options: .regularExpression
            )
        }

        return redacted
    }
}
