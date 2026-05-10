import SwiftUI

struct AgentPolicyDecisionView: View {
    let decision: AgentPolicyDecision

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GorkhStatusChip(title: decision.status.title, systemImage: systemImage, color: color)

            ForEach(decision.reasons, id: \.self) { reason in
                Label(reason, systemImage: "xmark.octagon")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            ForEach(decision.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }

    private var color: Color {
        switch decision.status {
        case .allowed:
            return GorkhColors.accent
        case .blocked:
            return GorkhColors.danger
        case .needsMoreInput:
            return GorkhColors.warning
        }
    }

    private var systemImage: String {
        switch decision.status {
        case .allowed:
            return "checkmark.shield"
        case .blocked:
            return "xmark.shield"
        case .needsMoreInput:
            return "questionmark.circle"
        }
    }
}

private extension AgentPolicyDecisionStatus {
    var title: String {
        switch self {
        case .allowed:
            return "Policy allows proposal"
        case .blocked:
            return "Policy blocked"
        case .needsMoreInput:
            return "Needs details"
        }
    }
}
