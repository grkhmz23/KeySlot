import Foundation

enum PnLActivityMapper {
    static func swapHints(from events: [AuditEvent]) -> [PnLSwapActivityHint] {
        events.compactMap { event in
            guard event.kind == .swapSent else {
                return nil
            }
            guard let publicAddress = event.publicAddress,
                  let inputMint = event.details["inputMint"],
                  let outputMint = event.details["outputMint"],
                  let inputAmountRaw = event.details["amountRaw"] else {
                return nil
            }

            return PnLSwapActivityHint(
                walletPublicAddress: publicAddress,
                signature: event.transactionSignature,
                inputMint: inputMint,
                outputMint: outputMint,
                inputAmountRaw: inputAmountRaw,
                outputAmountRaw: event.details["expectedOutputRaw"],
                feeLamports: event.details["estimatedFeeLamports"],
                timestamp: event.createdAt,
                source: .swapActivity,
                status: .partial,
                reason: "GORKH swap activity can provide a cost-basis hint, but historical USD values may be missing."
            )
        }
    }
}
