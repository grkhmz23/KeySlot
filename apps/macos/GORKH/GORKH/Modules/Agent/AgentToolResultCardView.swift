import SwiftUI

struct AgentToolResultCardView: View {
    let result: AgentToolResult

    var body: some View {
        GorkhPanel(result.title) {
            VStack(alignment: .leading, spacing: 8) {
                GorkhStatusChip(title: result.status.title, systemImage: "chart.bar.doc.horizontal", color: result.status == .blocked ? GorkhColors.danger : GorkhColors.accent)
                Text(result.summary)
                    .foregroundStyle(GorkhColors.secondaryText)
                ForEach(result.bullets, id: \.self) { bullet in
                    Label(bullet, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }
        }
        .accessibilityIdentifier("agent.tool.result")
    }
}
