import Foundation

enum SwapApprovalGuard {
    static func validate(_ context: SwapApprovalContext) throws {
        guard context.vaultState == .unlocked else {
            throw SwapError.signingBlocked("Unlock the wallet before signing this swap.")
        }
        guard context.hasUnlockedSecret else {
            throw SwapError.signingBlocked("The signing seed is not available in memory.")
        }
        guard !context.quote.isStale() else {
            throw SwapError.quoteStale
        }
        guard context.build.userPublicKey == context.walletPublicKey else {
            throw SwapError.signingBlocked("Built swap transaction does not match the selected wallet.")
        }
        guard context.review.transactionFingerprint == context.build.transactionFingerprint else {
            throw SwapError.signingBlocked("Reviewed transaction does not match the built transaction.")
        }
        guard context.review.canApprove else {
            throw SwapError.reviewFailed(context.review.blockingReasons.joined(separator: " "))
        }
        guard let simulation = context.simulation else {
            throw SwapError.simulationRequired
        }
        guard simulation.status == .success else {
            throw SwapError.simulationFailed(simulation.errorMessage ?? "Swap simulation failed.")
        }
        guard TransactionApprovalPolicy.canApprove(
            network: context.network,
            simulation: context.simulation,
            mainnetConfirmation: context.mainnetConfirmation,
            hasCompletedDevnetSmoke: context.hasCompletedDevnetSmoke,
            allowsUnavailableSimulation: false
        ) else {
            throw SwapError.signingBlocked("Approval requirements are not complete.")
        }
        guard context.preparedFingerprint == context.currentFingerprint else {
            throw SwapError.signingBlocked("The approved swap changed after simulation. Build and simulate again.")
        }
    }
}
