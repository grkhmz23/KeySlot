import Foundation

enum GlobalAgentIntentMapper {
    static func map(_ text: String) -> GlobalAgentProposal? {
        let lowercased = text.lowercased()

        // Blocked requests
        if matches(lowercased, ["private key", "reveal key", "show key", "export key", "get private"]) {
            return .blocked(
                title: "Private Key Access Blocked",
                reason: "Global Agent cannot reveal or export private keys.",
                details: ["Use the Wallet app to manage keys securely."]
            )
        }

        if matches(lowercased, ["seed phrase", "mnemonic", "recovery phrase", "show seed", "export seed"]) {
            return .blocked(
                title: "Seed Phrase Access Blocked",
                reason: "Global Agent cannot reveal or export seed phrases.",
                details: ["Use the Wallet recovery flow if you need to back up your seed phrase."]
            )
        }

        if matches(lowercased, ["shell", "terminal", "bash", "run command", "execute command", "exec ", "run shell"]) {
            return .blocked(
                title: "Shell/Terminal Access Blocked",
                reason: "Global Agent cannot execute arbitrary shell or terminal commands.",
                details: ["Use Developer Workstation for constrained developer tooling only."]
            )
        }

        if matches(lowercased, ["sendtransaction", "send transaction", "generic send", "raw send", "broadcast raw"]) {
            return .blocked(
                title: "Generic sendTransaction Blocked",
                reason: "Global Agent cannot execute generic or unreviewed transactions.",
                details: ["Use Wallet send flow for policy-scoped execution."]
            )
        }

        if matches(lowercased, ["unreviewed swap", "auto swap", "autoswap", "execute swap"]) {
            return .blocked(
                title: "Unreviewed Swap Blocked",
                reason: "Global Agent cannot execute swaps without review.",
                details: ["Draft a swap proposal for Wallet review."]
            )
        }

        // Handoff: Developer Workstation
        if matches(lowercased, ["anchor", "idl", "pda", "solana build", "debug transaction", "localnet", "program deploy", "program test", "program build", "security scan", "frontend draft"]) {
            return .handoff(
                target: .developerWorkstation,
                title: "Developer Workstation Handoff",
                summary: "This request belongs in Developer Workstation.",
                details: ["Developer Workstation provides typed tools, fixed command previews, and approval gates for Solana developer operations."]
            )
        }

        // Draft proposals
        if matches(lowercased, ["send ", "transfer ", "pay ", "payment "]) {
            let prefill = extractSendPrefill(from: text)
            var details = ["Enter the recipient and amount, then review in the Wallet send flow."]
            if let amount = prefill.amount { details.append("Amount: \(amount)") }
            if let recipient = prefill.recipient { details.append("Recipient: \(recipient)") }
            if let token = prefill.token { details.append("Token: \(token)") }
            return GlobalAgentProposal(
                kind: .sendPaymentDraft,
                title: "Send Payment Draft",
                summary: "A send-payment proposal can be drafted for Wallet review.",
                details: details,
                riskLevel: "medium",
                requiresApproval: true,
                sendPrefill: prefill
            )
        }

        if matches(lowercased, ["receive", "request payment", "get paid", "incoming"]) {
            return GlobalAgentProposal(
                kind: .receiveRequestDraft,
                title: "Receive Request Draft",
                summary: "A receive-request proposal can be drafted for Wallet review.",
                details: ["Share your address or create a payment request in the Wallet."],
                riskLevel: "low",
                requiresApproval: false
            )
        }

        if matches(lowercased, ["deposit", "fund wallet", "add funds", "top up"]) {
            return GlobalAgentProposal(
                kind: .depositDraft,
                title: "Deposit Draft",
                summary: "A deposit proposal can be drafted for Wallet review.",
                details: ["Use the Wallet deposit flow to add funds safely."],
                riskLevel: "low",
                requiresApproval: true
            )
        }

        if matches(lowercased, ["swap", "exchange", "trade", "convert"]) {
            return GlobalAgentProposal(
                kind: .swapDraft,
                title: "Swap Draft",
                summary: "A swap proposal can be drafted for Wallet review.",
                details: ["Draft a swap and review it in the Wallet swap flow."],
                riskLevel: "medium",
                requiresApproval: true
            )
        }

        // No deterministic match — return nil so existing classifier/policy pipeline handles it
        return nil
    }

    private static func matches(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private static func extractSendPrefill(from text: String) -> SendPrefillData {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Amount: number optionally followed by token name
        var amount: String?
        var token: String?
        let amountPattern = "([0-9]+\\.?[0-9]*)\\s*(SOL|USDC|USDT|ETH|BTC|sol|usdc|usdt|eth|btc)?"
        if let regex = try? NSRegularExpression(pattern: amountPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) {
            if let amountRange = Range(match.range(at: 1), in: trimmed) {
                amount = String(trimmed[amountRange])
            }
            if let tokenRange = Range(match.range(at: 2), in: trimmed) {
                token = String(trimmed[tokenRange]).uppercased()
            }
        }
        // Recipient: base58-like Solana address (32-44 chars, alphanumeric except 0, O, I, l)
        var recipient: String?
        let addressPattern = "([1-9A-HJ-NP-Za-km-z]{32,44})"
        if let regex = try? NSRegularExpression(pattern: addressPattern),
           let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) {
            if let recipientRange = Range(match.range(at: 1), in: trimmed) {
                let candidate = String(trimmed[recipientRange])
                // Exclude if it looks like a plain number (the amount we already matched)
                if candidate != amount {
                    recipient = candidate
                }
            }
        }
        return SendPrefillData(amount: amount, recipient: recipient, token: token)
    }
}
