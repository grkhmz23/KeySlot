import Foundation

struct CloakSignerBridgePolicy: Equatable {
    let signingEnabled: Bool
    let approvalRequirements: [CloakSignerApprovalRequirement]

    static let locked = CloakSignerBridgePolicy(
        signingEnabled: false,
        approvalRequirements: [
            .walletUnlocked,
            .localAuthentication,
            .signerPublicKeyMatch,
            .networkMatch,
            .actionKindMatch,
            .amountMatch,
            .cloakProgramMatch,
            .feeQuoteAcknowledged,
            .shieldReviewCompleted,
            .explicitUserApproval,
            .mainnetConfirmationPhrase,
            .draftFingerprintMatch,
            .auditBeforeSigning,
            .auditAfterSigning,
            .executionLocked
        ]
    )

    func preflight(
        request: CloakSignerRequestSummary,
        expectedWalletPublicKey: String?
    ) -> CloakSignerPreflightResult {
        do {
            try CloakSignerBridgeValidator.validate(
                request,
                expectedWalletPublicKey: expectedWalletPublicKey
            )
            return CloakSignerPreflightResult(
                requestID: request.id,
                state: .locked,
                requirements: approvalRequirements,
                failures: signingEnabled ? [] : ["Actual Cloak signing is disabled in Phase 2.4."],
                message: "Signer preflight passed contract checks, but native Cloak signing remains locked.",
                createdAt: Date()
            )
        } catch {
            return CloakSignerPreflightResult(
                requestID: request.id,
                state: .rejected,
                requirements: approvalRequirements,
                failures: [error.localizedDescription],
                message: "Signer preflight rejected the request.",
                createdAt: Date()
            )
        }
    }

    func signingDecision(
        request: CloakSignerRequestSummary,
        expectedWalletPublicKey: String?
    ) -> CloakSignerPreflightResult {
        var result = preflight(request: request, expectedWalletPublicKey: expectedWalletPublicKey)
        if result.state == .locked {
            result = CloakSignerPreflightResult(
                requestID: request.id,
                state: .locked,
                requirements: approvalRequirements,
                failures: ["Signing is not enabled for Cloak in Phase 2.4."],
                message: "Native signer bridge is defined but cannot sign Cloak requests yet.",
                createdAt: Date()
            )
        }
        return result
    }
}
