import Foundation

enum AgentToolSuggestion: String, Codable, CaseIterable, Identifiable, Equatable {
    case getWalletOverviewSummary
    case getPortfolioSummary
    case getAssetSummary
    case getPUSDSummary
    case getStakeLstSummary
    case getLendingSummary
    case getLiquiditySummary
    case getYieldSummary
    case getPnLSummary
    case getActivitySummary
    case getSecuritySummary
    case getRPCStatus
    case summarizePortfolio
    case summarizeRisk
    case summarizeYield
    case summarizeLPs
    case summarizePnL
    case draftSwapProposal
    case draftPUSDPayment
    case draftMainWalletSwap
    case draftMainWalletSend

    var id: String { rawValue }
}

struct AgentToolBoundaryDecision: Codable, Equatable {
    let allowed: [String]
    let blocked: [String]

    var hasBlockedTools: Bool {
        blocked.isEmpty == false
    }
}

enum AgentToolBoundary {
    static let enabledLocalTools = AgentToolSuggestion.allCases

    private static let allowedNames = Set(AgentToolSuggestion.allCases.map(\.rawValue))
    private static let blockedNames: Set<String> = [
            "executeSwap",
            "executeSend",
            "executeBridge",
            "sendTransaction",
            "signTransaction",
            "bridge",
            "sendToken",
            "exportSeed",
        "revealPrivateKey",
        "runShell",
        "arbitraryCommand"
    ]

    static func evaluate(_ suggestions: [String]) -> AgentToolBoundaryDecision {
        var allowed: [String] = []
        var blocked: [String] = []

        for suggestion in suggestions.map(AgentSafetyRedactor.redact) {
            if allowedNames.contains(suggestion) {
                allowed.append(suggestion)
            } else if blockedNames.contains(suggestion) {
                blocked.append(suggestion)
            } else {
                blocked.append(suggestion)
            }
        }

        return AgentToolBoundaryDecision(allowed: allowed, blocked: blocked)
    }
}
