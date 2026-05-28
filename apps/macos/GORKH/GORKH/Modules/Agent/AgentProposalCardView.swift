import SwiftUI

struct AgentProposalCardView: View {
    let proposal: AgentProposal
    let handoffAction: (AgentProposal) -> Void

    var body: some View {
        GorkhPanel(proposal.title) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    GorkhStatusChip(title: proposal.status.title, systemImage: statusIcon, color: statusColor)
                    GorkhStatusChip(title: proposal.lane.title, systemImage: "arrow.triangle.branch", color: GorkhColors.accent)
                    Spacer()
                }

                Text(proposal.summary)
                    .foregroundStyle(GorkhColors.secondaryText)

                VStack(alignment: .leading, spacing: 4) {
                    detail("Amount", proposal.amount.map { NSDecimalNumber(decimal: $0).stringValue } ?? "Unavailable")
                    detail("From", proposal.sourceAsset ?? "Unavailable")
                    detail("To", proposal.targetAsset ?? proposal.recipient ?? "Unavailable")
                    detail("Chain", proposal.chain ?? "solana")
                    detail("Expires", proposal.expiresAt.formatted(date: .omitted, time: .shortened))
                }

                if proposal.riskFlags.isEmpty == false {
                    ForEach(proposal.riskFlags) { flag in
                        Label(flag.label, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                }

                AgentPolicyDecisionView(decision: proposal.policyDecision)

                if proposal.handoffTarget != .none {
                    AgentHandoffCardView(instruction: AgentHandoffCoordinator.instruction(for: proposal))

                    Button {
                        handoffAction(proposal)
                    } label: {
                        Label(proposal.handoffTarget.title, systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.keyslotSecondary)
                    .disabled(proposal.status != .readyForReview || proposal.isExpired)
                    .accessibilityIdentifier("agent.proposal.handoff")
                }
            }
        }
        .accessibilityIdentifier("agent.proposal.card")
    }

    private var statusIcon: String {
        switch proposal.status {
        case .blocked:
            return "xmark.shield"
        case .missingFields:
            return "questionmark.circle"
        case .readyForReview, .handedOff, .approvedInDestination, .executedInDestination:
            return "checkmark.shield"
        case .draft, .failedInDestination:
            return "doc"
        }
    }

    private var statusColor: Color {
        switch proposal.status {
        case .blocked, .failedInDestination:
            return GorkhColors.danger
        case .missingFields, .draft:
            return GorkhColors.warning
        case .readyForReview, .handedOff, .approvedInDestination, .executedInDestination:
            return GorkhColors.accent
        }
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
        .font(.caption)
    }
}
