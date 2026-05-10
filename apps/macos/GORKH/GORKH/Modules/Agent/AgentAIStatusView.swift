import SwiftUI

struct AgentAIStatusView: View {
    let status: AgentAIStatus
    let isResponding: Bool

    var body: some View {
        GorkhPanel("AI Mode") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    GorkhStatusChip(
                        title: status.mode.title,
                        systemImage: status.mode == .hostedDeepSeek ? "cloud" : "lock.shield",
                        color: status.mode == .hostedDeepSeek ? GorkhColors.accent : GorkhColors.warning
                    )
                    GorkhStatusChip(title: status.providerState.title, systemImage: "circlebadge", color: status.providerState == .available ? GorkhColors.success : GorkhColors.warning)
                    if isResponding {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Label(status.noSecretsSent ? "No secrets sent" : "Request blocked", systemImage: status.noSecretsSent ? "checkmark.shield" : "xmark.shield")
                    .font(.caption)
                    .foregroundStyle(status.noSecretsSent ? GorkhColors.success : GorkhColors.warning)

                HStack(spacing: 8) {
                    Text("Redaction")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text(status.redactionStatus.title)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.primaryText)
                    if let endpointHost = status.endpointHost {
                        Text(endpointHost)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                }

                Text(status.message)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("agent.ai.status")
    }
}

