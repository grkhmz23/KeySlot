import SwiftUI

struct AgentOverviewView: View {
    let snapshot: AgentOverviewSnapshot
    let safetyPolicy: AgentSafetyPolicy
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                metricCard("Wallet Context", value: snapshot.walletContextAvailable ? "Available" : "Unavailable", icon: "wallet.pass")
                metricCard("Draft Proposals", value: "\(snapshot.draftProposalCount)", icon: "doc.text")
                metricCard("Main Wallet", value: snapshot.mainWalletAccess.label, icon: "xmark.shield")
            }

            GorkhPanel("Safety Invariants") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(safetyPolicy.invariants, id: \.self) { invariant in
                        Label(invariant, systemImage: "checkmark.seal")
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                }
            }
        }
        .accessibilityIdentifier("agent.overview")
    }

    private func metricCard(_ title: String, value: String, icon: String) -> some View {
        GorkhPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(GorkhColors.accent)
                    Spacer()
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(GorkhColors.primaryText)
            }
        }
    }
}
