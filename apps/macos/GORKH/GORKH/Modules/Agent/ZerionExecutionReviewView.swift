import SwiftUI

struct ZerionExecutionReviewView: View {
    let proposal: ZerionTinySwapProposal
    let decision: ZerionExecutionPolicyDecision
    let commandPlan: ZerionSwapCommandPlan?
    let confirmationPhrase: String
    let unknownValueAcknowledged: Bool
    let updateConfirmationPhrase: (String) -> Void
    let updateUnknownValueAcknowledged: (Bool) -> Void
    let executeAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        GorkhPanel("Zerion Tiny Swap Review") {
            VStack(alignment: .leading, spacing: 12) {
                Text("This uses a separate Zerion wallet. It does not use the GORKH main wallet, Keychain signer, Cloak vault, or native signing path.")
                    .foregroundStyle(GorkhColors.secondaryText)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                    row("Chain", proposal.chain.label)
                    row("Wallet", proposal.zerionWalletName)
                    row("Amount", "\(NSDecimalNumber(decimal: proposal.amount).stringValue) \(proposal.fromToken)")
                    row("To token", proposal.toToken)
                    row("Policy", proposal.policyName ?? proposal.policyID)
                    row("Local cap", "$\(NSDecimalNumber(decimal: decision.localMaxNotionalUSD).stringValue)")
                    row("Notional", proposal.estimatedNotionalUSD.map { "$\(NSDecimalNumber(decimal: $0).stringValue)" } ?? "Unavailable")
                    row("Command shape", commandPlan?.shape.label ?? "Unavailable")
                }

                if let commandPlan {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Command preview")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                        Text(commandPlan.redactedPreview)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(GorkhColors.primaryText)
                            .textSelection(.enabled)
                    }
                }

                let shieldReview = ShieldReviewService.reviewZerionTinySwap(
                    proposal: proposal,
                    decision: decision,
                    commandPlan: commandPlan
                )
                ShieldReviewCard(summary: shieldReview)

                if proposal.estimatedNotionalUSD == nil {
                    Toggle("I understand the USD value is unavailable and the amount is still intentionally tiny.", isOn: Binding(
                        get: { unknownValueAcknowledged },
                        set: updateUnknownValueAcknowledged
                    ))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Type exactly:")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text(ZerionTinySwapProposal.requiredConfirmationPhrase)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                        .textSelection(.enabled)
                    TextField("Confirmation phrase", text: Binding(
                        get: { confirmationPhrase },
                        set: updateConfirmationPhrase
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                if decision.blockingReasons.isEmpty == false {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(decision.blockingReasons, id: \.self) { reason in
                            Label(reason, systemImage: "xmark.octagon")
                                .foregroundStyle(GorkhColors.warning)
                        }
                    }
                }

                if decision.warnings.isEmpty == false {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(decision.warnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                    }
                }

                HStack {
                    Button("Cancel", action: cancelAction)
                    Spacer()
                    Button("Approve and execute tiny swap", action: executeAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(decision.canExecute == false || confirmationPhrase != ZerionTinySwapProposal.requiredConfirmationPhrase)
                }
            }
        }
        .accessibilityIdentifier("agent.zerion.execution.review")
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
