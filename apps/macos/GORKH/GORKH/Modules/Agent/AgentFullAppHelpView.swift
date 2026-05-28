import SwiftUI

struct AgentFullAppHelpView: View {
    var body: some View {
        GorkhPanel("Agent can help with") {
            VStack(alignment: .leading, spacing: 6) {
                help("Wallet", "overview, receive, send drafts, swap drafts, security, activity, RPC status")
                help("Portfolio", "assets, wallets, PUSD, Stake/LST, lending, liquidity, yield, PnL, history")
            }
        }
        .accessibilityIdentifier("agent.fullapp.help")
    }

    private func help(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)
                .frame(width: 72, alignment: .leading)
            Text(detail)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }
}
