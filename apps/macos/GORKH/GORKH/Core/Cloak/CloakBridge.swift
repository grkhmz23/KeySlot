import Foundation

protocol CloakBridgeProtocol {
    func checkAvailability() -> CloakAdapterStatus
    func health() -> CloakBridgeResponse
    func environmentCheck(network: WalletNetwork) -> CloakBridgeResponse
    func depositPlan(draft: CloakDepositDraft) -> CloakBridgeResponse
    func validateEnvironment(network: WalletNetwork) -> CloakBridgeResponseSummary
    func buildDepositPlanSummary(draft: CloakDepositDraft) -> CloakBridgeResponseSummary
    func executeDeposit(request: CloakBridgeRequestSummary) async -> CloakBridgeResponseSummary
}

struct CloakBridgeUnavailable: CloakBridgeProtocol {
    private let executionPolicy = CloakBridgeExecutionPolicy.disabled

    func checkAvailability() -> CloakAdapterStatus {
        .lockedInPhase23
    }

    func health() -> CloakBridgeResponse {
        let request = CloakBridgeRequest(command: .health, network: .mainnetBeta)
        return CloakBridgeResponse(
            requestID: request.id,
            command: .health,
            status: .locked,
            errorCategory: .lockedInPhase23,
            message: "Cloak helper invocation is disabled by native policy.",
            programID: CloakConstants.programID
        )
    }

    func environmentCheck(network: WalletNetwork) -> CloakBridgeResponse {
        let request = CloakBridgeRequest(command: .environmentCheck, network: network)
        return CloakBridgeResponse(
            requestID: request.id,
            command: .environmentCheck,
            status: .locked,
            errorCategory: .lockedInPhase23,
            message: executionPolicy.helperExecutionEnabled
                ? "Cloak helper execution is allowlisted but still locked for transactions."
                : "Cloak helper execution is disabled. Contract checks are available only as local models.",
            programID: CloakConstants.programID
        )
    }

    func depositPlan(draft: CloakDepositDraft) -> CloakBridgeResponse {
        let request = CloakBridgeRequest(
            command: .depositPlan,
            actionKind: .deposit,
            network: draft.network,
            walletPublicAddress: draft.sourceWalletAddress,
            amountLamports: draft.grossLamports,
            mintAddress: draft.mintAddress,
            feeQuote: draft.feeQuote
        )
        return CloakBridgeResponse.locked(request: request)
    }

    func validateEnvironment(network: WalletNetwork) -> CloakBridgeResponseSummary {
        CloakBridgeResponseSummary(
            requestID: nil,
            actionKind: nil,
            status: .locked,
            message: network.isMainnet
                ? "Cloak is mainnet-oriented, but transaction execution is locked in Phase 2.3."
                : "Cloak docs describe mainnet flows. GORKH does not create a fake devnet Cloak mode.",
            programID: CloakConstants.programID,
            createdAt: Date()
        )
    }

    func buildDepositPlanSummary(draft: CloakDepositDraft) -> CloakBridgeResponseSummary {
        let request = CloakBridgeRequestSummary(
            actionKind: .deposit,
            network: draft.network,
            walletPublicAddress: draft.sourceWalletAddress,
            grossLamports: draft.grossLamports
        )
        return .locked(request: request)
    }

    func executeDeposit(request: CloakBridgeRequestSummary) async -> CloakBridgeResponseSummary {
        .locked(request: request)
    }
}
