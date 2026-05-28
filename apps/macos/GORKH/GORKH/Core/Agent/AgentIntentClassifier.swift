import Foundation

struct AgentIntentClassifier {
    func classify(_ input: String) -> AgentIntentClassification {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        guard trimmed.isEmpty == false else {
            return AgentIntentClassification(input: input, intentType: .unsupported, confidence: 0.1, missingFields: ["request"], riskFlags: [.unsupportedAction])
        }

        if containsUnsafeTerm(lower) {
            return AgentIntentClassification(input: input, intentType: .unsafe, confidence: 0.99, missingFields: [], riskFlags: [.unsafeSecretRequest])
        }
        if containsUnsupportedExecution(lower) {
            return AgentIntentClassification(input: input, intentType: .unsupported, confidence: 0.9, riskFlags: [.unsupportedAction])
        }

        let amount = firstAmount(in: trimmed)
        let recipient = firstAddress(in: trimmed)
        let chain = firstChain(in: lower)
        let tokens = tokenSymbols(in: trimmed)

        if lower == "help" || lower.contains("what can you do") || lower.contains("how can you help") {
            return AgentIntentClassification(input: input, intentType: lower == "help" ? .help : .whatCanYouDo, confidence: 0.92, riskFlags: [.readOnlyOnly])
        }
        if containsAny(lower, ["rpc", "rpc fast", "infrastructure", "endpoint status"]) {
            return AgentIntentClassification(input: input, intentType: .rpcStatus, confidence: 0.88, riskFlags: [.readOnlyOnly])
        }
        if containsAny(lower, ["security", "safe for mainnet", "mainnet safe", "wallet safe", "is my wallet safe"]) {
            return AgentIntentClassification(input: input, intentType: .securityStatus, confidence: 0.88, riskFlags: [.readOnlyOnly])
        }
        if containsAny(lower, ["receive address", "receive panel", "copy address", "payment request address"]) && lower.contains("pusd") == false {
            return AgentIntentClassification(input: input, intentType: .receiveAddress, chain: chain ?? "solana", confidence: 0.86, riskFlags: [.readOnlyOnly])
        }
        if containsAny(lower, ["wallet overview", "overview", "what do i own", "what is it worth"]) {
            return AgentIntentClassification(input: input, intentType: .walletOverview, confidence: 0.86, riskFlags: [.readOnlyOnly])
        }
        if containsAny(lower, ["asset breakdown", "assets", "top tokens", "token balances"]) {
            return AgentIntentClassification(input: input, intentType: .assetBreakdown, sourceAsset: tokens.first, confidence: 0.84, riskFlags: [.readOnlyOnly])
        }
        if containsAny(lower, ["wallet breakdown", "wallets", "watch-only", "watch only"]) {
            return AgentIntentClassification(input: input, intentType: .walletBreakdown, confidence: 0.84, riskFlags: [.readOnlyOnly])
        }
        if lower.contains("pusd") && containsAny(lower, ["treasury", "balance", "summary", "circulation", "exposure"]) {
            return AgentIntentClassification(input: input, intentType: .pusdTreasurySummary, sourceAsset: "PUSD", chain: "solana", confidence: 0.88, riskFlags: [.readOnlyOnly])
        }
        if containsAny(lower, ["stake", "lst", "jitosol", "msol", "bsol", "liquid staking"]) {
            return AgentIntentClassification(input: input, intentType: .stakeLstSummary, sourceAsset: tokens.first, confidence: 0.84, riskFlags: [.readOnlyOnly])
        }
        if containsAny(lower, ["lending", "kamino", "marginfi", "borrow status", "supply apy"]) {
            return AgentIntentClassification(input: input, intentType: .lendingSummary, sourceAsset: tokens.first, confidence: 0.84, riskFlags: [.readOnlyOnly])
        }
        if lower.contains("swap") && (lower.contains("explain") || lower.contains("why") || lower.contains("quote")) {
            return AgentIntentClassification(input: input, intentType: .explainSwap, amount: amount, sourceAsset: tokens.first, targetAsset: tokens.dropFirst().first, chain: chain ?? "solana", confidence: 0.82, riskFlags: [.readOnlyOnly])
        }
        if lower.contains("prepare") && lower.contains("swap") {
            return swapLike(input: input, type: .prepareSwap, amount: amount, recipient: recipient, chain: chain, tokens: tokens, lower: lower)
        }
        if lower.contains("prepare") && (lower.contains("send") || lower.contains("transfer")) && lower.contains("pusd") == false {
            return sendLike(input: input, type: .prepareSend, amount: amount, recipient: recipient, chain: chain, tokens: tokens)
        }

        if lower.contains("pusd") && (lower.contains("send") || lower.contains("payment") || lower.contains("request") || lower.contains("pay")) {
            var missing: [String] = []
            if amount == nil { missing.append("amount") }
            if lower.contains("send") && recipient == nil { missing.append("recipient") }
            return AgentIntentClassification(
                input: input,
                intentType: .pusdPaymentRequest,
                amount: amount,
                sourceAsset: "PUSD",
                chain: "solana",
                recipient: recipient,
                confidence: missing.isEmpty ? 0.9 : 0.74,
                missingFields: missing,
                riskFlags: missing.map { $0 == "recipient" ? .missingRecipient : .missingAmount } + [.mainWalletApprovalRequired]
            )
        }

        if lower.contains("portfolio") || lower.contains("what do i own") || lower.contains("summarize my wallet") {
            return AgentIntentClassification(input: input, intentType: .portfolioSummary, confidence: 0.86, riskFlags: [.readOnlyOnly])
        }
        if lower.contains("risk") || lower.contains("explain my portfolio risk") {
            return AgentIntentClassification(input: input, intentType: .riskSummary, confidence: 0.86, riskFlags: [.readOnlyOnly])
        }
        if lower.contains("what changed") || lower.contains("changed today") || lower.contains("recent activity") {
            return AgentIntentClassification(input: input, intentType: .recentActivitySummary, confidence: 0.88, riskFlags: [.readOnlyOnly])
        }
        if lower.contains("pnl") || lower.contains("performance") || lower.contains("cost basis") {
            return AgentIntentClassification(input: input, intentType: lower.contains("cost basis") ? .costBasisHelp : .pnlSummary, confidence: 0.86, riskFlags: [.readOnlyOnly])
        }
        if lower.contains("history") || lower.contains("snapshot") {
            return AgentIntentClassification(input: input, intentType: .portfolioHistorySummary, confidence: 0.82, riskFlags: [.readOnlyOnly])
        }
        if lower.contains("yield") || lower.contains("apy") || lower.contains("safer") {
            return AgentIntentClassification(input: input, intentType: .yieldSearch, sourceAsset: tokens.first, confidence: 0.86, riskFlags: [.readOnlyOnly])
        }
        if lower.contains("lp") || lower.contains("liquidity") || lower.contains("pool") {
            let type: AgentIntentType = lower.contains("summary") ? .liquiditySummary : .lpPositionReview
            return AgentIntentClassification(input: input, intentType: type, sourceAsset: tokens.first, confidence: 0.86, riskFlags: [.readOnlyOnly])
        }

        if lower.contains("buy") {
            let target = targetAfterBuy(in: trimmed)
            var missing: [String] = []
            var flags: [AgentRiskFlag] = [.mainWalletApprovalRequired]
            if amount == nil { missing.append("amount"); flags.append(.missingAmount) }
            if target == nil || target?.lowercased() == "this token" { missing.append("token or mint"); flags.append(.missingToken) }
            return AgentIntentClassification(
                input: input,
                intentType: .tokenBuyRequest,
                amount: amount,
                sourceAsset: tokens.last ?? "SOL",
                targetAsset: target,
                chain: chain ?? "solana",
                confidence: missing.isEmpty ? 0.82 : 0.64,
                missingFields: missing,
                riskFlags: flags
            )
        }

        if lower.contains("swap") {
            return swapLike(input: input, type: .tokenSwapRequest, amount: amount, recipient: recipient, chain: chain, tokens: tokens, lower: lower)
        }

        if lower.contains("send") || lower.contains("transfer") {
            return sendLike(input: input, type: .tokenSendRequest, amount: amount, recipient: recipient, chain: chain, tokens: tokens)
        }

        return AgentIntentClassification(input: input, intentType: .unsupported, confidence: 0.35, riskFlags: [.unsupportedAction])
    }

