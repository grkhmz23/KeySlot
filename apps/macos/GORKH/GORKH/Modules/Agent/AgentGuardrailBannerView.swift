import SwiftUI

struct AgentGuardrailBannerView: View {
    var body: some View {
        GorkhPanel {
            VStack(alignment: .leading, spacing: 8) {
                Label("Agent can help you understand, prepare, and review actions. It cannot directly move funds from chat.", systemImage: "shield.lefthalf.filled")
                    .font(.callout)
                    .foregroundStyle(GorkhColors.primaryText)
                Text("Executable requests become proposals with policy checks and destination-module approval.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
        .accessibilityIdentifier("agent.guardrail.banner")
    }
}
