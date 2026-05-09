import Foundation

protocol CloakBridgeProtocol {
    func checkAvailability() -> CloakAdapterStatus
    func validateEnvironment(network: WalletNetwork) -> CloakBridgeResponseSummary
    func buildDepositPlanSummary(draft: CloakDepositDraft) -> CloakBridgeResponseSummary
    func executeDeposit(request: CloakBridgeRequestSummary) async -> CloakBridgeResponseSummary
}

struct CloakBridgeUnavailable: CloakBridgeProtocol {
    func checkAvailability() -> CloakAdapterStatus {
        .lockedInPhase20
    }

    func validateEnvironment(network: WalletNetwork) -> CloakBridgeResponseSummary {
        CloakBridgeResponseSummary(
            requestID: nil,
            actionKind: nil,
            status: .locked,
            message: network.isMainnet
                ? "Cloak is mainnet-oriented, but transaction execution is locked in Phase 2.0."
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