    private func swapLike(
        input: String,
        type: AgentIntentType,
        amount: Decimal?,
        recipient: String?,
        chain: String?,
        tokens: [String],
        lower: String
    ) -> AgentIntentClassification {
        var missing: [String] = []
        var flags: [AgentRiskFlag] = [.mainWalletApprovalRequired]
        if amount == nil { missing.append("amount"); flags.append(.missingAmount) }
        let fromToken = tokens.first
        let toToken = tokens.dropFirst().first
        if fromToken == nil { missing.append("from token"); flags.append(.missingToken) }
        if toToken == nil { missing.append("to token"); flags.append(.missingToken) }
        return AgentIntentClassification(
            input: input,
            intentType: type,
            amount: amount,
            sourceAsset: fromToken,
            targetAsset: toToken,
            chain: chain ?? "solana",
            recipient: recipient,
            confidence: missing.isEmpty ? 0.86 : 0.64,
            missingFields: missing,
            riskFlags: flags
        )
    }

    private func sendLike(
        input: String,
        type: AgentIntentType,
        amount: Decimal?,
        recipient: String?,
        chain: String?,
        tokens: [String]
    ) -> AgentIntentClassification {
        var missing: [String] = []
        var flags: [AgentRiskFlag] = [.mainWalletApprovalRequired]
        if amount == nil { missing.append("amount"); flags.append(.missingAmount) }
        if tokens.first == nil { missing.append("token"); flags.append(.missingToken) }
        if recipient == nil { missing.append("recipient"); flags.append(.missingRecipient) }
        return AgentIntentClassification(
            input: input,
            intentType: type,
            amount: amount,
            sourceAsset: tokens.first,
            chain: chain ?? "solana",
            recipient: recipient,
            confidence: missing.isEmpty ? 0.82 : 0.62,
            missingFields: missing,
            riskFlags: flags
        )
    }

