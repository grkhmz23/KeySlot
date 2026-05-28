import Foundation

struct AgentPolicyContext {
    let walletCanSign: Bool
    let walletIsWatchOnly: Bool
    let selectedNetwork: WalletNetwork
    let localMaxNotionalUSD: Decimal
    let now: Date

    init(
        walletCanSign: Bool,
        walletIsWatchOnly: Bool,
        selectedNetwork: WalletNetwork,
        localMaxNotionalUSD: Decimal = Decimal(5),
        now: Date = Date()
    ) {
        self.walletCanSign = walletCanSign
        self.walletIsWatchOnly = walletIsWatchOnly
        self.selectedNetwork = selectedNetwork
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
        case .mainWallet:
            guard context.walletCanSign && context.walletIsWatchOnly == false else {
                return .blocked(["Selected wallet cannot sign. Use a local signer wallet for destination approval."])
            }
            return .allowed(warnings: [
                "Agent cannot execute from chat.",
                "This proposal must be reviewed and approved in the destination Wallet module."
            ])
        case .unsupported:
            return .blocked(["Unsupported lane."])
        }
    }
}
