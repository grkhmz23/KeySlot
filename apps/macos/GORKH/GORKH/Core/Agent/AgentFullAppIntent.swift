import Foundation

struct AgentFullAppIntent: Codable, Equatable, Identifiable {
    let id: UUID
    let classification: AgentIntentClassification
    let appArea: AppArea
    let defaultToolID: AgentToolID?
    let createdAt: Date

    enum AppArea: String, Codable, CaseIterable, Identifiable {
        case wallet
        case portfolio
        case privateWallet
        case zerion
        case infrastructure
        case help
        case unsupported

        var id: String { rawValue }

        var title: String {
            switch self {
            case .wallet:
                return "Wallet"
            case .portfolio:
                return "Portfolio"
            case .privateWallet:
                return "Private"
            case .zerion:
                return "Zerion"
            case .infrastructure:
                return "Infrastructure"
            case .help:
                return "Help"
            case .unsupported:
                return "Unsupported"
            }
        }
    }

    init(
        id: UUID = UUID(),
        classification: AgentIntentClassification,
        appArea: AppArea,
        defaultToolID: AgentToolID?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.classification = classification
        self.appArea = appArea
        self.defaultToolID = defaultToolID
        self.createdAt = createdAt
    }
}

enum AgentFullAppIntentClassifier {
    static func classify(_ input: String, classifier: AgentIntentClassifier = AgentIntentClassifier()) -> AgentFullAppIntent {
        let classification = classifier.classify(input)
        return AgentFullAppIntent(
            classification: classification,
            appArea: appArea(for: classification.intentType),
            defaultToolID: AgentToolRegistry.defaultTool(for: classification.intentType)
        )
    }

    static func appArea(for intent: AgentIntentType) -> AgentFullAppIntent.AppArea {
        switch intent {
        case .walletOverview,
             .receiveAddress,
             .prepareSend,
             .prepareSwap,
             .explainSwap,
             .securityStatus,
             .activitySummary,
             .tokenBuyRequest,
             .tokenSwapRequest,
             .tokenSendRequest,
             .pusdPaymentRequest,
             .recentActivitySummary:
            return .wallet
        case .portfolioSummary,
             .assetBreakdown,
             .walletBreakdown,
             .pusdTreasurySummary,
             .stakeLstSummary,
             .lendingSummary,
             .liquiditySummary,
             .yieldSummary,
             .costBasisHelp,
             .portfolioHistorySummary,
             .riskSummary,
             .yieldSearch,
             .lpPositionReview,
             .pnlSummary:
            return .portfolio
        case .cloakStatus,
             .prepareCloakDeposit,
             .cloakPrivatePaymentRequest,
             .prepareCloakPrivatePayment,
             .cloakScanSummary,
             .explainPrivateState:
            return .privateWallet
        case .zerionStatus,
             .zerionPolicySummary,
             .zerionTinySwapRequest,
             .zerionPrepareTinySwap,
             .zerionProposalStatus:
            return .zerion
        case .rpcStatus:
            return .infrastructure
        case .help, .whatCanYouDo, .missingFields:
            return .help
        case .unsupported, .unsafe:
            return .unsupported
        }
    }
}