    private func containsAny(_ lower: String, _ terms: [String]) -> Bool {
        terms.contains { lower.contains($0) }
    }

    private func containsUnsafeTerm(_ lower: String) -> Bool {
        [
            "private key",
            "seed phrase",
            "mnemonic",
            "wallet json",
            "signing seed",
            "api key",
            "agent token",
            "raw transaction",
            "serialized transaction",
            "/bin/sh",
            " eval ",
            "unrestricted terminal"
        ].contains { lower.contains($0) }
    }

    private func containsUnsupportedExecution(_ lower: String) -> Bool {
        [
            "bridge",
            "perp",
            "leverage",
            "borrow now",
            "borrow funds",
            "open borrow",
            "deposit to lending",
            "add liquidity",
            "remove liquidity",
            "close position",
            "claim rewards",
            "autonomous trade",
            "auto trade",
            "recurring",
            "dca"
        ].contains { lower.contains($0) }
    }

    private func firstAmount(in text: String) -> Decimal? {
        let pattern = #"(?<![A-Za-z0-9.])([0-9]+(?:\.[0-9]+)?)"#
        guard let match = try? NSRegularExpression(pattern: pattern).firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Decimal(string: String(text[range]))
    }

    private func firstAddress(in text: String) -> String? {
        let pattern = #"\b[1-9A-HJ-NP-Za-km-z]{32,44}\b"#
        guard let match = try? NSRegularExpression(pattern: pattern).firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func firstChain(in lower: String) -> String? {
        if lower.contains("base") { return "base" }
        if lower.contains("solana") || lower.contains("sol ") { return "solana" }
        return nil
    }

    private func tokenSymbols(in text: String) -> [String] {
        let ignored: Set<String> = [
            "BUY", "SWAP", "SEND", "TO", "FOR", "ON", "FROM", "THIS", "TOKEN", "FIND", "CHECK",
            "MY", "AND", "PRIVATE", "PAYMENT", "PREPARE", "BASE", "SOLANA", "SAFER",
            "BETTER", "YIELD", "APY", "RISK", "PORTFOLIO", "SUMMARY", "ACTIVITY", "RECENT",
            "TODAY", "POSITION", "POSITIONS", "POOL", "POOLS", "LIQUIDITY", "CHANGED", "WHAT",
            "OVERVIEW", "ASSETS", "WALLETS", "SECURITY", "RPC", "STATUS", "HISTORY",
            "PNL", "PERFORMANCE", "COST", "BASIS", "STAKE", "LST", "LENDING", "KAMINO", "MARGINFI",
            "HELP", "RECEIVE", "ADDRESS", "QUOTE", "EXPLAIN"
        ]
        let pattern = #"\b[A-Za-z][A-Za-z0-9]{1,9}\b"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let value = String(text[range]).uppercased()
            guard ignored.contains(value) == false else { return nil }
            return value
        }
    }

    private func targetAfterBuy(in text: String) -> String? {
        let pattern = #"(?i)\bbuy\s+(.+?)\s+for\s+[0-9]"#
        guard let match = try? NSRegularExpression(pattern: pattern).firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
