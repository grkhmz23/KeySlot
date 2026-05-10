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
                }

                VStack(alignment: .leading, spacing: 4) {
                    statusRow("Endpoint", status.endpointConfigured ? (status.endpointHost ?? "Configured") : "Missing")
                    statusRow("Auth", status.authStatus.title)
                    if let backendContractVersion = status.backendContractVersion {
                        statusRow("Contract", backendContractVersion)
                    }
                    if let backendModelLabel = status.backendModelLabel {
                        statusRow("Model", backendModelLabel)
                    }
                    if let lastRequestID = status.lastRequestID {
                        statusRow("Request", lastRequestID)
                    }
                    if let lastSmokeStatus = status.lastSmokeStatus {
                        statusRow("Smoke", lastSmokeStatus)
                    }
                    if let fallbackReason = status.fallbackReason {
                        statusRow("Fallback", fallbackReason)
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

    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(.caption)
                .foregroundStyle(GorkhColors.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
