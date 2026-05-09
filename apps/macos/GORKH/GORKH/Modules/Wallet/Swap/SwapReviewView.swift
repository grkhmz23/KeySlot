import SwiftUI

struct SwapReviewView: View {
    let review: SwapTransactionReview?

    var body: some View {
        GorkhPanel("Transaction Review") {
            if let review {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        GorkhStatusChip(title: review.transactionVersion, systemImage: "doc.plaintext", color: GorkhColors.accent)
                        GorkhStatusChip(
                            title: review.canApprove ? "Review passed" : "Blocked",
                            systemImage: review.canApprove ? "checkmark.seal" : "exclamationmark.octagon",
                            color: review.canApprove ? GorkhColors.success : GorkhColors.danger
                        )
                        GorkhStatusChip(title: "\(review.requiredSignatureCount) signer(s)", systemImage: "signature", color: GorkhColors.accent)
                    }

                    reviewRow("Fee payer", review.feePayer ?? "Unknown")
                    reviewRow("Signers", review.signerAccounts.map(\.shortAddress).joined(separator: ", "))
                    reviewRow("Writable accounts", "\(review.writableAccounts.count)")

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Programs")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                        ForEach(review.programSummaries) { program in
                            HStack {
                                Text(program.label)
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.primaryText)
                                Spacer()
                                Text("\(program.instructionCount)x \(program.programID.shortAddress)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(GorkhColors.secondaryText)
                                    .textSelection(.enabled)
                            }
                        }
                    }

                    ForEach(review.warnings, id: \.self) { warning in
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.warning)
                    }
                    ForEach(review.blockingReasons, id: \.self) { reason in
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.danger)
                    }
                }
            } else {
                Text("Build the Jupiter transaction to decode fee payer, signer accounts, writable accounts, and program ids.")
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }

    private func reviewRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
        }
    }
}
