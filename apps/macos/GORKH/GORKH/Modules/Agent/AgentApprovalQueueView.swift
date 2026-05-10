import SwiftUI

struct AgentApprovalQueueView: View {
    let proposals: [AgentProposal]
    @State private var filter: AgentApprovalQueueFilter = .all

    private var queue: AgentApprovalQueue {
        AgentApprovalQueue(proposals: proposals)
    }

    var body: some View {
        GorkhPanel("Approval Queue") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Approval queue filter", selection: $filter) {
                    ForEach(AgentApprovalQueueFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("agent.approval.queue.filter")

                let items = queue.filtered(by: filter)
                if items.isEmpty {
                    Text("No proposals in this queue. Chat can prepare drafts, but approval stays in the destination module.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(items.prefix(6)) { item in
                            HStack(spacing: 8) {
                                GorkhStatusChip(title: item.status.title, systemImage: "doc.badge.gearshape", color: statusColor(item.status))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.caption)
                                        .foregroundStyle(GorkhColors.primaryText)
                                    Text("\(item.lane.title) -> \(item.handoffTarget.title)")
                                        .font(.caption2)
                                        .foregroundStyle(GorkhColors.secondaryText)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("agent.approval.queue")
    }

    private func statusColor(_ status: AgentProposalStatus) -> Color {
        switch status {
        case .blocked, .failedInDestination:
            return GorkhColors.danger
        case .missingFields, .draft:
            return GorkhColors.warning
        case .readyForReview, .handedOff, .approvedInDestination, .executedInDestination:
            return GorkhColors.accent
        }
    }
}
