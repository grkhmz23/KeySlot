import Foundation

/// Deterministic text-to-proposal mapper for Developer Workstation Agent.
/// No LLM. No execution. No wallet access.
enum WorkstationAgentIntentMapper {
    static func map(_ text: String) -> AgentProposalCardDisplay? {
        let lowercased = text.lowercased()

        // Blocked: mainnet writes
        if matches(lowercased, ["mainnet deploy", "mainnet upgrade", "mainnet close", "mainnet authority", "upgrade mainnet", "close mainnet"]) {
            return AgentProposalCardDisplay(
                agentID: .developerWorkstation,
                title: "Mainnet Write Blocked",
                summary: "Mainnet program deploy/upgrade/close/authority mutation is locked.",
                details: ["Use Developer Workstation program manager for localnet/devnet only."],
                riskLevel: "blocked",
                status: .blocked,
                primaryActionTitle: "Blocked",
                primaryActionStyle: .review,
                blockedReason: "Mainnet program writes remain locked."
            )
        }

        // Blocked: shell/terminal
        if matches(lowercased, ["shell", "terminal", "bash", "run command", "execute command", "exec ", "run shell"]) {
            return AgentProposalCardDisplay(
                agentID: .developerWorkstation,
                title: "Shell Access Blocked",
                summary: "Developer Workstation Agent cannot execute arbitrary shell or terminal commands.",
                details: ["Use typed tools with fixed command previews only."],
                riskLevel: "blocked",
                status: .blocked,
                primaryActionTitle: "Blocked",
                primaryActionStyle: .review,
                blockedReason: "Arbitrary shell and raw terminal are blocked."
            )
        }

        // Blocked: wallet secrets
        if matches(lowercased, ["private key", "seed phrase", "mnemonic", "wallet json", "send transaction"]) {
            return AgentProposalCardDisplay(
                agentID: .developerWorkstation,
                title: "Request Blocked",
                summary: "Developer Workstation Agent cannot access wallet secrets.",
                details: ["Use Wallet for transactions."],
                riskLevel: "blocked",
                status: .blocked,
                primaryActionTitle: "Blocked",
                primaryActionStyle: .review,
                blockedReason: "Wallet secrets are outside this agent's scope."
            )
        }

        // Read-only: project brain
        if matches(lowercased, ["scan project", "project brain", "brain scan", "scan brain"]) {
            return AgentProposalCardDisplay(
                agentID: .developerWorkstation,
                title: "Scan Project Brain",
                summary: "Run the bounded read-only Project Brain scanner.",
                details: ["No project code is executed. Results are redacted JSON summaries."],
                riskLevel: "low",
                status: .pending,
                primaryActionTitle: "Run read-only tool",
                primaryActionStyle: .approve,
                requiresApproval: false
            )
        }

        // Read-only: transaction debug
        if matches(lowercased, ["debug transaction", "explain tx", "transaction debug", "decode tx"]) {
            let signature = extractBase58(ofLength: 64...88, from: text)
            var details = ["RPC/log-based read-only analysis. No execution."]
            if let signature { details.append("Signature: \(signature)") }
            return AgentProposalCardDisplay(
                agentID: .developerWorkstation,
                title: "Debug Transaction",
                summary: "Decode and explain a Solana transaction from its signature.",
                details: details,
                riskLevel: "low",
                status: .pending,
                primaryActionTitle: "Run read-only tool",
                primaryActionStyle: .approve,
                requiresApproval: false,
                prefill: signature.map { ["signature": $0] } ?? [:]
            )
        }

        // Read-only: PDA derive
        if matches(lowercased, ["pda", "derive pda", "find pda", "program derived address"]) {
            let seeds = extractSeeds(from: text)
            var details = ["Pure computation. No on-chain execution."]
            if !seeds.isEmpty { details.append("Seeds: \(seeds.joined(separator: ", "))") }
            return AgentProposalCardDisplay(
                agentID: .developerWorkstation,
                title: "Derive PDA",
                summary: "Derive a Program Derived Address from program ID and seeds.",
                details: details,
                riskLevel: "low",
                status: .pending,
                primaryActionTitle: "Run read-only tool",
                primaryActionStyle: .approve,
                requiresApproval: false,
                prefill: seeds.isEmpty ? [:] : ["seeds": seeds.joined(separator: ",")]
            )
        }

        // Read-only: IDL diff
        if matches(lowercased, ["idl drift", "compare idl", "idl diff", "check idl"]) {
            return AgentProposalCardDisplay(
                agentID: .developerWorkstation,
                title: "Check IDL Drift",
                summary: "Compare loaded IDL against on-chain program state.",
                details: ["Read-only summary. No unreviewed on-chain fetches."],
                riskLevel: "low",
                status: .pending,
                primaryActionTitle: "Run read-only tool",
                primaryActionStyle: .approve,
                requiresApproval: false
            )
        }

        // Read-only: account decode
        if matches(lowercased, ["decode account", "account decode", "explain account"]) {
            let address = extractBase58(ofLength: 32...44, from: text)
            var details = ["Read-only decoding. No execution."]
            if let address { details.append("Address: \(address)") }
            return AgentProposalCardDisplay(
                agentID: .developerWorkstation,
                title: "Decode Account",
                summary: "Decode an account using its IDL definition.",
                details: details,
                riskLevel: "low",
                status: .pending,
                primaryActionTitle: "Run read-only tool",
                primaryActionStyle: .approve,
                requiresApproval: false,
                prefill: address.map { ["address": $0] } ?? [:]
            )
        }

        // Execution: test
        if matches(lowercased, ["run tests", "anchor test", "cargo test", "test program", "detect tests"]) {
            return AgentProposalCardDisplay(
                agentID: .developerWorkstation,
                title: "Run Tests",
                summary: "Detect and run tests for the current project.",
                details: ["Requires project trust and fixed command preview."],
                riskLevel: "medium",
                status: .pending,
                primaryActionTitle: "Review command preview",
                primaryActionStyle: .review,
                requiresApproval: true
            )
        }

        // Execution: build/deploy
        if matches(lowercased, ["build", "deploy", "anchor build", "cargo build"]) {
            return AgentProposalCardDisplay(
                agentID: .developerWorkstation,
                title: "Build / Deploy",
                summary: "Build or deploy the current Anchor program.",
                details: ["Requires project trust, fixed preview, and explicit approval."],
                riskLevel: "high",
                status: .pending,
                primaryActionTitle: "Review command preview",
                primaryActionStyle: .review,
                requiresApproval: true
            )
        }

        // No match
        return nil
    }

    private static func matches(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private static func extractBase58(ofLength range: ClosedRange<Int>, from text: String) -> String? {
        let pattern = "([1-9A-HJ-NP-Za-km-z]{\(range.lowerBound),\(range.upperBound)})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(location: 0, length: text.utf16.count)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              let swiftRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[swiftRange])
    }

    private static func extractSeeds(from text: String) -> [String] {
        // Look for "seed" keyword followed by quoted strings or space-separated tokens
        let pattern = "seed[s]?\\s*[:=]?\\s*\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let nsRange = NSRange(location: 0, length: text.utf16.count)
        var seeds: [String] = []
        for match in regex.matches(in: text, options: [], range: nsRange) {
            if let swiftRange = Range(match.range(at: 1), in: text) {
                seeds.append(String(text[swiftRange]))
            }
        }
        return seeds
    }
}
