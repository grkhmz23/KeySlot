import SwiftUI

struct ZerionProposalView: View {
    let legacyProposals: [ZerionProposal]
    let tinySwapProposals: [ZerionTinySwapProposal]
    let createSolanaProposal: () -> Void
    let createBaseProposal: () -> Void
    let reviewProposal: (ZerionTinySwapProposal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GorkhPanel("Proposals") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("A2 proposals can become reviewable only for one tiny same-chain Zerion swap from a separate tiny-funded Zerion wallet under a scoped policy. Bridge, send, signing, recurring automation, and GORKH main-wallet access remain blocked.")
                        .foregroundStyle(GorkhColors.secondaryText)
                    HStack {
                        Button(action: createSolanaProposal) {
                            Label("Draft Solana tiny swap", systemImage: "plus.circle")
                        }
                        Button(action: createBaseProposal) {
                            Label("Draft Base tiny swap", systemImage: "plus.circle")
                        }
                        Spacer()
                        GorkhStatusChip(title: "Explicit approval required", systemImage: "checkmark.shield", color: GorkhColors.warning)
                    }
                }
            }

            if tinySwapProposals.isEmpty && legacyProposals.isEmpty {
                GorkhPanel {
                    Text("No draft proposals.")
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }

            ForEach(tinySwapProposals) { proposal in
                GorkhPanel("\(proposal.chain.label) tiny swap") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            GorkhStatusChip(title: proposal.status.label, systemImage: "lock", color: proposal.status == .blocked ? GorkhColors.warning : GorkhColors.accent)
                            GorkhStatusChip(title: "Separate Zerion wallet", systemImage: "wallet.pass", color: GorkhColors.accent)
                            Spacer()
                            Button("Review") {
                                reviewProposal(proposal)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        detail("Wallet", proposal.zerionWalletName)
                        detail("Amount", "\(NSDecimalNumber(decimal: proposal.amount).stringValue) \(proposal.fromToken)")
                        detail("To token", proposal.toToken)
                        detail("Policy", proposal.policyName ?? proposal.policyID)
                        detail("Estimated notional", proposal.estimatedNotionalUSD.map { "$\(NSDecimalNumber(decimal: $0).stringValue)" } ?? "Unavailable")
                        ForEach(proposal.riskNotes, id: \.self) { note in
                            Label(note, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                    }
                }
            }

            ForEach(legacyProposals) { proposal in
                GorkhPanel(proposal.actionType.label) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            GorkhStatusChip(title: proposal.status.label, systemImage: "lock", color: GorkhColors.warning)
                            GorkhStatusChip(title: proposal.chain, systemImage: "link", color: GorkhColors.accent)
                            Spacer()
                        }
                        detail("Amount", proposal.amount)
                        detail("From", proposal.fromToken)
                        detail("To / Recipient", proposal.toTokenOrRecipient)
                        detail("Policy", proposal.policyID ?? "Not selected")
                        ForEach(proposal.riskNotes, id: \.self) { note in
                            Label(note, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("agent.proposals")
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(GorkhColors.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}
