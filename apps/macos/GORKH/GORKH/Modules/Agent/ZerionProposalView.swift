import SwiftUI

struct ZerionProposalView: View {
    let proposals: [ZerionProposal]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GorkhPanel("Proposals") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("A1 proposals are drafts for future review. They cannot execute, sign, trade, or call Zerion trading commands.")
                        .foregroundStyle(GorkhColors.secondaryText)
                    GorkhStatusChip(title: "Draft-only", systemImage: "doc.text", color: GorkhColors.warning)
                }
            }

            if proposals.isEmpty {
                GorkhPanel {
                    Text("No draft proposals.")
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            } else {
                ForEach(proposals) { proposal in
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
        }
        .font(.callout)
    }
}
