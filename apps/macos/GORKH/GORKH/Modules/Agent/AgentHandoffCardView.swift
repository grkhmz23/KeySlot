import SwiftUI

struct AgentHandoffCardView: View {
    let instruction: AgentHandoffInstruction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(instruction.title, systemImage: "arrow.right.circle")
                .font(.caption)
                .foregroundStyle(GorkhColors.primaryText)
            Text(instruction.instruction)
                .font(.caption2)
                .foregroundStyle(GorkhColors.secondaryText)
        }
        .accessibilityIdentifier("agent.handoff.card")
    }
}
