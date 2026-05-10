import SwiftUI

struct ZerionPolicyCenterView: View {
    let snapshot: ZerionPolicyCenterSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GorkhPanel("Policy Center") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Create the Zerion wallet, scoped policy, and agent token manually in terminal, then refresh here. A2 can execute only an approved tiny swap after policy validation.")
                        .foregroundStyle(GorkhColors.secondaryText)
                    HStack(spacing: 8) {
                        GorkhStatusChip(title: snapshot.status.label, systemImage: "checklist", color: snapshot.status == .loaded ? GorkhColors.accent : GorkhColors.warning)
                        GorkhStatusChip(title: "Transfers denied recommended", systemImage: "arrow.up.right.circle", color: GorkhColors.warning)
                        GorkhStatusChip(title: "Approvals denied recommended", systemImage: "checkmark.shield", color: GorkhColors.warning)
                    }
                }
            }

            GorkhPanel("Policies") {
                if snapshot.policies.isEmpty {
                    empty("No policies loaded yet.", reason: snapshot.unavailableReason)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(snapshot.policies) { policy in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(policy.name)
                                    .font(.headline)
                                    .foregroundStyle(GorkhColors.primaryText)
                                Text(policy.id)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(GorkhColors.secondaryText)
                                Text("Chains: \(policy.allowedChains.joined(separator: ", "))")
                                    .foregroundStyle(GorkhColors.secondaryText)
                                Text("Allowlist entries: \(policy.allowlistCount)")
                                    .foregroundStyle(GorkhColors.secondaryText)
                            }
                            Divider().overlay(GorkhColors.border)
                        }
                    }
                }
            }

            GorkhPanel("Agent Tokens") {
                if snapshot.tokens.isEmpty {
                    empty("No agent tokens loaded yet.", reason: "Agent tokens are spending power and are never displayed.")
                } else {
                    ForEach(snapshot.tokens) { token in
                        HStack {
                            Text(token.id)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(GorkhColors.primaryText)
                            Spacer()
                            GorkhStatusChip(title: token.status.label, systemImage: "key", color: GorkhColors.warning)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("agent.policy.center")
    }

    private func empty(_ title: String, reason: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundStyle(GorkhColors.primaryText)
            if let reason {
                Text(reason)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }
}
