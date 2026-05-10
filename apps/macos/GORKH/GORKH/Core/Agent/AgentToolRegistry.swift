import Foundation

enum AgentToolRegistry {
    static let forbiddenFields = [
        "mnemonic",
        "seed phrase",
        "private key",
        "wallet JSON",
        "signing seed",
        "API key",
        "agent token",
        "transaction payload",
        "serialized transaction",
        "Cloak private state"
    ]

    static let declarations: [AgentToolDeclaration] = [
        read(.getWalletOverviewSummary, lane: .readOnlyAnalysis),
        read(.getPortfolioSummary, lane: .readOnlyAnalysis),
        read(.getAssetSummary, lane: .readOnlyAnalysis),
        read(.getPUSDSummary, lane: .readOnlyAnalysis),
        read(.getStakeLstSummary, lane: .readOnlyAnalysis),
        read(.getLendingSummary, lane: .readOnlyAnalysis),
        read(.getLiquiditySummary, lane: .readOnlyAnalysis),
        read(.getYieldSummary, lane: .readOnlyAnalysis),
        read(.getPnLSummary, lane: .readOnlyAnalysis),
        read(.getActivitySummary, lane: .readOnlyAnalysis),
        read(.getSecuritySummary, lane: .readOnlyAnalysis),
        read(.getRPCStatus, lane: .readOnlyAnalysis),
        read(.getCloakStatus, lane: .readOnlyAnalysis),
        read(.getZerionStatus, lane: .readOnlyAnalysis),
        draft(.draftMainWalletSwap, lane: .mainWallet, requiredInputs: ["amount", "from token", "to token"]),
        draft(.draftMainWalletSend, lane: .mainWallet, requiredInputs: ["amount", "token", "recipient"]),
        draft(.draftPUSDPayment, lane: .mainWallet, requiredInputs: ["amount or payment request details"]),
        draft(.draftCloakPayment, lane: .cloakPrivate, requiredInputs: ["amount", "recipient"]),
        draft(.draftZerionTinySwap, lane: .zerionAgentWallet, requiredInputs: ["amount", "from token", "to token", "chain"]),
        blocked(.executeSwap),
        blocked(.executeSend),
        blocked(.executeBridge),
        blocked(.executeCloakPayment),
        blocked(.signTransaction),
        blocked(.sendTransaction),
        blocked(.runShell),
        blocked(.exportSeed),
        blocked(.revealPrivateKey),
        blocked(.arbitraryCommand)
    ]

    static var allowedToolNames: [String] {
        declarations.filter(\.isAllowed).map { $0.id.rawValue }
    }

    static func declaration(for id: AgentToolID) -> AgentToolDeclaration? {
        declarations.first { $0.id == id }
    }

    static func evaluate(toolID: AgentToolID) -> AgentToolBoundaryDecision {
        guard declaration(for: toolID)?.isAllowed == true else {
            return AgentToolBoundaryDecision(allowed: [], blocked: [toolID.rawValue])
        }
        return AgentToolBoundaryDecision(allowed: [toolID.rawValue], blocked: [])
    }

    static func defaultTool(for intent: AgentIntentType) -> AgentToolID? {
        switch intent {
        case .walletOverview:
            return .getWalletOverviewSummary
        case .receiveAddress:
            return .getWalletOverviewSummary
        case .securityStatus:
            return .getSecuritySummary
        case .activitySummary, .recentActivitySummary:
            return .getActivitySummary
        case .rpcStatus:
            return .getRPCStatus
        case .portfolioSummary, .riskSummary:
            return .getPortfolioSummary
        case .assetBreakdown:
            return .getAssetSummary
        case .walletBreakdown:
            return .getPortfolioSummary
        case .pusdTreasurySummary:
            return .getPUSDSummary
        case .stakeLstSummary:
            return .getStakeLstSummary
        case .lendingSummary:
            return .getLendingSummary
        case .liquiditySummary, .lpPositionReview:
            return .getLiquiditySummary
        case .yieldSummary, .yieldSearch:
            return .getYieldSummary
        case .pnlSummary, .costBasisHelp:
            return .getPnLSummary
        case .portfolioHistorySummary:
            return .getPortfolioSummary
        case .cloakStatus, .cloakScanSummary, .explainPrivateState:
            return .getCloakStatus
        case .zerionStatus, .zerionPolicySummary, .zerionProposalStatus:
            return .getZerionStatus
        case .prepareSwap, .tokenBuyRequest, .tokenSwapRequest:
            return .draftMainWalletSwap
        case .prepareSend, .tokenSendRequest:
            return .draftMainWalletSend
        case .pusdPaymentRequest:
            return .draftPUSDPayment
        case .prepareCloakDeposit, .cloakPrivatePaymentRequest, .prepareCloakPrivatePayment:
            return .draftCloakPayment
        case .zerionTinySwapRequest, .zerionPrepareTinySwap:
            return .draftZerionTinySwap
        case .explainSwap, .help, .whatCanYouDo, .missingFields, .unsupported, .unsafe:
            return nil
        }
    }

    private static func read(_ id: AgentToolID, lane: AgentProposalLane) -> AgentToolDeclaration {
        AgentToolDeclaration(
            id: id,
            lane: lane,
            mode: .readOnly,
            requiredInputs: [],
            forbiddenFields: forbiddenFields,
            outputRedactionClass: .walletSummary
        )
    }

    private static func draft(_ id: AgentToolID, lane: AgentProposalLane, requiredInputs: [String]) -> AgentToolDeclaration {
        AgentToolDeclaration(
            id: id,
            lane: lane,
            mode: .draftOnly,
            requiredInputs: requiredInputs,
            forbiddenFields: forbiddenFields,
            outputRedactionClass: .proposalSummary
        )
    }

    private static func blocked(_ id: AgentToolID) -> AgentToolDeclaration {
        AgentToolDeclaration(
            id: id,
            lane: .unsupported,
            mode: .blocked,
            requiredInputs: [],
            forbiddenFields: forbiddenFields,
            outputRedactionClass: .blocked
        )
    }
}
