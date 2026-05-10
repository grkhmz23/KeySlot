import Foundation

struct AgentPolicyContext {
    let walletCanSign: Bool
    let walletIsWatchOnly: Bool
    let selectedNetwork: WalletNetwork
    let zerionStatus: ZerionStatusSnapshot
    let localMaxNotionalUSD: Decimal
    let now: Date

    init(
        walletCanSign: Bool,
        walletIsWatchOnly: Bool,
        selectedNetwork: WalletNetwork,
        zerionStatus: ZerionStatusSnapshot,
        localMaxNotionalUSD: Decimal = Decimal(5),
        now: Date = Date()
    ) {
        self.walletCanSign = walletCanSign
        self.walletIsWatchOnly = walletIsWatchOnly
        self.selectedNetwork = selectedNetwork
        self.zerionStatus = zerionStatus
        self.localMaxNotionalUSD = localMaxNotionalUSD
        self.now = now
    }
}

enum AgentPolicyEngine {
    static func evaluate(classification: AgentIntentClassification, lane: AgentProposalLane, context: AgentPolicyContext) -> AgentPolicyDecision {
        if classification.intentType == .unsafe {
            return .blocked(["Request asks for secret material or unsafe local command access."])
        }
        if classification.intentType == .unsupported || lane == .unsupported {
            return .blocked(["This action is outside the current Agent wallet operator scope."])
        }
        if classification.missingFields.isEmpty == false {
            return .needsMoreInput(classification.missingFields.map { "Missing \($0)." })
        }

        switch lane {
        case .readOnlyAnalysis:
            return .allowed(warnings: ["Read-only analysis only. No transaction will be prepared."])
        case .watchOnlyAnalysis:
            return .blocked(["Watch-only wallets can be analyzed but cannot execute or hand off executable proposals."])
        case .mainWallet, .cloakPrivate:
            guard context.walletCanSign && context.walletIsWatchOnly == false else {
                return .blocked(["Selected wallet cannot sign. Use a local signer wallet for destination approval."])
            }
            return .allowed(warnings: [
                "Agent cannot execute from chat.",
                "This proposal must be reviewed and approved in the destination Wallet module."
            ])
        case .zerionAgentWallet:
            var blocks: [String] = []
            if context.zerionStatus.cliStatus != .installed {
                blocks.append("Zerion CLI is not installed or unavailable.")
            }
            if context.zerionStatus.apiKeyStatus != .presentRedacted {
                blocks.append("Zerion API key is missing or malformed.")
            }
            if context.zerionStatus.agentTokenStatus != .presentRedacted {
                blocks.append("Zerion agent token is missing.")
            }
            if context.zerionStatus.swapCommandShape.canBuildTinySwap == false {
                blocks.append("Zerion swap command shape is not validated.")
            }
            if let amount = classification.amount,
               (classification.sourceAsset ?? "").uppercased() == "USDC",
               amount > context.localMaxNotionalUSD {
                blocks.append("Amount exceeds local tiny-swap cap.")
            }
            return blocks.isEmpty
                ? .allowed(warnings: ["Execution must continue through Zerion A2 review and exact confirmation."])
                : .blocked(blocks)
        case .unsupported:
            return .blocked(["Unsupported lane."])
        }
    }
}
