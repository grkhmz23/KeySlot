import Foundation

enum ZerionExecutionPolicyStatus: String, Codable, Equatable {
    case ready
    case blocked
}

struct ZerionExecutionPolicyDecision: Codable, Equatable {
    let status: ZerionExecutionPolicyStatus
    let blockingReasons: [String]
    let warnings: [String]
    let localMaxNotionalUSD: Decimal
    let evaluatedAt: Date

    var canExecute: Bool {
        status == .ready && blockingReasons.isEmpty
    }

    static func blocked(_ reasons: [String], warnings: [String] = [], cap: Decimal) -> ZerionExecutionPolicyDecision {
        ZerionExecutionPolicyDecision(
            status: .blocked,
            blockingReasons: reasons.map(ZerionRedaction.redact),
            warnings: warnings.map(ZerionRedaction.redact),
            localMaxNotionalUSD: cap,
            evaluatedAt: Date()
        )
    }
}

struct ZerionExecutionPolicyContext {
    let statusSnapshot: ZerionStatusSnapshot
    let policySnapshot: ZerionPolicyCenterSnapshot
    let helpProbe: ZerionCLIHelpProbe
    let safetyPolicy: AgentSafetyPolicy
    let localMaxNotionalUSD: Decimal
    let now: Date
    let maximumProposalAge: TimeInterval

    init(
        statusSnapshot: ZerionStatusSnapshot,
        policySnapshot: ZerionPolicyCenterSnapshot,
        helpProbe: ZerionCLIHelpProbe,
        safetyPolicy: AgentSafetyPolicy = .zerionA2,
        localMaxNotionalUSD: Decimal = Decimal(5),
        now: Date = Date(),
        maximumProposalAge: TimeInterval = 10 * 60
    ) {
        self.statusSnapshot = statusSnapshot
        self.policySnapshot = policySnapshot
        self.helpProbe = helpProbe
        self.safetyPolicy = safetyPolicy
        self.localMaxNotionalUSD = localMaxNotionalUSD
        self.now = now
        self.maximumProposalAge = maximumProposalAge
    }
}

enum ZerionExecutionPolicy {
    static func validate(
        proposal: ZerionTinySwapProposal,
        approval: ZerionExecutionApproval?,
        context: ZerionExecutionPolicyContext
    ) -> ZerionExecutionPolicyDecision {
        var blocks: [String] = []
        var warnings: [String] = []

        if context.safetyPolicy.mainWalletAccess != .disabled {
            blocks.append("GORKH main wallet access must remain disabled.")
        }
        if context.safetyPolicy.canUseNativeSigner {
            blocks.append("GORKH native signer access is not allowed for Zerion execution.")
        }
        if context.statusSnapshot.cliStatus != .installed {
            blocks.append("Zerion CLI is not installed or unavailable.")
        }
        if context.statusSnapshot.nodeStatus == .incompatible || context.statusSnapshot.nodeStatus == .missing {
            blocks.append("Node.js 20 or later is required for Zerion CLI.")
        }
        if context.statusSnapshot.apiKeyStatus != .presentRedacted {
            blocks.append("ZERION_API_KEY must be present and redacted.")
        }
        if context.statusSnapshot.agentTokenStatus != .presentRedacted {
            blocks.append("A Zerion agent token must be configured before execution.")
        }
        if context.helpProbe.swapCommandShape.canBuildTinySwap == false {
            blocks.append("Zerion swap command shape has not been safely validated from local CLI help.")
        }
        if proposal.amount <= 0 {
            blocks.append("Tiny swap amount must be greater than zero.")
        }
        if proposal.zerionWalletName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append("A separate Zerion wallet name is required.")
        }
        if context.now.timeIntervalSince(proposal.createdAt) > context.maximumProposalAge {
            blocks.append("Zerion proposal is stale and must be recreated.")
        }

        let matchingPolicy = context.policySnapshot.policies.first { policy in
            policy.id.caseInsensitiveCompare(proposal.policyID) == .orderedSame
                || policy.name.caseInsensitiveCompare(proposal.policyID) == .orderedSame
                || proposal.policyName.map { policyName in policy.name.caseInsensitiveCompare(policyName) == .orderedSame } == true
        }
        guard let policy = matchingPolicy else {
            blocks.append("A matching scoped Zerion policy is required.")
            return .blocked(blocks, warnings: warnings, cap: context.localMaxNotionalUSD)
        }

        if policy.allowedChains.map({ $0.lowercased() }).contains(proposal.chain.rawValue) == false {
            blocks.append("Zerion policy chain does not match the proposal chain.")
        }
        if let expiresAt = policy.expiresAt, expiresAt <= context.now {
            blocks.append("Zerion policy is expired.")
        }
        if policy.deniesTransfers == false {
            warnings.append("Policy does not report deny-transfers. Confirm the manual policy is intentionally scoped.")
        }
        if policy.deniesApprovals == false {
            warnings.append("Policy does not report deny-approvals. Confirm the manual policy is intentionally scoped.")
        }

        if let estimated = proposal.estimatedNotionalUSD {
            if estimated > context.localMaxNotionalUSD {
                blocks.append("Estimated notional exceeds the local tiny-swap cap.")
            }
        } else if approval?.unknownValueAcknowledged != true {
            blocks.append("USD value is unavailable; explicit unknown-value acknowledgement is required.")
        }

        guard let approval else {
            blocks.append("Explicit GORKH approval is required.")
            return .blocked(blocks, warnings: warnings, cap: context.localMaxNotionalUSD)
        }
        if approval.proposalID != proposal.id || approval.proposalFingerprint != proposal.fingerprint {
            blocks.append("Proposal fingerprint mismatch.")
        }
        if approval.hasExactConfirmation == false {
            blocks.append("Exact Zerion execution confirmation phrase is required.")
        }

        return ZerionExecutionPolicyDecision(
            status: blocks.isEmpty ? .ready : .blocked,
            blockingReasons: blocks.map(ZerionRedaction.redact),
            warnings: warnings.map(ZerionRedaction.redact),
            localMaxNotionalUSD: context.localMaxNotionalUSD,
            evaluatedAt: Date()
        )
    }
}
