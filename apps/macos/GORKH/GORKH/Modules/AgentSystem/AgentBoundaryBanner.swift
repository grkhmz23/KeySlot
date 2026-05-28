import SwiftUI

struct AgentBoundaryBanner: View {
    let manifest: KeySlotAgentManifest
    var compact: Bool = false
    var handoffAction: (() -> Void)? = nil
    var handoffLabel: String? = nil

    var body: some View {
        GorkhPanel(manifest.title) {
            VStack(alignment: .leading, spacing: compact ? 6 : 10) {
                HStack(spacing: 8) {
                    Text(manifest.scopeSummary)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Spacer()
                    if let handoffAction, let handoffLabel {
                        Button(action: handoffAction) {
                            Label(handoffLabel, systemImage: "arrow.right.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(GorkhColors.accent)
                    }
                }

                if compact == false {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(manifest.walletBoundary, systemImage: "wallet.pass")
                        Label(manifest.executionBoundary, systemImage: "lock.shield")
                    }
                    .font(.caption2)
                    .foregroundStyle(GorkhColors.secondaryText)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(manifest.blockedDomains, id: \.self) { domain in
                            GorkhStatusChip(
                                title: domain,
                                systemImage: "xmark.shield",
                                color: GorkhColors.warning
                            )
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        GorkhStatusChip(
                            title: "Wallet: scoped",
                            systemImage: "wallet.pass",
                            color: GorkhColors.accent
                        )
                        GorkhStatusChip(
                            title: "Exec: gated",
                            systemImage: "lock.shield",
                            color: GorkhColors.accent
                        )
                        GorkhStatusChip(
                            title: "\(manifest.blockedDomains.count) blocked",
                            systemImage: "xmark.shield",
                            color: GorkhColors.warning
                        )
                    }
                }
            }
        }
    }
}
