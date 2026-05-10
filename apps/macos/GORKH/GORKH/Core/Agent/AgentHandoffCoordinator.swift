import Foundation

struct AgentHandoffInstruction: Equatable, Identifiable {
    let id: UUID
    let target: AgentHandoffTarget
    let walletSection: WalletSection?
    let agentSection: AgentSection?
    let title: String
    let instruction: String

    init(
        id: UUID = UUID(),
        target: AgentHandoffTarget,
        walletSection: WalletSection?,
        agentSection: AgentSection?,
        title: String,
        instruction: String
    ) {
        self.id = id
        self.target = target
        self.walletSection = walletSection
        self.agentSection = agentSection
        self.title = AgentSafetyRedactor.redact(title)
        self.instruction = AgentSafetyRedactor.redact(instruction)
    }
}

enum AgentHandoffCoordinator {
    static func instruction(for proposal: AgentProposal) -> AgentHandoffInstruction {
        instruction(for: proposal.handoffTarget)
    }

    static func instruction(for target: AgentHandoffTarget) -> AgentHandoffInstruction {
        switch target {
        case .walletOverview:
            return wallet(.overview, target: target, title: "Open Wallet Overview")
        case .walletReceive:
            return wallet(.overview, target: target, title: "Open Receive", detail: "Use the Receive card in Wallet Overview. Receiving only displays public address details; no funds move from Agent Chat.")
        case .walletSwap:
            return wallet(.swap, target: target, title: "Open Swap Review")
        case .walletSend:
            return wallet(.send, target: target, title: "Open Send")
        case .walletPrivate:
            return wallet(.privateWallet, target: target, title: "Open Private")
        case .walletPortfolio,
             .portfolioAssets,
             .portfolioWallets,
             .portfolioPUSD,
             .portfolioStake,
             .portfolioLending,
             .portfolioLiquidity,
             .portfolioYield,
             .portfolioPnL,
             .portfolioHistory:
            return wallet(.portfolio, target: target, title: target.title, detail: portfolioDetail(for: target))
        case .walletSecurity:
            return wallet(.security, target: target, title: "Open Security")
        case .walletActivity:
            return wallet(.activity, target: target, title: "Open Activity")
        case .zerionReview:
            return AgentHandoffInstruction(
                target: target,
                walletSection: nil,
                agentSection: .proposals,
                title: target.title,
                instruction: "Open Agent Proposals and continue through the existing Zerion review flow."
            )
        case .none:
            return AgentHandoffInstruction(
                target: target,
                walletSection: nil,
                agentSection: nil,
                title: "No handoff",
                instruction: "This item is read-only or blocked; no destination review screen is available."
            )
        }
    }

    static func target(for intent: AgentIntentType) -> AgentHandoffTarget {
        switch intent {
        case .walletOverview:
            return .walletOverview
        case .receiveAddress:
            return .walletReceive
        case .prepareSend, .tokenSendRequest, .pusdPaymentRequest:
            return .walletSend
        case .prepareSwap, .tokenBuyRequest, .tokenSwapRequest:
            return .walletSwap
        case .prepareCloakDeposit, .cloakPrivatePaymentRequest, .prepareCloakPrivatePayment, .cloakStatus, .cloakScanSummary, .explainPrivateState:
            return .walletPrivate
        case .securityStatus:
            return .walletSecurity
        case .activitySummary, .recentActivitySummary:
            return .walletActivity
        case .assetBreakdown:
            return .portfolioAssets
        case .walletBreakdown:
            return .portfolioWallets
        case .pusdTreasurySummary:
            return .portfolioPUSD
        case .stakeLstSummary:
            return .portfolioStake
        case .lendingSummary:
            return .portfolioLending
        case .liquiditySummary, .lpPositionReview:
            return .portfolioLiquidity
        case .yieldSummary, .yieldSearch:
            return .portfolioYield
        case .pnlSummary, .costBasisHelp:
            return .portfolioPnL
        case .portfolioHistorySummary:
            return .portfolioHistory
        case .portfolioSummary, .riskSummary:
            return .walletPortfolio
        case .zerionTinySwapRequest, .zerionPrepareTinySwap, .zerionStatus, .zerionPolicySummary, .zerionProposalStatus:
            return .zerionReview
        case .explainSwap, .rpcStatus, .help, .whatCanYouDo, .missingFields, .unsupported, .unsafe:
            return .none
        }
    }

    private static func wallet(_ section: WalletSection, target: AgentHandoffTarget, title: String, detail: String? = nil) -> AgentHandoffInstruction {
        AgentHandoffInstruction(
            target: target,
            walletSection: section,
            agentSection: nil,
            title: title,
            instruction: detail ?? "Open Wallet -> \(section.title). The destination module keeps its own review and approval gates."
        )
    }

    private static func portfolioDetail(for target: AgentHandoffTarget) -> String {
        let destination: String
        switch target {
        case .portfolioAssets:
            destination = "Assets"
        case .portfolioWallets:
            destination = "Wallets"
        case .portfolioPUSD:
            destination = "PUSD Treasury"
        case .portfolioStake:
            destination = "Stake / LST"
        case .portfolioLending:
            destination = "Lending"
        case .portfolioLiquidity:
            destination = "Liquidity"
        case .portfolioYield:
            destination = "Yield"
        case .portfolioPnL:
            destination = "PnL"
        case .portfolioHistory:
            destination = "History"
        default:
            destination = "Summary"
        }
        return "Open Wallet -> Portfolio, then review the \(destination) section. Agent only hands off; Portfolio remains read-only unless an existing destination flow requires approval."
    }
}
