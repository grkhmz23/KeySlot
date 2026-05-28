import SwiftUI

struct AgentSystemProposalCardView: View {
    let display: AgentProposalCardDisplay
    var onPrimaryAction: () -> Void = {}
    var onReject: () -> Void = {}

    var body: some View {
        GorkhPanel(display.title) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    riskChip
                    if display.requiresApproval {
                        GorkhStatusChip(title: "Approval required", systemImage: "checkmark.shield", color: GorkhColors.warning)
                    }
                    if display.requiresSignature {
                        GorkhStatusChip(title: "Signature required", systemImage: "signature", color: GorkhColors.warning)
                    }
                    if display.blockedReason != nil {
                        GorkhStatusChip(title: "Blocked", systemImage: "xmark.octagon", color: GorkhColors.danger)
                    }
                    if let handoffTarget = display.handoffTarget {
                        GorkhStatusChip(title: "Handoff: \(handoffTarget.rawValue)", systemImage: "arrow.right.circle", color: GorkhColors.accent)
                    }
                    Spacer()
                }

                Text(display.summary)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.primaryText)

                if display.details.isEmpty == false {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(display.details, id: \.self) { detail in
                            Text("• \(detail)")
                                .font(.caption2)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                    }
                }

                if let blockedReason = display.blockedReason {
                    Label(blockedReason, systemImage: "xmark.octagon")
                        .font(.caption2)
                        .foregroundStyle(GorkhColors.danger)
                }

                AgentDecisionButtonsView(
                    display: display,
                    onPrimaryAction: onPrimaryAction,
                    onReject: onReject
                )

                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text("Approval uses this agent’s existing safety gates. Rejecting does not execute anything.")
                        .font(.caption2)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }
        }
    }

    private var riskChip: some View {
        let color: Color
        switch display.riskLevel.lowercased() {
        case "low": color = GorkhColors.success
        case "medium": color = GorkhColors.warning
        case "high", "blocked": color = GorkhColors.danger
        default: color = GorkhColors.secondaryText
        }
        return GorkhStatusChip(title: "Risk: \(display.riskLevel)", systemImage: "exclamationmark.triangle", color: color)
    }
}

struct AgentDecisionButtonsView: View {
    let display: AgentProposalCardDisplay
    var onPrimaryAction: () -> Void = {}
    var onReject: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            if display.blockedReason == nil {
                Button(action: onPrimaryAction) {
                    Label(display.primaryActionTitle, systemImage: primaryIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(primaryColor)
                .disabled(display.status == .executed || display.status == .failed)
            }

            Button(action: onReject) {
                Label(display.rejectTitle, systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .tint(GorkhColors.danger)

            Spacer()
        }
    }

    private var primaryIcon: String {
        switch display.primaryActionStyle {
        case .approve: return "checkmark.circle.fill"
        case .sign: return "signature"
        case .execute: return "bolt.fill"
        case .openHandoff: return "arrow.right.circle.fill"
        case .review: return "eye.fill"
        }
    }

    private var primaryColor: Color {
        switch display.primaryActionStyle {
        case .approve, .sign: return GorkhColors.success
        case .execute: return GorkhColors.accent
        case .openHandoff: return GorkhColors.accent
        case .review: return GorkhColors.warning
        }
    }
}
